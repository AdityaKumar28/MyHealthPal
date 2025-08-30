import Foundation
import HealthKit

@MainActor
final class HealthDataViewModel: ObservableObject {
    @Published var stepCount: Double = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var errorMessage: String?

    func fetchAllHealthData(for date: Date) async {
        print("📲 [HealthDataViewModel] Fetching health data for \(date)")
        do {
            let (steps, hr, energy) = try await HealthKitManager.shared.fetchMetrics(for: date)
            stepCount = steps
            heartRate = hr
            activeEnergy = energy
            errorMessage = nil
            print("✅ [HealthDataViewModel] Updated for \(date): steps=\(steps), hr=\(hr), energy=\(energy)")
        } catch {
            // Graceful fallback: show zeros instead of surfacing errors
            stepCount = 0
            heartRate = 0
            activeEnergy = 0
            errorMessage = nil
            print("⚠️ [HealthDataViewModel] No data for \(date). Defaulting to zeros.")
        }
    }
}
