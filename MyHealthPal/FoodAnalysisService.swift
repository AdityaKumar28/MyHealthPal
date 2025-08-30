import Foundation
import UIKit

enum FoodAnalysisError: Error {
    case noAPIKeyConfigured
    case failedToAnalyze
    case networkError(Error)
}

struct FoodAnalysisService {
    static func analyzeFood(image: UIImage) async throws -> String {
        print("🧠 Starting food analysis...")

        // Fetch the first non-empty key from the keystore
        let keys = AIKeyStore.shared.keys
        let activeKey = keys.first(where: { !$0.value.isEmpty })

        guard let (provider, apiKey) = activeKey else {
            print("❌ No AI key configured.")
            throw FoodAnalysisError.noAPIKeyConfigured
        }

        print("🔐 Using key for \(provider.rawValue): \(apiKey.prefix(6))******")

        // Convert image to Base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to compress image.")
            throw FoodAnalysisError.failedToAnalyze
        }
        let base64Image = imageData.base64EncodedString()

        // Updated Prompt
        let prompt = """
        Estimate the calories in this food. Return only a number with no extra text or explanation.
        If the image is not usable or you cannot identify the food, return exactly: ErrorInScanning
        """

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        ["inline_data": [
                            "mime_type": "image/jpeg",
                            "data": base64Image
                        ]]
                    ]
                ]
            ]
        ]

        // Construct URLRequest
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("❌ Invalid HTTP response.")
                throw FoodAnalysisError.failedToAnalyze
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let text = ((json?["candidates"] as? [[String: Any]])?.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]]
            let reply = text?.first?["text"] as? String ?? "ErrorInScanning"

            print("✅ Analysis Result: \(reply)")
            return reply

        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw FoodAnalysisError.networkError(error)
        }
    }
}
