//
//  HealthDataViewModel.swift
//  HealthProctor
//
//  Created by Aditya Kumar on 24/08/25.
//
import Foundation
import SwiftUI
import HealthKit

/// View model that exposes health data to the UI.
@MainActor
final class HealthDataViewModel: ObservableObject {
    @Published var stepCount: Double = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var errorMessage: String?

    init() {
        Task { await requestAuthorization() }
    }

    func requestAuthorization() async {
        do {
            let success = try await HealthKitManager.shared.requestAuthorization()
            if success { await fetchAllHealthData() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchAllHealthData() async {
        async let steps = fetchStepCount()
        async let rate = fetchHeartRate()
        async let energy = fetchActiveEnergy()
        _ = await (steps, rate, energy)
    }

    func fetchStepCount() async {
        if let sample = try? await HealthKitManager.shared.fetchMostRecentSample(for: .stepCount) {
            stepCount = sample.quantity.doubleValue(for: HKUnit.count())
        }
    }

    func fetchHeartRate() async {
        if let sample = try? await HealthKitManager.shared.fetchMostRecentSample(for: .heartRate) {
            heartRate = sample.quantity.doubleValue(for: HKUnit.count()
                                                    .unitDivided(by: HKUnit.minute()))
        }
    }

    func fetchActiveEnergy() async {
        if let sample = try? await HealthKitManager.shared.fetchMostRecentSample(for: .activeEnergyBurned) {
            activeEnergy = sample.quantity.doubleValue(for: HKUnit.kilocalorie())
        }
    }
}
