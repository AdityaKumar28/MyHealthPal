//
//  MyHealthPalApp.swift
//  MyHealthPal
//
//  Created by Aditya Kumar on 24/08/25.
//

import SwiftUI

@main
struct MyHealthPalApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
