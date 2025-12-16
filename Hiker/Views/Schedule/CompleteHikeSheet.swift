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
    let hike: DailyHike.Hike

    @Query(filter: #Predicate<HikingLocation> { $0.isActive }, sort: \HikingLocation.name)
    private var hikingLocations: [HikingLocation]

    @Query(filter: #Predicate<Dog> { $0.isActive }, sort: \Dog.name)
    private var activeDogs: [Dog]

    @Query private var scheduleOverrides: [ScheduleOverride]

    @State private var attendingDogs: Set<UUID>
    @State private var selectedTrail: HikingLocation?
    @State private var notes: String = ""
    @State private var isSaving = false

    init(date: Date, hike: DailyHike.Hike) {
        self.date = date
        self.hike = hike

        // Pre-select all dogs as attending
        _attendingDogs = State(initialValue: Set(hike.dogs.map { $0.id }))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Dog Attendance
                Section {
                    ForEach(Array(hike.dogs.enumerated()), id: \.element.id) { index, dog in
                        Toggle(isOn: Binding(
                            get: { attendingDogs.contains(dog.id) },
                            set: { isAttending in
                                if isAttending {
                                    attendingDogs.insert(dog.id)
                                } else {
                                    attendingDogs.remove(dog.id)
                                }
                            }
                        )) {
                            HStack {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .trailing)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dog.name)
                                        .font(.subheadline)

                                    if let address = dog.locationAddress {
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
                    Text("\(attendingDogs.count) of \(hike.dogs.count) dogs attending")
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
            .navigationTitle("Complete Hike \(hike.number)")
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
                // Pre-select suggested trail
                selectedTrail = hike.suggestedTrail
            }
        }
    }

    // MARK: - Complete Hike

    private func completeHike() {
        isSaving = true

        // Find schedule overrides for this date
        let normalizedDate = Calendar.current.startOfDay(for: date)
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

        // Create CompletedHike record
        let completedHike = CompletedHike(
            date: date,
            hikeNumber: hike.number,
            routeLatitudes: hike.route.map { $0.latitude },
            routeLongitudes: hike.route.map { $0.longitude },
            trailLocationId: selectedTrail?.id,
            trailName: selectedTrail?.name,
            totalDistance: hike.totalDistance,
            notes: notes.isEmpty ? nil : notes,
            removedDogIds: removedDogIds,
            removedDogNames: removedDogNames
        )

        modelContext.insert(completedHike)

        // Create DogAttendance records for attending dogs
        let attendingDogsList = hike.dogs.filter { attendingDogs.contains($0.id) }

        for (index, dog) in attendingDogsList.enumerated() {
            // Check if this dog was added via .isPresent override
            let hasAddedOverride = overridesForDate.contains { override in
                override.dogId == dog.id && override.type == .isPresent
            }

            let attendance = DogAttendance(
                dogId: dog.id,
                dogName: dog.name,
                pickupOrder: index + 1,
                pickupLatitude: dog.location?.latitude,
                pickupLongitude: dog.location?.longitude,
                pickupAddress: dog.locationAddress,
                amountCharged: dog.paymentRate,
                wasAddedViaOverride: hasAddedOverride
            )

            attendance.completedHike = completedHike
            modelContext.insert(attendance)
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
    let schema = Schema([Client.self, Dog.self, Payment.self, ScheduleOverride.self, HikingLocation.self, CompletedHike.self, DogAttendance.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    SampleData.createSampleData(in: container.mainContext)

    // Get a hike from sample data
    let manager = DailyHikeManager(modelContext: container.mainContext)
    let schedule = manager.dailySchedule(for: Date())

    return Group {
        if let hike = schedule.hike1 {
            CompleteHikeSheet(date: Date(), hike: hike)
        } else {
            Text("No hike available")
        }
    }
    .modelContainer(container)
}
