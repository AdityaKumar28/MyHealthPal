//  FoodAnalysisService.swift
//  MyHealthPal
//
//  Created by Aditya Kumar on 25/08/25.
//

import Foundation
import UIKit

/// The result of analyzing a food image.
enum FoodAnalysisResult {
    /// Parsed successfully with an approximate calorie number and optional textual description.
    case ok(calories: Int, description: String?)
    /// The image was unusable or the AI could not confidently identify the food.
    case errorInScanning
}

struct FoodAnalysisService {
    static func analyzeFood(image: UIImage) async throws -> FoodAnalysisResult {
        // 1) Pick first non-empty key
        guard let (provider, apiKey) = AIKeyStore.shared.keys.first(where: {
            !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            throw FoodAnalysisError.noAPIKeyConfigured
        }
        print("🔐 Using key for \(provider.rawValue)")

        // 2) Image -> base64
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw FoodAnalysisError.failedToAnalyze
        }
        let base64 = data.base64EncodedString()

        // 3) Strict JSON prompt
        let prompt = """
        You are helping a health app log food from an image.
        Respond with ONLY a single JSON object on one line, no markdown, no backticks.
        JSON schema:
        - If the image is usable: {"calories": <integer>, "label": "<short food name 2-5 words>"}
        - If the image is not usable: {"error": "ErrorInScanning"}

        Rules:
        - calories must be an INTEGER (round your estimate).
        - label must be short and human-friendly (e.g., "grilled chicken salad").
        - Do not include units, explanations, or any extra keys.
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": base64]]
                ]
            ]]
        ]

        var req = URLRequest(url: URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?key=\(apiKey)"
        )!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                throw FoodAnalysisError.failedToAnalyze
            }

            // Pull model text
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let parts = ((root?["candidates"] as? [[String: Any]])?.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]]
            let text = parts?.first?["text"] as? String ?? ""

            // Decode JSON safely
            struct Raw: Codable {
                let calories: Int?
                let label: String?
                let error: String?
            }

            guard let textData = text.data(using: .utf8) else {
                throw FoodAnalysisError.failedToAnalyze
            }
            let raw = try JSONDecoder().decode(Raw.self, from: textData)

            if raw.error == "ErrorInScanning" {
                return .errorInScanning
            }

            guard let cals = raw.calories else {
                return .errorInScanning
            }

            let label = (raw.label?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? raw.label!
            : "Scanned food"

            return .ok(calories: max(0, cals), description: label)

        } catch {
            throw FoodAnalysisError.networkError(error)
        }
    }
}
