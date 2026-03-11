//
//  Recipe.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation

struct Recipe: Identifiable {
    let id: String
    let name: String
    let inputItems: [RecipeIngredient]
    let outputItems: [RecipeIngredient]
    let cycleTimeInMinutes: Int
}
