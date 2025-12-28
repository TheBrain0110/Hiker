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
            ScheduleOverride.self,
            HikingLocation.self,
            DailyHike.self,
            HikeParticipation.self,
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
            // To debug app launch issues, replace ContentView() with DebugLaunchView()
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Debug Launch View
// Useful for isolating iOS SwiftData/SwiftUI issues during app launch.
// To use: Replace ContentView() with DebugLaunchView() in the WindowGroup above.

struct DebugLaunchView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Debug Launch Screen")
                    .font(.largeTitle)

                Text("App launched successfully!")
                    .foregroundStyle(.green)

                Divider()

                Group {
                    NavigationLink("Test: ContentView (Full App)") {
                        ContentView()
                    }

                    NavigationLink("Test: ScheduleView Only") {
                        ScheduleView()
                    }

                    NavigationLink("Test: ScheduleListView (direct)") {
                        ScheduleListView()
                    }

                    NavigationLink("Test: ClientsView Only") {
                        ClientsView()
                    }

                    NavigationLink("Test: SettingsView Only") {
                        SettingsView()
                    }
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding()
            .navigationTitle("Debug")
        }
    }
}
