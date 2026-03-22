# Chat — Firestore layout

Used by `ChatService.swift`.

## Collections

### Public rooms

- `publicChats/{roomId}` — document id is one of: `general`, `sales`, `help` (no required fields on the parent).
- `publicChats/{roomId}/messages/{messageId}`
  - `senderId` (string) — Firebase Auth UID
  - `text` (string)
  - `createdAt` (timestamp) — use server timestamp on write
  - `mentionedUserIds` (optional array of string) — Firebase Auth UIDs parsed from `@…` tokens in `text` (see **@mentions** below)

### Resource hashtags in message text

Stored as plain `text` in Firestore (e.g. `selling 100 units of #rawgold`). The iOS client parses `#…` tokens and renders matching **MarketCatalog** tradeables as **inline icons** (`#RawGold`, `#raw-gold`, `#rawgold` all resolve to Raw Gold). Unknown tags stay as literal text.

### Client: public vs direct

**Public channels:** `ChatService` queries **`createdAt` ≥ now − 24 hours** (and a limit). Requires a **composite index** on `publicChats/.../messages` (console link from the first query error). The scheduled purge deletes public messages older than **1 day**.

**Direct messages:** **No time filter** — the app loads **the full** `directChats/{dmId}/messages` thread (ordered by `createdAt`). Threads stay in the hub list indefinitely. There is **no** DM purge in Cloud Functions yet; add one later if you need retention for storage/cost.

### Direct messages

- `directChats/{dmId}` — `dmId` = two UIDs sorted ascending, joined with `_` (see `ChatService.directChatDocumentId`).
  - `participantIds` (array of string) — both UIDs (order does not matter)
  - `lastMessageText` (string) — short preview
  - `updatedAt` (timestamp)
- `directChats/{dmId}/messages/{messageId}`
  - `senderId`, `text`, `createdAt` — same shape as public messages
  - `mentionedUserIds` (optional) — same as public messages

### @mentions and in-app banner

Players mention others by typing **`@` + full Firebase Auth UID** (28-character-style ids). The client parses tokens with `ChatMentionParser` (minimum token length 20 to avoid `@help`-style false positives).

On send, `ChatService` batches:

1. The message document (with optional `mentionedUserIds`).
2. One document per target under **`chatMentions/{mentionId}`** with:
   - `targetUserId` (string) — mentioned user
   - `fromUserId` (string) — sender (must equal auth uid on create)
   - `previewText` (string) — short excerpt of the message
   - `kind` (string) — `"public"` or `"direct"`
   - `publicRoomId` (string, when `kind == "public"`) — e.g. `general`, `sales`, `help`
   - `dmId` (string, when `kind == "direct"`) — same id as `directChats` doc
   - `dmOtherUserId` (string, optional, when direct) — the non-sender participant (for future deep links)
   - `createdAt` (timestamp) — server time
   - `consumed` (bool) — `false` on create; set `true` when the target dismisses the banner or was already in that chat (suppressed)

The iOS app listens with `ChatMentionBannerController` (query below). While the user is viewing that **same** public room or DM (`ChatActiveSession`), incoming mention docs are auto-marked consumed so no banner fires.

#### `chatMentions` composite index

Query: `where targetUserId == currentUid` **and** `where consumed == false` **order by** `createdAt` **descending** (limit 25).

Firebase will offer a console link the first time this runs if the index is missing. The console-generated index uses fields: **`consumed` Asc**, **`targetUserId` Asc**, **`createdAt` Desc** (see `firestore.indexes.json`).

## Composite index

The direct thread list query is:

`directChats` where `participantIds` **array-contains** `currentUid` order by `updatedAt` **descending**.

Firebase will prompt with a console link the first time this runs if the index is missing.

### Deploy indexes from the repo (optional)

Indexes are defined in **`firestore.indexes.json`** (includes `chatMentions`, `directChats`, and existing collections). After `firebase login` and selecting project **`boardroom-tycoon`**:

