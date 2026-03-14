//
//  MarketViewModel.swift
//  Boardroom Tycoon
//
//  MVVM: Presentation logic and state for the Market screen.
//

import Foundation
import Combine

@MainActor
final class MarketViewModel: ObservableObject {
    let userID: String

    @Published private(set) var mineListings: [MineMarketListing] = []
    @Published private(set) var isLoading = true
    @Published private(set) var loadingErrorMessage: String?
    @Published var actionErrorMessage: String?

    @Published var selectedListingForBid: MineMarketListing?
    @Published var bidAmountText = ""
    @Published private(set) var isSubmitting = false

    private let mineMarketService = MineMarketService()

    init(userID: String) {
        self.userID = userID
    }

    func loadListings() {
        isLoading = true
        loadingErrorMessage = nil

        mineMarketService.fetchActiveMineListings { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let listings):
                    self.mineListings = listings
                    self.isLoading = false
                case .failure(let error):
                    self.loadingErrorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func buyNow(_ listing: MineMarketListing) {
        isSubmitting = true
        actionErrorMessage = nil

        mineMarketService.buyNowMineListing(for: userID, listing: listing) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    self.loadListings()
                case .failure(let error):
                    self.actionErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func submitBid(_ listing: MineMarketListing) {
        guard let bidAmount = Double(bidAmountText), bidAmount > 0 else {
            actionErrorMessage = "Enter a valid bid amount."
            return
        }

        isSubmitting = true
        actionErrorMessage = nil

        mineMarketService.placeBid(for: userID, listing: listing, bidAmount: bidAmount) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    self.selectedListingForBid = nil
                    self.bidAmountText = ""
                    self.loadListings()
                case .failure(let error):
                    self.actionErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelListing(_ listing: MineMarketListing) {
        isSubmitting = true
        actionErrorMessage = nil

        mineMarketService.cancelMineListing(for: userID, listing: listing) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    self.loadListings()
                case .failure(let error):
                    self.actionErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func openBidSheet(for listing: MineMarketListing) {
        actionErrorMessage = nil
        bidAmountText = ""
        selectedListingForBid = listing
    }

    func closeBidSheet() {
        selectedListingForBid = nil
        bidAmountText = ""
        actionErrorMessage = nil
    }

    func formattedTimeRemaining(until endDate: Date, now: Date) -> String {
        let remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(now))))
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func mineLabel(for resourceType: ResourceType) -> String {
        switch resourceType {
        case .gold: return "Gold Mine"
        case .silver: return "Silver Mine"
        case .diamond: return "Diamond Mine"
        case .oil: return "Oil Rig"
        case .coal: return "Coal Mine"
        case .iron: return "Iron Mine"
        case .quarry, .stoneQuarry: return "Stone Quarry"
        case .sandQuarry: return "Sand Quarry"
        case .gravelQuarry: return "Gravel Quarry"
        default: return resourceType.rawValue
        }
    }
}
