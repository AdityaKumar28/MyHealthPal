import SwiftUI
import UIKit

private struct InfoAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct AISettingsView: View {
    @ObservedObject private var keyStore = AIKeyStore.shared
    @State private var geminiKey: String = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var isValidating = false
    @State private var localAlert: InfoAlert?

    // NEW: toggle to show/hide the key
    @State private var showKey: Bool = false
    // NEW: expand/collapse instructions
    @State private var showHowTo: Bool = false

    var body: some View {
        Form {
            // GOOGLE GEMINI
            Section {
                // TextField / SecureField with trailing eye icon
                HStack(spacing: 8) {
                    Group {
                        if showKey {
                            TextField("API Key", text: $geminiKey)
                        } else {
                            SecureField("API Key", text: $geminiKey)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body)

                    Button(action: { showKey.toggle() }) {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(showKey ? "Hide key" : "Show key")
                    }
                }

                // Keep your Paste / Clear row exactly as-is
                HStack {
                    Button("Paste") {
                        if let s = UIPasteboard.general.string {
                            geminiKey = s
                        }
                    }
                    .buttonStyle(.bordered)

                    Spacer(minLength: 12)

                    Button("Clear", role: .destructive) {
                        geminiKey = ""
                        keyStore.saveKey("", for: .gemini)
                    }
                    .buttonStyle(.bordered)
                }
            } header: {
                Text("GOOGLE GEMINI")
                    .font(.subheadline.weight(.semibold))
            }

            // Save row – label flips to “Validating…” while we check the key
            Section(footer:
                Text("Your key is stored locally in UserDefaults for this device and used only for API requests to Google’s Generative Language API.")
            ) {
                Button {
                    Task { await validateAndSave() }
                } label: {
                    Text(isValidating ? "Validating…" : "Save")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isValidating || geminiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // NEW: How-to instructions
            Section {
                DisclosureGroup(isExpanded: $showHowTo) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1) Open Google AI Studio and sign in with your Google account.")
                        Text("2) Create an API key (or use an existing one).")
                        Text("3) Copy the key and paste it above.")
                        Text("4) Make sure the **Generative Language API** is enabled for your account/project.")
                            .foregroundStyle(.secondary)

                        Button {
                            if let url = URL(string: "https://aistudio.google.com/app/apikey") {
                                openURL(url)
                            }
                        } label: {
                            Label("Open Google AI Studio", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }
                    .font(.subheadline)
                    .padding(.top, 4)
                } label: {
                    Label("How to get a Gemini API key", systemImage: "questionmark.circle")
                }
            }
        }
        .navigationTitle("AI Key")
        .onAppear {
            geminiKey = keyStore.keys[.gemini] ?? ""
        }
        // Only used for validation FAIL; success alert shows after dismiss on the parent screen
        .alert(item: $localAlert) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Validate then save

    private func validateAndSave() async {
        let key = geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        isValidating = true
        let ok = await validateGeminiKey(key)
        isValidating = false

        if ok {
            keyStore.saveKey(key, for: .gemini)
            // Dismiss settings first…
            dismiss()
            // …then show a success alert on the previous screen
            presentGlobalAlert(title: "Key Saved", message: "Your Gemini API key is valid and has been saved.")
        } else {
            localAlert = InfoAlert(
                title: "Invalid Key",
                message: "That key didn’t work. Make sure it’s correct and that the Generative Language API is enabled for this key in Google Cloud."
            )
        }
    }

    /// Lightweight validation using the public models list endpoint.
    private func validateGeminiKey(_ key: String) async -> Bool {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)") else {
            return false
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            // Optional sanity check of response shape
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj["models"] != nil
            }
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Present a global UIKit alert after dismiss

private func presentGlobalAlert(title: String, message: String) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let window = scene.windows.first(where: { $0.isKeyWindow }),
            var top = window.rootViewController
        else { return }

        while let presented = top.presentedViewController { top = presented }

        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        top.present(ac, animated: true)
    }
}
