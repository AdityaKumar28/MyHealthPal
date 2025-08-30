//
//  FoodLog.swift
//  MyHealthPal
//
//  Created by Aditya Kumar on 30/08/25.
//


import Foundation
import Combine

import Foundation
import Foundation

struct FoodLog: Identifiable, Codable, Equatable {
    var id: UUID
    var date: Date
    var title: String          // short food name
    var calories: Int          // integer calories
    var notes: String?         // optional longer description

    // Primary initializer (preferred)
    init(id: UUID = UUID(),
         date: Date = Date(),
         title: String,
         calories: Int,
         notes: String? = nil) {
        self.id = id
        self.date = date
        self.title = title
        self.calories = calories
        self.notes = notes
    }

    // ✅ Back-compat initializer for older call sites that used `description:` as the title label
    init(id: UUID = UUID(),
         date: Date = Date(),
         description: String,
         calories: Int,
         notes: String? = nil) {
        self.init(id: id,
                  date: date,
                  title: description,
                  calories: calories,
                  notes: notes)
    }

    // Convenience: build directly from a FoodAnalysisResult
    init?(result: FoodAnalysisResult, date: Date = Date()) {
        switch result {
        case .errorInScanning:
            return nil
        case let .ok(calories, description):
            let name = (description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? description!
            : "Scanned food"
            self.init(date: date, title: name, calories: max(0, calories), notes: description)
        }
    }
}

final class FoodLogStore: ObservableObject {
    static let shared = FoodLogStore()
    private init() { load() }

    @Published private(set) var logs: [FoodLog] = [] {
        didSet { save() }
    }

    // MARK: - CRUD

    func add(calories: Int, description: String, on date: Date) {
        let normalized = Calendar.current.startOfDay(for: date)
        let entry = FoodLog(id: UUID(), date: normalized, description: description, calories: calories)
        logs.insert(entry, at: 0)
    }

    func update(_ log: FoodLog) {
        if let idx = logs.firstIndex(where: { $0.id == log.id }) {
            logs[idx] = log
        }
    }

    func delete(_ log: FoodLog) {
        logs.removeAll { $0.id == log.id }
    }

    func logs(on date: Date) -> [FoodLog] {
        let day = Calendar.current.startOfDay(for: date)
        return logs.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
                   .sorted { $0.id.uuidString > $1.id.uuidString }
    }

    // MARK: - Persistence

    private let key = "FoodLogsV1"

    private func save() {
        do {
            let data = try JSONEncoder().encode(logs)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("⚠️ Failed saving food logs: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            logs = try JSONDecoder().decode([FoodLog].self, from: data)
        } catch {
            print("⚠️ Failed loading food logs: \(error)")
        }
    }
}
