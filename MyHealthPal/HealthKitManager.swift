import Foundation
import HealthKit

/// Manages interactions with Apple HealthKit.
final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private init() {}

    /// Request permission to read steps, heart rate and active energy.
    @MainActor
    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: success) }
            }
        }
    }

    /// Fetch the most recent sample for a given identifier.
    func fetchMostRecentSample(for identifier: HKQuantityTypeIdentifier) async throws -> HKQuantitySample? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay,
                                                    end: Date(),
                                                    options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType,
                                      predicate: predicate,
                                      limit: 1,
                                      sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples?.first as? HKQuantitySample) }
            }
            healthStore.execute(query)
        }
    }
}
