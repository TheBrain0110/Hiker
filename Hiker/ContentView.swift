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
                            Text("Welcome to Happy Hound Hikes")
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
                    }
                } else {
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

                    Section {
                        Button(role: .destructive, action: clearAllData) {
                            Label("Clear All Data", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Hiker")
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

#Preview {
    ContentView()
        .modelContainer(for: Client.self, inMemory: true)
}
