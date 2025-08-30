// AISettingsView.swift
import SwiftUI

enum AIProvider: String, CaseIterable, Identifiable {
    case gemini = "Gemini"
    case chatgpt = "ChatGPT"

    var id: String { rawValue }
    var userDefaultsKey: String {
        switch self {
        case .gemini: return "API_KEY_GEMINI"
        case .chatgpt: return "API_KEY_CHATGPT"
        }
    }
}

struct AISettingsView: View {
    @State private var selectedProvider: AIProvider = .gemini
    @State private var apiKey: String = ""
    @State private var showSavedMessage = false

    var body: some View {
        Form {
            Section(header: Text("Select AI Provider")) {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedProvider) { newProvider in
                    apiKey = UserDefaults.standard.string(forKey: newProvider.userDefaultsKey) ?? ""
                }
            }

            Section(header: Text("API Key for \(selectedProvider.rawValue)")) {
                SecureField("Enter API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Button("Save API Key") {
                UserDefaults.standard.set(apiKey, forKey: selectedProvider.userDefaultsKey)
                AIKeyStore.shared.saveKey(apiKey, for: selectedProvider)
                showSavedMessage = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showSavedMessage = false
                }
            }

            if showSavedMessage {
                HStack {
                    Spacer()
                    Label("Saved!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Spacer()
                }
            }
        }
        .navigationTitle("AI Key Management")
        .onAppear {
            apiKey = UserDefaults.standard.string(forKey: selectedProvider.userDefaultsKey) ?? ""
        }
    }
}

#Preview {
    NavigationView {
        AISettingsView()
    }
}
