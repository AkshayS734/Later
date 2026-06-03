//
//  LaterApp.swift
//  Later
//
//  Created by Akshay Shukla on 03/06/26.
//

import SwiftUI
import SwiftData

@main
struct LaterApp: App {
    @StateObject private var storageManager = StorageManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Capsule.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storageManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
