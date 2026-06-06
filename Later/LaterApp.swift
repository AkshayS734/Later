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
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Capsule.self,
        ])
        
        let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.akshay.Later")!
        let storeURL = appGroupURL.appendingPathComponent("Capsules.sqlite")
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !hasSeenOnboarding {
                    OnboardingView()
                        .environmentObject(storageManager)
                } else if securityManager.isUnlocked {
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
                    if hasSeenOnboarding && !securityManager.isUnlocked {
                        securityManager.authenticate()
                    }
                }
            }
            .tint(AppTheme.accent)
        }
        .modelContainer(sharedModelContainer)
    }
}
