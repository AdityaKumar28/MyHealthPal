import Foundation
import HealthKit

@MainActor
final class HealthDataViewModel: ObservableObject {
    @Published var stepCount: Double = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var errorMessage: String?

    func fetchAllHealthData() async {
        print("📲 [HealthDataViewModel] Starting data fetch...")

        do {
            let (steps, heartRate, energy) = try await HealthKitManager.shared.fetchMetrics()
            self.stepCount = steps
            self.heartRate = heartRate
            self.activeEnergy = energy

            print("✅ [HealthDataViewModel] Health data updated: steps=\(steps), heartRate=\(heartRate), energy=\(energy)")

            if steps == 0 && heartRate == 0 && energy == 0 {
                self.errorMessage = "No recent health data available."
            } else {
                self.errorMessage = nil
            }

        } catch {
            print("❌ [HealthDataViewModel] Failed to fetch health data: \(error.localizedDescription)")
            self.errorMessage = "Failed to fetch health data."
        }
    }
}
