// AIKeyStore.swift
import Foundation
import Combine

final class AIKeyStore: ObservableObject {
    static let shared = AIKeyStore()

    @Published var keys: [AIProvider: String] = [:]

    private init() {
        loadKeys()
    }

    func loadKeys() {
        var loaded: [AIProvider: String] = [:]
        for provider in AIProvider.allCases {
            let key = UserDefaults.standard.string(forKey: provider.userDefaultsKey) ?? ""
            print("[AIKeyStore] Loaded key for \(provider.rawValue): \(key.isEmpty ? "[Empty]" : "[Set]")")
            loaded[provider] = key
        }
        DispatchQueue.main.async {
            self.keys = loaded
        }
    }

    func saveKey(_ key: String, for provider: AIProvider) {
        print("[AIKeyStore] Saving key for \(provider.rawValue): \(key)")
        UserDefaults.standard.set(key, forKey: provider.userDefaultsKey)
        DispatchQueue.main.async {
            self.keys[provider] = key
        }
    }

    func getKey(for provider: AIProvider) -> String? {
        return keys[provider]
    }

    func hasAnyValidKey() -> Bool {
        return keys.values.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }
}
