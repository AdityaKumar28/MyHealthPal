import SwiftUI
import Foundation

// A single alert router for the whole screen.
enum ActiveAlert: Identifiable, Equatable {
    case missingKey
    case scanFailed
    case analysisError(String)

    var id: String {
        switch self {
        case .missingKey: return "missingKey"
        case .scanFailed: return "scanFailed"
        case .analysisError(let msg): return "analysisError:\(msg)"
        }
    }

    var title: String {
        switch self {
        case .missingKey: return "AI Key Required"
        case .scanFailed: return "Scan Failed"
        case .analysisError: return "Error"
        }
    }

    var message: String {
        switch self {
        case .missingKey:
            return "Please configure at least one AI provider's API key in Settings before scanning food."
        case .scanFailed:
            return "We couldn’t identify the food clearly. Please try scanning again."
        case .analysisError(let msg):
            return msg
        }
    }
}

struct ContentView: View {
    @StateObject private var healthViewModel = HealthDataViewModel()
    @ObservedObject private var keyStore = AIKeyStore.shared

    // UI State
    @State private var scannedFoods: [String] = []
    @State private var showingScanner = false
    @State private var isProcessing = false
    @State private var isRefreshing = false
    @State private var activeAlert: ActiveAlert?

    // Cached values
    @AppStorage("cachedSteps") private var cachedSteps: Double = 0
    @AppStorage("cachedHeartRate") private var cachedHeartRate: Double = 0
    @AppStorage("cachedEnergy") private var cachedEnergy: Double = 0

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                // HealthKit errors (non-blocking)
                if let errorMsg = healthViewModel.errorMessage {
                    Text("HealthKit Error: \(errorMsg)")
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Metrics (fallback to cached if current == 0)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Steps: \(Int(healthViewModel.stepCount > 0 ? healthViewModel.stepCount : cachedSteps))")
                    Text(String(format: "Heart Rate: %.1f BPM",
                                healthViewModel.heartRate > 0 ? healthViewModel.heartRate : cachedHeartRate))
                    Text(String(format: "Active Energy: %.0f kcal",
                                healthViewModel.activeEnergy > 0 ? healthViewModel.activeEnergy : cachedEnergy))
                }
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Logged Foods
                if scannedFoods.isEmpty {
                    Text("No foods logged yet.")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else {
                    List {
                        Section(header: Text("Logged Foods")) {
                            ForEach(scannedFoods, id: \.self) { item in
                                Text(item)
                            }
                        }
                    }
                    .listStyle(GroupedListStyle())
                }

                Spacer()
            }
            .navigationTitle("My Health Pal")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Camera
                    Button {
                        let hasValidKey = keyStore.keys.values.contains {
                            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        }
                        if hasValidKey {
                            showingScanner = true
                        } else {
                            // Ensure main-thread update to trigger alert
                            Task { @MainActor in
                                activeAlert = .missingKey
                            }
                        }
                    } label: {
                        Image(systemName: "camera")
                    }
                    .disabled(isProcessing)

                    // Refresh
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Button {
                            isRefreshing = true
                            Task {
                                await healthViewModel.fetchAllHealthData()
                                cacheMetrics()
                                isRefreshing = false
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }

                    // Settings
                    NavigationLink(destination: AISettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
            // Camera sheet
            .sheet(isPresented: $showingScanner) {
                FoodScannerView { image in
                    Task {
                        await MainActor.run { isProcessing = true }
                        do {
                            let result = try await FoodAnalysisService.analyzeFood(image: image)
                            await MainActor.run {
                                if result == "ErrorInScanning" {
                                    activeAlert = .scanFailed
                                } else {
                                    scannedFoods.append(result)
                                }
                            }
                        } catch {
                            await MainActor.run {
                                activeAlert = .analysisError(error.localizedDescription)
                            }
                        }
                        await MainActor.run { isProcessing = false }
                    }
                }
            }
            // Single, unified alert
            .alert(item: $activeAlert) { active in
                Alert(
                    title: Text(active.title),
                    message: Text(active.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            // Initial load + cache
            .task {
                await healthViewModel.fetchAllHealthData()
                cacheMetrics()
            }
        }
    }

    private func cacheMetrics() {
        cachedSteps = healthViewModel.stepCount
        cachedHeartRate = healthViewModel.heartRate
        cachedEnergy = healthViewModel.activeEnergy
    }
}

#Preview {
    ContentView()
}
