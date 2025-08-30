//
//  CalendarPickerView.swift
//  MyHealthPal
//
//  Created by Aditya Kumar on 30/08/25.
//


import SwiftUI
import UIKit

/// SwiftUI wrapper around UICalendarView that binds the selected Date.
@available(iOS 16.0, *)
struct CalendarPickerView: UIViewRepresentable {
    @Binding var selectedDate: Date

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = Calendar.current

        // Single-date selection with delegate -> Coordinator
        let sel = UICalendarSelectionSingleDate(delegate: context.coordinator)
        // Preselect the bound date
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        sel.setSelected(comps, animated: false)
        view.selectionBehavior = sel

        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        // Keep UIKit selection in sync if SwiftUI binding changes externally
        if let sel = uiView.selectionBehavior as? UICalendarSelectionSingleDate {
            let comps = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
            sel.setSelected(comps, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UICalendarSelectionSingleDateDelegate {
        let parent: CalendarPickerView
        init(_ parent: CalendarPickerView) { self.parent = parent }

        func dateSelection(_ selection: UICalendarSelectionSingleDate,
                           didSelectDate dateComponents: DateComponents?) {
            guard
                let dc = dateComponents,
                let date = Calendar.current.date(from: dc)
            else { return }
            // Push the UIKit selection back into SwiftUI binding
            parent.selectedDate = date
        }
    }
}