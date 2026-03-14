//
//  RecipeService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class RecipeService {
    private let db = Firestore.firestore()

    func fetchRecipes(completion: @escaping (Result<[Recipe], Error>) -> Void) {
        let recipesRef = db.collection("recipes")

        recipesRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let recipes: [Recipe] = documents.compactMap { document in
                let data = document.data()

                guard
                    let id = data["id"] as? String,
                    let name = data["name"] as? String,
                    let cycleTimeInMinutes = data["cycleTimeInMinutes"] as? Int,
                    let inputItemsData = data["inputItems"] as? [[String: Any]],
                    let outputItemsData = data["outputItems"] as? [[String: Any]]
                else {
                    return nil
                }

                let inputItems = inputItemsData.compactMap { ingredientData -> RecipeIngredient? in
                    guard
                        let ingredientID = ingredientData["id"] as? String,
                        let itemID = ingredientData["itemID"] as? String,
                        let itemName = ingredientData["itemName"] as? String,
                        let categoryRawValue = ingredientData["category"] as? String,
                        let category = ItemCategory(rawValue: categoryRawValue),
                        let isFractional = ingredientData["isFractional"] as? Bool,
                        let quantity = ingredientData["quantity"] as? Double
                    else {
                        return nil
                    }

                    let item = Item(
                        id: itemID,
                        name: itemName,
                        category: category,
                        isFractional: isFractional
                    )

                    return RecipeIngredient(
                        id: ingredientID,
                        item: item,
                        quantity: quantity
                    )
                }

                let outputItems = outputItemsData.compactMap { ingredientData -> RecipeIngredient? in
                    guard
                        let ingredientID = ingredientData["id"] as? String,
                        let itemID = ingredientData["itemID"] as? String,
                        let itemName = ingredientData["itemName"] as? String,
                        let categoryRawValue = ingredientData["category"] as? String,
                        let category = ItemCategory(rawValue: categoryRawValue),
                        let isFractional = ingredientData["isFractional"] as? Bool,
                        let quantity = ingredientData["quantity"] as? Double
                    else {
                        return nil
                    }

                    let item = Item(
                        id: itemID,
                        name: itemName,
                        category: category,
                        isFractional: isFractional
                    )

                    return RecipeIngredient(
                        id: ingredientID,
                        item: item,
                        quantity: quantity
                    )
                }

                return Recipe(
                    id: id,
                    name: name,
                    inputItems: inputItems,
                    outputItems: outputItems,
                    cycleTimeInMinutes: cycleTimeInMinutes
                )
            }

            completion(.success(recipes))
        }
    }
}
