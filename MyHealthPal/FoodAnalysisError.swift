//
//  FoodAnalysisError.swift
//  HealthProctor
//
//  Created by Aditya Kumar on 24/08/25.
//


import Foundation
import UIKit

enum FoodAnalysisError: Error { case failed }

final class FoodAnalysisService {
    static func analyzeFood(image: UIImage) async throws -> String {
        // TODO: integrate with your AI API here.
        return "Sample Food Item"
    }
}