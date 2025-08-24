//
//  ContentView.swift
//  HealthProctor
//
//  Created by Aditya Kumar on 24/08/25.
//

import SwiftUI

/// A simple type that wraps an error message and conforms to `Identifiable`. This is needed
/// to use SwiftUI's `alert(item:content:)` modifier, which requires the bound item to conform
/// to `Identifiable`.
struct ErrorMessage: Identifiable {
    let id = UUID()
    let message: String
}

/// Main screen showing health metrics and scanned foods.
struct ContentView: View {
    @StateObject private var healthViewModel = HealthDataViewModel()
    @State private var scannedFoods: [String] = []
    @State private var showingScanner = false
    @State private var isProcessing = false
    @State private var analysisError: ErrorMessage?
    @State private var isRefreshing = false

        // No date-specific state yet. We'll sync the current day's health data when the user taps the sync button.

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                // Show errors if HealthKit authorization fails
                if let errorMsg = healthViewModel.errorMessage {
                    Text("HealthKit Error: \(errorMsg)")
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                // Display health metrics
                VStack(alignment: .leading, spacing: 8) {
                    Text("Steps: \(Int(healthViewModel.stepCount))")
                    Text(String(format: "Heart Rate: %.1f BPM", healthViewModel.heartRate))
                    Text(String(format: "Active Energy: %.0f kcal", healthViewModel.activeEnergy))
                }
                .font(.headline)
                .padding()

                // List of logged foods
                if scannedFoods.isEmpty {
                    Text("No foods logged yet.")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else {
                    List {
                        Section(header: Text("Logged Foods")) {
                            // Use \(.self) to uniquely identify each string in the array.
                            ForEach(scannedFoods, id: \.self) { item in
                                Text(item)
                            }
                        }
                    }
                    .listStyle(GroupedListStyle())
                }

                Spacer()

                // Button to launch camera
                Button(action: { showingScanner = true }) {
                    Text(isProcessing ? "Processing…" : "Scan Food")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isProcessing ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                .disabled(isProcessing)

                // Removed the bottom sync button; the refresh action is now in the navigation bar.
            }
            .navigationTitle("Health Proctor")
            .toolbar {
                // Add a refresh icon in the navigation bar. When tapped, it will show a spinner while fetching data.
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isRefreshing {
                        // Show a built-in spinner during refresh
                        ProgressView()
                    } else {
                        Button(action: {
                            // Log the button tap and start refreshing
                            print("Refresh button tapped at \(Date())")
                            isRefreshing = true
                            print("isRefreshing set to true")
                            Task {
                                print("Starting HealthKit data refresh at \(Date())")
                                // Asynchronously refresh health data.
                                await healthViewModel.fetchAllHealthData()
                                print("Finished HealthKit data refresh at \(Date())")
                                print("Adding an delay for animation")
                                try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds
                                print("Delay Complete")
                                isRefreshing = false
                                print("isRefreshing set to false")
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                // Present the camera; when the user captures a photo,
                // send it to the analysis service and append the result.
                FoodScannerView { image in
                    Task {
                        isProcessing = true
                        do {
                            let result = try await FoodAnalysisService.analyzeFood(image: image)
                            scannedFoods.append(result)
                            analysisError = nil
                        } catch {
                            analysisError = ErrorMessage(message: error.localizedDescription)
                        }
                        isProcessing = false
                    }
                }
            }
            .alert(item: $analysisError) { error in
                Alert(title: Text("Error"),
                      message: Text(error.message),
                      dismissButton: .default(Text("OK")))
            }
        }
    }
}

// Preview provider for SwiftUI canvas
#Preview {
    ContentView()
}
