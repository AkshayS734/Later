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
    @StateObject private var securityManager = SecurityManager()
    @Environment(\.scenePhase) private var scenePhase
    
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
            ZStack {
                if securityManager.isUnlocked {
                    ContentView()
                        .environmentObject(storageManager)
                        .environmentObject(securityManager)
                } else {
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea()
                        .onTapGesture {
                            securityManager.authenticate()
                        }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    securityManager.lock()
                } else if newPhase == .active {
                    if !securityManager.isUnlocked {
                        securityManager.authenticate()
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
