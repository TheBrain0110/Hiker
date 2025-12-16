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

        // Create CompletedHike record
        let completedHike = CompletedHike(
            date: date,
            hikeNumber: hike.number,
            routeLatitudes: hike.route.map { $0.latitude },
            routeLongitudes: hike.route.map { $0.longitude },
            trailLocationId: selectedTrail?.id,
            trailName: selectedTrail?.name,
            totalDistance: hike.totalDistance,
            notes: notes.isEmpty ? nil : notes
        )

        modelContext.insert(completedHike)

        // Create DogAttendance records for attending dogs
        for (index, dog) in hike.dogs.enumerated() where attendingDogs.contains(dog.id) {
            let attendance = DogAttendance(
                dogId: dog.id,
                dogName: dog.name,
                pickupOrder: index + 1,
                pickupLatitude: dog.location?.latitude,
                pickupLongitude: dog.location?.longitude,
                pickupAddress: dog.locationAddress,
                amountCharged: dog.paymentRate
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Dog.self, HikingLocation.self,
        configurations: config
    )

    let client = Client(ownerName: "Test Owner", address: "123 Test St")
    let dog1 = Dog(name: "Buddy", client: client, locationAddress: "123 Test St", regularSchedule: [.monday])
    let dog2 = Dog(name: "Max", client: client, locationAddress: "456 Oak Ave", regularSchedule: [.monday])

    container.mainContext.insert(client)
    container.mainContext.insert(dog1)
    container.mainContext.insert(dog2)

    let hike = DailyHike.Hike(
        number: 1,
        dogs: [dog1, dog2],
        route: [],
        totalDistance: 5000,
        suggestedTrail: nil
    )

    return CompleteHikeSheet(date: Date(), hike: hike)
        .modelContainer(container)
}
