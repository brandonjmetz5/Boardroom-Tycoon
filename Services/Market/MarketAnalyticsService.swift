import Foundation
import FirebaseFirestore

struct MarketAggregate: Identifiable {
    let id: String
    let resourceID: String
    let resourceName: String
    let quality: Int
    let avgListingPrice: Double?
    let avgBuyOrderPrice: Double?
}

final class MarketAnalyticsService {
    private let db = Firestore.firestore()

    func fetchAggregates(completion: @escaping (Result<[MarketAggregate], Error>) -> Void) {
        db.collection("marketAggregates").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            let docs = snapshot?.documents ?? []
            let aggregates: [MarketAggregate] = docs.compactMap { doc in
                let data = doc.data()
                let id = data["id"] as? String ?? doc.documentID
                let resourceID = data["resourceID"] as? String ?? ""
                let resourceName = data["resourceName"] as? String ?? ""
                let quality = (data["quality"] as? Int) ?? 1
                let avgListingPrice = data["avgListingPrice"] as? Double
                let avgBuyOrderPrice = data["avgBuyOrderPrice"] as? Double
                return MarketAggregate(
                    id: id,
                    resourceID: resourceID,
                    resourceName: resourceName,
                    quality: quality,
                    avgListingPrice: avgListingPrice,
                    avgBuyOrderPrice: avgBuyOrderPrice
                )
            }
            completion(.success(aggregates))
        }
    }
}

