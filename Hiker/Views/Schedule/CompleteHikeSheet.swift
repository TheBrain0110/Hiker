//
//  CompleteHikeSheet.swift
//  Hiker
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct CompleteHikeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let date: Date
    @Bindable var hike: DailyHike

    @Query(filter: #Predicate<HikingLocation> { $0.isActive }, sort: \HikingLocation.name)
    private var hikingLocations: [HikingLocation]

    @Query(filter: #Predicate<Dog> { $0.isActive }, sort: \Dog.name)
    private var activeDogs: [Dog]

    @Query private var scheduleOverrides: [ScheduleOverride]

    @State private var attendingDogs: Set<UUID>
    @State private var selectedTrail: HikingLocation?
    @State private var notes: String = ""
    @State private var isSaving = false

    init(date: Date, hike: DailyHike) {
        self.date = date
        self._hike = Bindable(wrappedValue: hike)

        // Pre-select all participating dogs as attending
        _attendingDogs = State(initialValue: Set(hike.orderedParticipations.map { $0.dogId }))

        // Pre-fill notes from hike if any
        _notes = State(initialValue: hike.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Dog Attendance
                Section {
                    ForEach(Array(hike.orderedParticipations.enumerated()), id: \.element.id) { index, participation in
                        Toggle(isOn: Binding(
                            get: { attendingDogs.contains(participation.dogId) },
                            set: { isAttending in
                                if isAttending {
                                    attendingDogs.insert(participation.dogId)
                                } else {
                                    attendingDogs.remove(participation.dogId)
                                }
                            }
                        )) {
                            HStack {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .trailing)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(participation.dogName)
                                        .font(.subheadline)

                                    if let address = participation.pickupAddress {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Dog Attendance")
                } footer: {
                    Text("\(attendingDogs.count) of \(hike.orderedParticipations.count) dogs attending")
                }

                // Trail Selection
                Section("Trail") {
                    Picker("Select Trail", selection: $selectedTrail) {
                        Text("None").tag(nil as HikingLocation?)

                        ForEach(hikingLocations) { location in
                            Text(location.name).tag(location as HikingLocation?)
                        }
                    }
                    .labelsHidden()
                }

                // Notes
                Section("Notes") {
                    TextField("Add notes about this hike", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Complete Hike \(hike.hikeNumber)")
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
                    Button("Complete") {
                        completeHike()
                    }
                    .disabled(attendingDogs.isEmpty || isSaving)
                }
            }
            .onAppear {
                // Pre-select trail from hike if set
                if let trailId = hike.selectedTrailId {
                    selectedTrail = hikingLocations.first { $0.id == trailId }
                }
            }
        }
    }

    // MARK: - Complete Hike

    private func completeHike() {
        isSaving = true

        let normalizedDate = Calendar.current.startOfDay(for: date)

        // Find schedule overrides for this date (for tracking removed dogs)
        let overridesForDate = scheduleOverrides.filter { override in
            Calendar.current.isDate(override.date, inSameDayAs: normalizedDate)
        }

        // Find removed dogs (dogs with .isAbsent override that would have been scheduled)
        var removedDogIds: [UUID] = []
        var removedDogNames: [String] = []

        if let dayOfWeek = normalizedDate.dayOfWeek {
            for dog in activeDogs {
                // Check if dog is in regular schedule for this day
                let isInRegularSchedule = dog.regularSchedule.contains(dayOfWeek)

                // Check if dog has .isAbsent override
                let hasAbsentOverride = overridesForDate.contains { override in
                    override.dogId == dog.id && override.type == .isAbsent
                }

                // If in regular schedule but has absent override, they were removed
                if isInRegularSchedule && hasAbsentOverride {
                    removedDogIds.append(dog.id)
                    removedDogNames.append(dog.name)
                }
            }
        }

        // Update the DailyHike to mark as completed
        hike.completedAt = Date()
        hike.selectedTrailId = selectedTrail?.id
        hike.trailName = selectedTrail?.name
        hike.notes = notes.isEmpty ? nil : notes
        hike.removedDogIds = removedDogIds
        hike.removedDogNames = removedDogNames
        hike.lastModifiedAt = Date()

        // Update participation records for attendance confirmation
        for participation in hike.participations {
            participation.isConfirmed = attendingDogs.contains(participation.dogId)
        }

        // Save context
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving completed hike: \(error)")
            isSaving = false
        }
    }
}

#Preview {
    let schema = Schema([Client.self, Dog.self, Payment.self, ScheduleOverride.self, HikingLocation.self, DailyHike.self, HikeParticipation.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    SampleData.createSampleData(in: container.mainContext)

    // Get a hike from sample data
    let manager = DailyHikeManager(modelContext: container.mainContext)
    let hikes = manager.getDailyHikes(for: Date())

    return Group {
        if let hike = hikes.first {
            CompleteHikeSheet(date: Date(), hike: hike)
        } else {
            Text("No hike available")
        }
    }
    .modelContainer(container)
}
