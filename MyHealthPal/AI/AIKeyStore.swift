import Foundation
import Combine

enum AIProvider: String, CaseIterable, Codable {
    case gemini
}

final class AIKeyStore: ObservableObject {
    static let shared = AIKeyStore()

    @Published var keys: [AIProvider: String] = [:]

    private let storageKey = "ai_keys_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([AIProvider: String].self, from: data) {
            keys = decoded
        }
    }

    func saveKey(_ key: String, for provider: AIProvider) {
        keys[provider] = key
        persist()
    }

    func clearKey(for provider: AIProvider) {
        keys[provider] = ""
        persist()
    }

    func getKey(for provider: AIProvider) -> String? {
        let v = keys[provider]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return v.isEmpty ? nil : v
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(keys) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
