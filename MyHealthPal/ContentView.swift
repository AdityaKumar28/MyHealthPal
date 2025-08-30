import SwiftUI
import Foundation

struct ErrorMessage: Identifiable {
    let id = UUID()
    let message: String
}

private enum ActiveAlert: Identifiable {
    case error(String)
    case missingKey
    case scanFailed

    var id: String {
        switch self {
        case .error:      return "error"
        case .missingKey: return "missingKey"
        case .scanFailed: return "scanFailed"
        }
    }
}

struct ContentView: View {
    @StateObject private var healthViewModel = HealthDataViewModel()
    @ObservedObject private var keyStore = AIKeyStore.shared

    // unified alert state
    @State private var activeAlert: ActiveAlert?

    @State private var showingScanner = false
    @State private var isProcessing = false
    @State private var isRefreshing = false

    @State private var logs: [FoodLog] = []
    @State private var editingLog: FoodLog?
    @State private var goToSettings = false

    // Cached values
    @AppStorage("cachedSteps") private var cachedSteps: Double = 0
    @AppStorage("cachedHeartRate") private var cachedHeartRate: Double = 0
    @AppStorage("cachedEnergy") private var cachedEnergy: Double = 0

    // Calendar selection (today by default)
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {

                // Invisible link for “Open Settings” alert action
                NavigationLink(destination: AISettingsView(),
                               isActive: $goToSettings) { EmptyView() }
                    .hidden()

                // Selected date under the title for clarity
                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                // Metrics (fallback to cached if latest == 0)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Steps: \(Int(healthOrCached(healthViewModel.stepCount, cachedSteps)))")
                    Text(String(format: "Heart Rate: %.1f BPM",
                                healthOrCached(healthViewModel.heartRate, cachedHeartRate)))
                    Text(String(format: "Active Energy: %.0f kcal",
                                healthOrCached(healthViewModel.activeEnergy, cachedEnergy)))
                }
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Summary row (Deficit/Surplus, Intake/Spent/Net)
                summaryRow
                    .padding(.horizontal)
                    .padding(.top, 6)

                // Logs list
                Group {
                    if dayLogs.isEmpty {
                        Text("No foods logged yet.")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else {
                        List {
                            Section(header: Text("LOGGED FOODS")) {
                                ForEach(dayLogs) { log in
                                    HStack(spacing: 16) {
                                        Text("\(log.calories) kcal")
                                            .font(.headline)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(log.title).font(.body)
                                            if let notes = log.notes, !notes.isEmpty {
                                                Text(notes)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .swipeActions {
                                        Button("Edit") { editingLog = log }
                                            .tint(.blue)

                                        Button(role: .destructive) {
                                            delete(log)
                                        } label: { Text("Delete") }
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
                .animation(.default, value: dayLogs)

                Spacer()
            }
            .navigationTitle("My Health Pal")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Calendar icon
                    Button { showDatePicker.toggle() } label: {
                        Image(systemName: "calendar")
                    }

                    // Camera (scan)
                    Button {
                        if hasAIKey {
                            showingScanner = true
                        } else {
                            activeAlert = .missingKey
                        }
                    } label: {
                        Image(systemName: "camera")
                    }
                    .disabled(isProcessing)

                    // Refresh metrics
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Button { refreshMetrics() } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }

                    // Settings
                    NavigationLink(destination: AISettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
            // Scanner
            .sheet(isPresented: $showingScanner) {
                FoodScannerView { image in
                    Task {
                        isProcessing = true
                        do {
                            let result = try await FoodAnalysisService.analyzeFood(image: image)
                            handleAnalysisResult(result)
                        } catch {
                            activeAlert = .error(error.localizedDescription)
                        }
                        isProcessing = false
                    }
                }
            }
            // Edit sheet
            .sheet(item: $editingLog) { log in
                FoodEditSheet(
                    title: log.title,
                    calories: log.calories,
                    description: log.notes
                ) { newTitle, newCalories, newNotes in
                    if let idx = logs.firstIndex(where: { $0.id == log.id }) {
                        logs[idx].title = newTitle
                        logs[idx].calories = newCalories
                        logs[idx].notes = newNotes
                    }
                }
            }
            // Date picker sheet
            .sheet(isPresented: $showDatePicker) {
                NavigationView {
                    DatePicker("Pick a date",
                               selection: $selectedDate,
                               displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .navigationTitle("Select Date")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Today") { selectedDate = Date() }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showDatePicker = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            // ONE alert for everything (prevents conflicts)
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .error(let message):
                    return Alert(
                        title: Text("Error"),
                        message: Text(message),
                        dismissButton: .default(Text("OK"))
                    )

                case .missingKey:
                    return Alert(
                        title: Text("AI Key Required"),
                        message: Text("Please add at least one AI provider key before scanning food."),
                        primaryButton: .default(Text("Open Settings")) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                goToSettings = true
                            }
                        },
                        secondaryButton: .cancel()
                    )

                case .scanFailed:
                    return Alert(
                        title: Text("Scan Failed"),
                        message: Text("We couldn’t identify the food clearly. Please try scanning again."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            // Initial load for today's selected date
            .task {
                await healthViewModel.fetchAllHealthData(for: selectedDate)
                cacheMetrics()
            }
            // Re-fetch when the user picks a new date
            .onChange(of: selectedDate) { newValue in
                Task {
                    await healthViewModel.fetchAllHealthData(for: newValue)
                    cacheMetrics()
                }
            }
        }
    }

    // MARK: - Derived state

    private var hasAIKey: Bool {
        let key = keyStore.keys[.gemini]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !key.isEmpty
    }

    private var summaryRow: some View {
        let intake = dayLogs.map(\.calories).reduce(0, +)
        let spent = Int(healthOrCached(healthViewModel.activeEnergy, cachedEnergy))
        let net = intake - spent
        let isDeficit = net <= 0

        return HStack(spacing: 16) {
            Text(isDeficit ? "Deficit" : "Surplus")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isDeficit ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                .foregroundColor(isDeficit ? .green : .orange)
                .clipShape(Capsule())

            Group {
                Text("Intake: \(intake) kcal")
                Text("Spent: \(spent) kcal")
                Text("Net: \(net) kcal")
                    .foregroundColor(isDeficit ? .green : .orange)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Helpers

    private func healthOrCached(_ live: Double, _ cached: Double) -> Double {
        live > 0 ? live : cached
    }

    private var dayLogs: [FoodLog] {
        logs.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private func delete(_ log: FoodLog) {
        logs.removeAll { $0.id == log.id }
    }

    private func refreshMetrics() {
        isRefreshing = true
        Task {
            await healthViewModel.fetchAllHealthData(for: selectedDate)
            cacheMetrics()
            isRefreshing = false
        }
    }

    private func cacheMetrics() {
        cachedSteps = healthViewModel.stepCount
        cachedHeartRate = healthViewModel.heartRate
        cachedEnergy = healthViewModel.activeEnergy
    }

    private func handleAnalysisResult(_ result: FoodAnalysisResult) {
        switch result {
        case .errorInScanning:
            activeAlert = .scanFailed

        case let .ok(calories, description):
            logs.append(
                FoodLog(
                    date: selectedDate,
                    title: (description?.isEmpty == false ? description! : "Scanned food"),
                    calories: calories,
                    notes: description
                )
            )
        }
    }
}

#Preview {
    ContentView()
}
