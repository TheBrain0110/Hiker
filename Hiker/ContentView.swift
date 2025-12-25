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
            // Unified Schedule View (replaces Today + Weekly)
            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }

            // Clients
            ClientsView()
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

                Section("Configuration") {
                    NavigationLink {
                        HikingLocationsView()
                    } label: {
                        Label("Hiking Locations", systemImage: "figure.hiking")
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
                    Section {
                        NavigationLink {
                            DataDetailView(clients: clients, hikingLocations: hikingLocations)
                        } label: {
                            Label("View All Data", systemImage: "list.bullet")
                        }

                        Button(role: .destructive, action: clearAllData) {
                            Label("Clear All Data", systemImage: "trash")
                        }
                    } header: {
                        Text("Data")
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
            try? modelContext.delete(model: ScheduleOverride.self)
            try? modelContext.delete(model: HikingLocation.self)
            try? modelContext.delete(model: CompletedHike.self)
            try? modelContext.delete(model: DogAttendance.self)
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
    }
}

#Preview {
    let schema = Schema([Client.self, Dog.self, Payment.self, ScheduleOverride.self, HikingLocation.self, CompletedHike.self, DogAttendance.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    SampleData.createSampleData(in: container.mainContext)

    return ContentView()
        .modelContainer(container)
}
