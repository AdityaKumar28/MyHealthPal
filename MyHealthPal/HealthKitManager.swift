import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private init() {}

    // MARK: Authorization
    private func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let readTypes: Set<HKObjectType> = [
                HKQuantityType.quantityType(forIdentifier: .stepCount)!,
                HKQuantityType.quantityType(forIdentifier: .heartRate)!,
                HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            ]
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error = error { continuation.resume(throwing: error) }
                else if success { continuation.resume() }
                else {
                    continuation.resume(throwing: NSError(
                        domain: "HealthKit",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Authorization failed"]
                    ))
                }
            }
        }
    }

    // MARK: Public: fetch metrics for **a given day**
    func fetchMetrics(for date: Date) async throws -> (Double, Double, Double) {
        try await requestAuthorization()

        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else {
            throw NSError(domain: "HealthKit", code: 99, userInfo: [NSLocalizedDescriptionKey: "Date math failed"])
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        async let steps = fetchSumQuantity(.stepCount, unit: .count(), predicate: predicate)
        async let heartRate = fetchAverageQuantity(.heartRate, unit: HKUnit(from: "count/min"), predicate: predicate)
        async let energy = fetchSumQuantity(.activeEnergyBurned, unit: .kilocalorie(), predicate: predicate)

        return try await (steps, heartRate, energy)
    }

    // MARK: Internals
    private func fetchSumQuantity(_ identifier: HKQuantityTypeIdentifier,
                                  unit: HKUnit,
                                  predicate: NSPredicate) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw NSError(domain: "HealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid quantity type"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, result, error in
                if error != nil {
                    continuation.resume(returning: 0)  // graceful fallback
                } else if let sum = result?.sumQuantity() {
                    continuation.resume(returning: sum.doubleValue(for: unit))
                } else {
                    continuation.resume(returning: 0)
                }
            }
            self.healthStore.execute(q)
        }
    }

    private func fetchAverageQuantity(_ identifier: HKQuantityTypeIdentifier,
                                      unit: HKUnit,
                                      predicate: NSPredicate) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw NSError(domain: "HealthKit", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid quantity type"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .discreteAverage) { _, result, error in
                if error != nil {
                    continuation.resume(returning: 0)  // graceful fallback
                } else if let avg = result?.averageQuantity() {
                    continuation.resume(returning: avg.doubleValue(for: unit))
                } else {
                    continuation.resume(returning: 0)
                }
            }
            self.healthStore.execute(q)
        }
    }
}
