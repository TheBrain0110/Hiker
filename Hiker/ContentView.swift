//
//  ContentView.swift
//  Hiker
//
//  Created by Andrew Puddington on 11/7/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            // Home: Today's Schedule
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "calendar")
                }

            // Weekly Schedule (placeholder)
            PlaceholderTab(title: "Weekly", icon: "calendar.day.timeline.left")
                .tabItem {
                    Label("Weekly", systemImage: "calendar.day.timeline.left")
                }

            // Clients (placeholder)
            PlaceholderTab(title: "Clients", icon: "person.2")
                .tabItem {
                    Label("Clients", systemImage: "person.2")
                }

            // Settings & Data Management
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.ownerName) private var clients: [Client]
    @Query(sort: \Dog.name) private var dogs: [Dog]
    @Query private var hikingLocations: [HikingLocation]

    var body: some View {
        NavigationStack {
            List {
                Section("Happy Hound Hikes") {
                    HStack {
                        Image(systemName: "pawprint.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text("Happy Hound Hikes")
                                .font(.headline)
                            Text("\(clients.count) clients • \(dogs.count) dogs • \(hikingLocations.count) trails")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if clients.isEmpty {
                    Section {
                        Button(action: loadSampleData) {
                            Label("Load Sample Data", systemImage: "square.and.arrow.down")
                        }
                    } footer: {
                        Text("Load sample clients, dogs, and hiking locations to test the app.")
                    }
                } else {
                    Section("Data") {
                        NavigationLink {
                            DataDetailView(clients: clients, hikingLocations: hikingLocations)
                        } label: {
                            Label("View All Data", systemImage: "list.bullet")
                        }

                        Button(role: .destructive, action: clearAllData) {
                            Label("Clear All Data", systemImage: "trash")
                        }
                    } footer: {
                        Text("Clear all clients, dogs, payments, schedules, and hiking locations.")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func loadSampleData() {
        Task { @MainActor in
            SampleData.createSampleData(in: modelContext)
        }
    }

    private func clearAllData() {
        Task { @MainActor in
            try? modelContext.delete(model: Client.self)
            try? modelContext.delete(model: Dog.self)
            try? modelContext.delete(model: Payment.self)
            try? modelContext.delete(model: ScheduleException.self)
            try? modelContext.delete(model: HikingLocation.self)
        }
    }
}

// MARK: - Data Detail View

struct DataDetailView: View {
    let clients: [Client]
    let hikingLocations: [HikingLocation]

    var body: some View {
        List {
            Section("Clients & Dogs") {
                ForEach(clients) { client in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(client.ownerName)
                            .font(.headline)
                        if !client.dogs.isEmpty {
                            Text(client.dogs.map { $0.name }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Hiking Locations") {
                ForEach(hikingLocations) { location in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.name)
                            .font(.headline)
                        Text(location.region)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("All Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Placeholder Tab

struct PlaceholderTab: View {
    let title: String
    let icon: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "\(title) View",
                systemImage: icon,
                description: Text("This feature is coming soon.")
            )
            .navigationTitle(title)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Client.self, inMemory: true)
}
