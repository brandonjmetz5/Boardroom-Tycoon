//
//  ChatMentionBannerController.swift
//  Boardroom Tycoon
//
//  Listens for chatMentions targeted at the current user and shows a top banner queue.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class ChatMentionBannerController: ObservableObject {
    /// Matches auto-dismiss and the countdown bar in `ChatMentionTopBannerView`.
    static let bannerDisplayDuration: TimeInterval = 5

    struct BannerPayload: Equatable {
        let documentId: String
        let fromUserId: String
        let preview: String
        let kind: String
        let publicRoomId: String?
        let dmId: String?
        /// Other participant in the DM (for navigation); optional if derivable from `dmId`.
        let dmOtherUserId: String?
    }

    @Published private(set) var activeBanner: BannerPayload?
    /// Start time for the 5s countdown bar (nil when no banner).
    @Published private(set) var bannerClockStart: Date?

    private let userId: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var primedInitialSnapshot = false
    /// Used so mentions that already exist in Firestore when the listener attaches still get a banner if they’re “fresh.”
    private var listenerAttachedAt: Date?
    private var seenDocumentIds = Set<String>()
    private var pendingQueue: [BannerPayload] = []
    private var autoDismissTask: Task<Void, Never>?
    private var bannerShownAt: Date?

    private var bannerDuration: TimeInterval { Self.bannerDisplayDuration }

    init(userId: String) {
        self.userId = userId
    }

    deinit {
        listener?.remove()
    }

    func start() {
        listener?.remove()
        primedInitialSnapshot = false
        listenerAttachedAt = Date()
        seenDocumentIds.removeAll()

        let query = db.collection("chatMentions")
            .whereField("targetUserId", isEqualTo: userId)
            .whereField("consumed", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: 25)

        listener = query.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    let ns = error as NSError
                    print("ChatMentionBannerController listener error: \(error.localizedDescription)")
                    print("  domain=\(ns.domain) code=\(ns.code) userInfo=\(ns.userInfo)")
                    if error.localizedDescription.localizedCaseInsensitiveContains("index")
                        || ns.userInfo.description.localizedCaseInsensitiveContains("index") {
                        print("  → Firestore likely needs a composite index for chatMentions (targetUserId + consumed + createdAt). Check the Xcode/Firebase console link.")
                    }
                    return
                }
                guard let snapshot else { return }

                if !self.primedInitialSnapshot {
                    // Old behavior: every doc on the first snapshot was marked “seen,” so you never got a banner
                    // if the mention was already in the result set (e.g. B opens the app after A sent, or unconsumed backlog).
                    // We still skip banners for *old* backlog using a time cutoff vs when the listener started.
                    let attach = self.listenerAttachedAt ?? Date()
                    // Mentions older than this vs. listener start stay “silent” (backlog); recent ones still banner.
                    let backlogCutoff = attach.addingTimeInterval(-120)

                    for doc in snapshot.documents {
                        let id = doc.documentID
                        guard !self.seenDocumentIds.contains(id) else { continue }
                        self.seenDocumentIds.insert(id)

                        let createdAt = (doc.data()["createdAt"] as? Timestamp)?.dateValue()
                        if createdAt == nil {
                            // Pending server timestamp — treat as live.
                            self.ingestNewMention(document: doc)
                        } else if createdAt! >= backlogCutoff {
                            self.ingestNewMention(document: doc)
                        }
                    }
                    self.primedInitialSnapshot = true
                    return
                }

                for change in snapshot.documentChanges where change.type == .added {
                    let doc = change.document
                    let id = doc.documentID
                    guard !self.seenDocumentIds.contains(id) else { continue }
                    self.seenDocumentIds.insert(id)
                    self.ingestNewMention(document: doc)
                }
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        autoDismissTask?.cancel()
        autoDismissTask = nil
        activeBanner = nil
        bannerClockStart = nil
        bannerShownAt = nil
        pendingQueue.removeAll()
    }

    func dismissActiveBanner(userInitiated: Bool) {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        guard let banner = activeBanner else {
            showNextFromQueue()
            return
        }
        markConsumed(documentId: banner.documentId)
        activeBanner = nil
        bannerShownAt = nil
        bannerClockStart = nil
        showNextFromQueue()
    }

    private func ingestNewMention(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let from = data["fromUserId"] as? String else { return }
        let preview = (data["previewText"] as? String) ?? "Mentioned you in chat"
        let kind = (data["kind"] as? String) ?? "public"
        let publicRoomId = data["publicRoomId"] as? String
        let dmId = data["dmId"] as? String
        let dmOtherUserId = data["dmOtherUserId"] as? String

        if kind == "public", ChatActiveSession.shared.shouldSuppressMentionBanner(publicRoomId: publicRoomId) {
            markConsumed(documentId: document.documentID)
            return
        }
        if kind == "direct", ChatActiveSession.shared.shouldSuppressMentionBanner(dmId: dmId) {
            markConsumed(documentId: document.documentID)
            return
        }

        let payload = BannerPayload(
            documentId: document.documentID,
            fromUserId: from,
            preview: preview,
            kind: kind,
            publicRoomId: publicRoomId,
            dmId: dmId,
            dmOtherUserId: dmOtherUserId
        )

        if activeBanner == nil {
            present(payload)
        } else {
            pendingQueue.append(payload)
        }
    }

    private func present(_ payload: BannerPayload) {
        let now = Date()
        activeBanner = payload
        bannerShownAt = now
        bannerClockStart = now
        autoDismissTask?.cancel()
        autoDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(bannerDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if self.activeBanner?.documentId == payload.documentId {
                self.dismissActiveBanner(userInitiated: false)
            }
        }
    }

    private func showNextFromQueue() {
        guard activeBanner == nil, !pendingQueue.isEmpty else { return }
        let next = pendingQueue.removeFirst()
        present(next)
    }

    private func markConsumed(documentId: String) {
        db.collection("chatMentions").document(documentId).setData(
            ["consumed": true],
            merge: true
        )
    }
}