```bash
cd "/path/to/Boardroom Tycoon" && firebase deploy --only firestore:indexes
```

Or open the **“create it here”** URL from the Xcode error once per missing index — Firebase builds the index in the background (often 1–5+ minutes); restart the app or wait before retesting.

### Public chat purge (scheduled deletes)

Cloud Function: **`purgePublicChatMessages`** in `functions/index.js`.

- Runs **daily** at **06:00 UTC** (`0 6 * * *`).
- Deletes messages in `publicChats/general|sales|help/messages` where **`createdAt` &lt; now − 1 day** (tune `PUBLIC_CHAT_RETENTION_DAYS` in `functions/index.js`).
- Writes a heartbeat to **`worldState/publicChatPurge`** (`lastRunAt`, `totalDeleted`, etc.).

**Deploy**

```bash
cd functions && npm install && cd .. && firebase deploy --only functions:purgePublicChatMessages
```

**Firestore index:** The purge uses `where("createdAt", "<", …)` + `orderBy("createdAt", "asc")` on each `messages` subcollection. If the first run fails, the error log includes a link to create the required index (often one composite index on collection **`messages`** with field **`createdAt`**).

**Direct messages:** Not purged by this job (different product decision / privacy). Add a separate scheduled job later if you want DM retention.

## Security rules (sketch)

Tighten for production; during development you may use permissive rules.

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /publicChats/{roomId}/messages/{msgId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
        && request.resource.data.senderId == request.auth.uid
        && request.resource.data.text is string
        && request.resource.data.text.size() > 0
        && request.resource.data.text.size() < 2000;
    }

    match /directChats/{dmId} {
      allow read: if request.auth != null
        && request.auth.uid in resource.data.participantIds;

      allow create, update: if request.auth != null
        && request.auth.uid in request.resource.data.participantIds
        && request.resource.data.participantIds.size() == 2;

      match /messages/{msgId} {
        allow read: if request.auth != null
          && request.auth.uid in get(/databases/$(database)/documents/directChats/$(dmId)).data.participantIds;

        allow create: if request.auth != null
          && request.auth.uid in get(/databases/$(database)/documents/directChats/$(dmId)).data.participantIds
          && request.resource.data.senderId == request.auth.uid;
      }
    }

    match /chatMentions/{mentionId} {
      allow read: if request.auth != null
        && resource.data.targetUserId == request.auth.uid;

      allow create: if request.auth != null
        && request.resource.data.fromUserId == request.auth.uid
        && request.resource.data.targetUserId is string
        && request.resource.data.targetUserId != request.auth.uid
        && request.resource.data.previewText is string
        && request.resource.data.previewText.size() > 0
        && request.resource.data.previewText.size() <= 500
        && request.resource.data.kind in ['public', 'direct']
        && request.resource.data.consumed == false
        && request.resource.data.createdAt == request.time
        && (
          (request.resource.data.kind == 'public'
            && request.resource.data.publicRoomId is string
            && request.resource.data.publicRoomId.size() > 0)
          ||
          (request.resource.data.kind == 'direct'
            && request.resource.data.dmId is string
            && request.resource.data.dmId.size() > 0)
        );

      allow update: if request.auth != null
        && resource.data.targetUserId == request.auth.uid
        && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['consumed'])
        && request.resource.data.consumed == true;
    }
  }
}
```

**Note:** First message in a DM creates the parent via `merge`; adjust rules if `create` on subcollection before parent exists — you may need to allow `create` on `directChats/{dmId}` when the document is new and both IDs are valid.

**`chatMentions` rules:** Optionally restrict `publicRoomId` to `general`, `sales`, `help`, and/or verify `fromUserId` is in `get(/databases/.../directChats/$(dmId)).data.participantIds` for direct mentions. If `createdAt == request.time` is too strict for your client, relax to allowing `request.resource.data.createdAt is timestamp`.
