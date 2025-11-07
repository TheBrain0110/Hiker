//
//  HikerApp.swift
//  Hiker
//
//  Created by Andrew Puddington on 11/7/25.
//

import SwiftUI
import SwiftData

@main
struct HikerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Client.self,
            Dog.self,
            Payment.self,
            ScheduleException.self,
            HikingLocation.self,
        ])

        // Enable iCloud sync with CloudKit
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
