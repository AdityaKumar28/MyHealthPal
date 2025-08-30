//
//  FoodEditSheet.swift
//  MyHealthPal
//
//  Created by Aditya Kumar on 30/08/25.
//


import SwiftUI

struct FoodEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var newTitle: String
    @State private var newCalories: Int
    @State private var newNotes: String

    /// Called when the user taps Save.
    var onSave: (_ title: String, _ calories: Int, _ notes: String?) -> Void

    /// Designated init that matches how ContentView calls it.
    init(title: String, calories: Int, description: String? = nil,
         onSave: @escaping (_ title: String, _ calories: Int, _ notes: String?) -> Void) {
        _newTitle = State(initialValue: title)
        _newCalories = State(initialValue: calories)
        _newNotes = State(initialValue: description ?? "")
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("FOOD")) {
                    TextField("Food name", text: $newTitle)
                        .textInputAutocapitalization(.words)
                }

                Section(header: Text("CALORIES")) {
                    HStack {
                        Text("\(newCalories) kcal")
                            .font(.title3).bold()
                            .accessibilityLabel("\(newCalories) kilocalories")

                        Spacer()
                        HStack(spacing: 8) {
                            Button {
                                newCalories = max(0, newCalories - 10)
                            } label: {
                                Image(systemName: "minus")
                                    .frame(width: 44, height: 36)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                newCalories += 10
                            } label: {
                                Image(systemName: "plus")
                                    .frame(width: 44, height: 36)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Section(header: Text("NOTES (OPTIONAL)")) {
                    TextField("e.g., no dressing, extra veggies", text: $newNotes)
                        .textInputAutocapitalization(.sentences)
                }

                Section {
                    Button("Save Changes") {
                        onSave(newTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                               max(0, newCalories),
                               newNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newNotes)
                        dismiss()
                    }
                    .buttonStyle(PrimaryFilledButtonStyle())
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Log")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}