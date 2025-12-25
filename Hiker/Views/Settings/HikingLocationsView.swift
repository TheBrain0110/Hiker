//
//  HikingLocationsView.swift
//  Hiker
//
//  Created by Claude on 12/20/25.
//

import SwiftUI
import SwiftData

struct HikingLocationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HikingLocation.name) private var locations: [HikingLocation]

    @State private var showingAddLocation = false

    var activeLocations: [HikingLocation] {
        locations.filter { $0.isActive }
    }

    var inactiveLocations: [HikingLocation] {
        locations.filter { !$0.isActive }
    }

    var body: some View {
        List {
            // Active Locations
            Section {
                if activeLocations.isEmpty {
                    Text("No hiking locations")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activeLocations) { location in
                        NavigationLink {
                            HikingLocationDetailView(location: location)
                        } label: {
                            HikingLocationRow(location: location)
                        }
                    }
                    .onDelete { indexSet in
                        deleteLocations(at: indexSet, from: activeLocations)
                    }
                }
            } header: {
                HStack {
                    Text("Hiking Locations")
                    Spacer()
                    Button {
                        showingAddLocation = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            } footer: {
                if !activeLocations.isEmpty {
                    Text("\(activeLocations.count) active location\(activeLocations.count == 1 ? "" : "s")")
                }
            }

            // Inactive Locations
            if !inactiveLocations.isEmpty {
                Section("Inactive") {
                    ForEach(inactiveLocations) { location in
                        NavigationLink {
                            HikingLocationDetailView(location: location)
                        } label: {
                            HikingLocationRow(location: location)
                        }
                    }
                    .onDelete { indexSet in
                        deleteLocations(at: indexSet, from: inactiveLocations)
                    }
                }
            }
        }
        .navigationTitle("Hiking Locations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddLocation = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddLocation) {
            AddHikingLocationView()
        }
    }

    private func deleteLocations(at offsets: IndexSet, from locationList: [HikingLocation]) {
        for index in offsets {
            let location = locationList[index]
            modelContext.delete(location)
        }
    }
}

// MARK: - Hiking Location Row

struct HikingLocationRow: View {
    let location: HikingLocation

    var body: some View {
        HStack(spacing: 12) {
            // Location icon
            ZStack {
                Circle()
                    .fill(regionColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: "figure.hiking")
                    .font(.body)
                    .foregroundStyle(regionColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(location.name)
                        .font(.headline)

                    if !location.isActive {
                        Badge(text: "Inactive", color: .gray)
                    }
                }

                Text(location.region)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var regionColor: Color {
        guard location.isActive else { return .gray }
        switch location.region.lowercased() {
        case "bedford": return .blue
        case "sackville": return .green
        case "beaver bank": return .orange
        default: return .blue
        }
    }
}

// MARK: - Add Hiking Location View

struct AddHikingLocationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var region = "Bedford"
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var notes = ""

    private let regions = ["Bedford", "Sackville", "Beaver Bank"]

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(latitude) != nil &&
        Double(longitude) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Location Information") {
                    TextField("Name", text: $name)

                    Picker("Region", selection: $region) {
                        ForEach(regions, id: \.self) { region in
                            Text(region).tag(region)
                        }
                    }
                }

                Section {
                    TextField("Latitude", text: $latitude)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif

                    TextField("Longitude", text: $longitude)
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        #endif
                } header: {
                    Text("Coordinates")
                } footer: {
                    Text("Enter GPS coordinates for the trailhead. Halifax area is approximately 44.6° N, -63.6° W.")
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Location")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addLocation()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func addLocation() {
        guard let lat = Double(latitude), let lon = Double(longitude) else { return }

        let location = HikingLocation(
            name: name.trimmingCharacters(in: .whitespaces),
            latitude: lat,
            longitude: lon,
            region: region,
            notes: notes.isEmpty ? nil : notes
        )

        modelContext.insert(location)
        dismiss()
    }
}

// MARK: - Hiking Location Detail View

struct HikingLocationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var location: HikingLocation

    @State private var showingEditSheet = false

    var body: some View {
        List {
            // Header
            Section {
                locationHeader
            }

            // Details
            Section("Details") {
                LabeledContent("Region", value: location.region)
                LabeledContent("Latitude", value: String(format: "%.4f", location.latitude))
                LabeledContent("Longitude", value: String(format: "%.4f", location.longitude))
            }

            // Notes
            if let notes = location.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .foregroundStyle(.secondary)
                }
            }

            // Status
            Section {
                Toggle("Active", isOn: $location.isActive)
            } footer: {
                Text("Inactive locations won't appear in trail selection.")
            }
        }
        .navigationTitle(location.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditHikingLocationView(location: location)
        }
    }

    private var locationHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(regionColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: "figure.hiking")
                    .font(.title)
                    .foregroundStyle(regionColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    Label(location.region, systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !location.isActive {
                        Badge(text: "Inactive", color: .gray)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var regionColor: Color {
        guard location.isActive else { return .gray }
        switch location.region.lowercased() {
        case "bedford": return .blue
        case "sackville": return .green
        case "beaver bank": return .orange
        default: return .blue
        }
    }
}

// MARK: - Edit Hiking Location View

struct EditHikingLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var location: HikingLocation

    @State private var latitudeString: String = ""
    @State private var longitudeString: String = ""

    private let regions = ["Bedford", "Sackville", "Beaver Bank"]

    var isValid: Bool {
        !location.name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(latitudeString) != nil &&
        Double(longitudeString) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Location Information") {
                    TextField("Name", text: $location.name)

                    Picker("Region", selection: $location.region) {
                        ForEach(regions, id: \.self) { region in
                            Text(region).tag(region)
                        }
                    }
                }

                Section {
                    TextField("Latitude", text: $latitudeString)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .onChange(of: latitudeString) { _, newValue in
                            if let lat = Double(newValue) {
                                location.latitude = lat
                            }
                        }

                    TextField("Longitude", text: $longitudeString)
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        #endif
                        .onChange(of: longitudeString) { _, newValue in
                            if let lon = Double(newValue) {
                                location.longitude = lon
                            }
                        }
                } header: {
                    Text("Coordinates")
                } footer: {
                    Text("Enter GPS coordinates for the trailhead.")
                }

                Section("Notes") {
                    TextField("Notes", text: Binding(
                        get: { location.notes ?? "" },
                        set: { location.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Location")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                latitudeString = String(format: "%.6f", location.latitude)
                longitudeString = String(format: "%.6f", location.longitude)
            }
        }
    }
}

#Preview {
    let schema = Schema([Client.self, Dog.self, Payment.self, ScheduleOverride.self, HikingLocation.self, CompletedHike.self, DogAttendance.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    SampleData.createSampleData(in: container.mainContext)

    return NavigationStack {
        HikingLocationsView()
    }
    .modelContainer(container)
}
