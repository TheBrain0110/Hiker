//
//  DayDetailView.swift
//  Hiker
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData
import MapKit

struct DayDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var currentDate: Date

    @Query(sort: \CompletedHike.date, order: .reverse)
    private var completedHikes: [CompletedHike]

    @Query(filter: #Predicate<Dog> { $0.isActive }, sort: \Dog.name)
    private var activeDogs: [Dog]

    @Query private var scheduleOverrides: [ScheduleOverride]

    @State private var dailySchedule: DailyHike?
    @State private var selectedHike: DailyHike.Hike?
    @State private var isEditing = false

    // Initialize with a starting date
    init(date: Date) {
        _currentDate = State(initialValue: date)
    }

    private var isToday: Bool {
        Calendar.current.isDate(currentDate, inSameDayAs: Date())
    }

    private var isPast: Bool {
        currentDate < Calendar.current.startOfDay(for: Date())
    }

    private var isFuture: Bool {
        currentDate > Calendar.current.startOfDay(for: Date())
    }

    private var completedHikesForDay: [CompletedHike] {
        completedHikes.filter { hike in
            Calendar.current.isDate(hike.date, inSameDayAs: currentDate)
        }
    }

    // Check if there are any pending (uncompleted) hikes for this day
    private var hasPendingHikes: Bool {
        guard let schedule = dailySchedule, !schedule.isEmpty else { return false }

        // If it's a future day, all hikes are pending
        if isFuture { return true }

        // For past/today, check if any hikes are not yet completed
        return schedule.hikes.contains { plannedHike in
            !completedHikesForDay.contains { completedHike in
                completedHike.hikeNumber == plannedHike.number
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date header
                VStack(spacing: 8) {
                    Text(dateFormatter.string(from: currentDate))
                        .font(.title2)
                        .fontWeight(.semibold)

                    if isToday {
                        Text("Today")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.top)

                // Unified day content (handles past/today/future with conditionals)
                dayContent
            }
            .padding()
        }
        .navigationTitle("Day Schedule")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button(action: previousDay) {
                        Image(systemName: "chevron.left")
                    }

                    Button(action: jumpToToday) {
                        Image(systemName: "calendar")
                    }
                    .disabled(isToday)

                    Button(action: nextDay) {
                        Image(systemName: "chevron.right")
                    }
                }

                // Edit button (only for days with pending hikes)
                if hasPendingHikes {
                    Button(isEditing ? "Done" : "Edit") {
                        withAnimation {
                            isEditing.toggle()
                        }
                    }
                }
            }
        }
        .onAppear {
            loadSchedule()
        }
        .onChange(of: currentDate) {
            loadSchedule()
        }
        .onChange(of: activeDogs) {
            loadSchedule()
        }
        .onChange(of: scheduleOverrides) {
            loadSchedule()
        }
        .sheet(item: $selectedHike) { hike in
            CompleteHikeSheet(date: currentDate, hike: hike)
        }
    }

    // MARK: - Unified Day Content

    private var dayContent: some View {
        VStack(spacing: 16) {
            // Completed hikes (for past and today)
            if !completedHikesForDay.isEmpty {
                ForEach(completedHikesForDay) { completedHike in
                    CompletedHikeCard(completedHike: completedHike)
                }
            }

            // Planned hikes section
            if let schedule = dailySchedule, !schedule.isEmpty {
                let pendingHikes = isPast || isToday
                    ? schedule.hikes.filter { plannedHike in
                        !completedHikesForDay.contains { completedHike in
                            completedHike.hikeNumber == plannedHike.number
                        }
                      }
                    : schedule.hikes  // Future: show all (none complete yet)

                if !pendingHikes.isEmpty {
                    // Warning header (only for past uncompleted hikes)
                    if isPast {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Uncompleted Hikes")
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal)

                            Text("These hikes were scheduled but not marked complete. Tap to complete retroactively.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        }
                    }

                    ForEach(pendingHikes) { hike in
                        PlannedHikeCard(
                            hike: hike,
                            isEditing: isEditing,
                            scheduleOverrides: scheduleOverrides,
                            currentDate: currentDate,
                            onMarkComplete: isFuture ? nil : { selectedHike = hike },  // Enable for past + today
                            onRemoveDog: isPast ? nil : { dog in removeDog(dog) }      // Disable for past
                        )
                    }
                }
            }

            // Empty state
            if completedHikesForDay.isEmpty && (dailySchedule?.isEmpty ?? true) {
                ContentUnavailableView(
                    "No Hikes Scheduled",
                    systemImage: "calendar",
                    description: Text(emptyStateText)
                )
                .padding(.top, 40)
            }

            // Available to Add (only for days with pending hikes in edit mode)
            if isEditing && hasPendingHikes {
                availableToAddSection
            }
        }
    }

    private var emptyStateText: String {
        if isPast {
            return "No hikes were scheduled for this day."
        } else if isToday {
            return "No dogs are scheduled for today."
        } else {
            return "No dogs are scheduled for this day."
        }
    }

    // MARK: - Available to Add Section

    private var availableToAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !availableDogs.isEmpty {
                Text("Available to Add")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(availableDogs) { dog in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(dog.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                // Show "Removed" badge if dog has .isAbsent override
                                if isOverriddenAbsent(dog) {
                                    Badge(text: "Removed", color: .red)
                                }
                            }

                            Text(dog.client?.ownerName ?? "Unknown Owner")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            addDog(dog)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                                .imageScale(.large)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.background.secondary)
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top, 16)
    }

    private var allScheduledDogs: [Dog] {
        guard let schedule = dailySchedule else { return [] }
        return schedule.hikes.flatMap { $0.dogs }
    }

    private var availableDogs: [Dog] {
        let scheduledIds = Set(allScheduledDogs.map { $0.id })
        return activeDogs.filter { !scheduledIds.contains($0.id) && $0.isActive }
    }

    private func isOverriddenAbsent(_ dog: Dog) -> Bool {
        scheduleOverrides.contains { override in
            Calendar.current.isDate(override.date, inSameDayAs: currentDate) &&
            override.dogId == dog.id &&
            override.type == .isAbsent
        }
    }

    // MARK: - Helper Methods

    private func loadSchedule() {
        let manager = DailyHikeManager(modelContext: modelContext)
        dailySchedule = manager.dailySchedule(for: currentDate)
    }

    private func previousDay() {
        if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) {
            withAnimation {
                currentDate = newDate
            }
        }
    }

    private func nextDay() {
        if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) {
            withAnimation {
                currentDate = newDate
            }
        }
    }

    private func jumpToToday() {
        withAnimation {
            currentDate = Calendar.current.startOfDay(for: Date())
        }
    }

    private func addDog(_ dog: Dog) {
        // Check if there's an existing override
        if let existing = scheduleOverrides.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: currentDate) && $0.dogId == dog.id
        }) {
            // Override exists (likely .isAbsent) - delete it to revert to regular schedule
            modelContext.delete(existing)
        } else {
            // No override exists, check if dog is in regular schedule for this day
            let dayOfWeek = currentDate.dayOfWeek
            let isInRegularSchedule = dayOfWeek.map { dog.regularSchedule.contains($0) } ?? false

            if !isInRegularSchedule {
                // Not in regular schedule, so create .isPresent override
                let override = ScheduleOverride(dogId: dog.id, date: currentDate, type: .isPresent)
                modelContext.insert(override)
            }
            // If already in regular schedule, do nothing (shouldn't reach here via UI)
        }

        // Reload schedule to reflect changes
        loadSchedule()
    }

    private func removeDog(_ dog: Dog) {
        // Check if there's an existing override
        if let existing = scheduleOverrides.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: currentDate) && $0.dogId == dog.id
        }) {
            if existing.type == .isPresent {
                // Was added manually, so just delete the override
                modelContext.delete(existing)
            } else {
                // Already has .isAbsent, do nothing
            }
        } else {
            // Dog is here from regular schedule, create .isAbsent override
            let override = ScheduleOverride(dogId: dog.id, date: currentDate, type: .isAbsent)
            modelContext.insert(override)
        }

        // Reload schedule to reflect changes
        loadSchedule()
    }
}

// MARK: - Placeholder Cards (to be implemented)

private struct CompletedHikeCard: View {
    let completedHike: CompletedHike

    @State private var isExpanded = true

    private var mapPosition: MapCameraPosition {
        if let firstCoordinate = completedHike.route.first {
            return .region(MKCoordinateRegion(
                center: firstCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
        return .automatic
    }

    // Sort attendances by pickup order
    private var orderedAttendances: [DogAttendance] {
        completedHike.dogAttendances.sorted { $0.pickupOrder < $1.pickupOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with expand/collapse
            hikeHeader
                .padding()
                .background(Color.green.opacity(0.1))

            if isExpanded {
                Divider()

                // Dog List with pickup order
                if !orderedAttendances.isEmpty {
                    dogList
                        .padding(.vertical, 12)
                }

                // Removed Dogs Section
                if !completedHike.removedDogNames.isEmpty {
                    Divider()
                    removedDogsSection
                        .padding()
                }

                // Route Map
                if !completedHike.route.isEmpty {
                    Divider()
                    routeMap
                        .frame(height: 200)
                }

                // Trail Info
                if let trailName = completedHike.trailName {
                    Divider()
                    trailInfo(trailName)
                        .padding()
                }

                // Notes
                if let notes = completedHike.notes, !notes.isEmpty {
                    Divider()
                    notesSection(notes)
                        .padding()
                }
            }
        }
        .background(.background.secondary)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    // MARK: - Header

    private var hikeHeader: some View {
        Button(action: { withAnimation { isExpanded.toggle() } }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Hike \(completedHike.hikeNumber)")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .imageScale(.small)
                    }

                    Text("\(completedHike.dogCount) dogs • \(String(format: "%.1f km", completedHike.totalDistance / 1000))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.green)
                    .imageScale(.small)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dog List

    private var dogList: some View {
        VStack(spacing: 0) {
            ForEach(Array(orderedAttendances.enumerated()), id: \.element.id) { index, attendance in
                CompletedHikeDogRow(attendance: attendance)

                if index < orderedAttendances.count - 1 {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
    }

    // MARK: - Removed Dogs Section

    private var removedDogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .imageScale(.medium)
                Text("Removed from Schedule")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(completedHike.removedDogNames.enumerated()), id: \.offset) { index, dogName in
                    HStack(spacing: 12) {
                        Image(systemName: "pawprint.fill")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.6))
                            .frame(width: 20)

                        Text(dogName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Badge(text: "Removed", color: .red)

                        Spacer()
                    }
                }
            }
            .padding(.leading, 28)
        }
    }

    // MARK: - Map

    private var routeMap: some View {
        Map(initialPosition: mapPosition) {
            // Show pickup locations as numbered markers
            ForEach(Array(completedHike.route.enumerated()), id: \.offset) { index, coordinate in
                Annotation("\(index + 1)", coordinate: coordinate) {
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 30, height: 30)
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
            }

            // Draw route line
            if completedHike.route.count > 1 {
                MapPolyline(coordinates: completedHike.route)
                    .stroke(.green, lineWidth: 3)
            }
        }
        .mapStyle(.standard)
        .allowsHitTesting(false)
    }

    // MARK: - Trail Info

    private func trailInfo(_ trailName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("Trail")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(trailName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
    }

    // MARK: - Notes

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notes")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(notes)
                .font(.subheadline)
        }
    }
}

// MARK: - Completed Hike Dog Row

private struct CompletedHikeDogRow: View {
    @Environment(\.modelContext) private var modelContext
    let attendance: DogAttendance

    // Look up the dog by ID to enable navigation
    private var dog: Dog? {
        let dogId = attendance.dogId
        let descriptor = FetchDescriptor<Dog>(
            predicate: #Predicate<Dog> { $0.id == dogId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    var body: some View {
        Group {
            if let dog = dog {
                // If dog still exists, make row tappable
                NavigationLink {
                    DogDetailView(dog: dog)
                } label: {
                    rowContent
                }
            } else {
                // If dog was deleted, show non-tappable row
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            // Pickup number badge
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text("\(attendance.pickupOrder)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }

            // Dog info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(attendance.dogName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // "Added" badge for override dogs
                    if attendance.wasAddedViaOverride {
                        Badge(text: "Added", color: .green)
                    }
                }

                if let address = attendance.pickupAddress {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount charged
            Text("$\(attendance.amountCharged as NSDecimalNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

private struct PlannedHikeCard: View {
    let hike: DailyHike.Hike
    let isEditing: Bool
    let scheduleOverrides: [ScheduleOverride]
    let currentDate: Date
    let onMarkComplete: (() -> Void)?
    let onRemoveDog: ((Dog) -> Void)?

    @State private var isExpanded = true

    private var mapPosition: MapCameraPosition {
        if let firstCoordinate = hike.route.first {
            return .region(MKCoordinateRegion(
                center: firstCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
        return .automatic
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with expand/collapse
            hikeHeader
                .padding()
                .background(Color.blue.opacity(0.1))

            if isExpanded {
                Divider()

                // Dog List with pickup order
                dogList
                    .padding(.vertical, 12)

                // Route Map
                if !hike.route.isEmpty {
                    Divider()
                    routeMap
                        .frame(height: 200)
                }

                // Suggested Trail
                if let trail = hike.suggestedTrail {
                    Divider()
                    trailSuggestion(trail)
                        .padding()
                }

                // Mark Complete Button (only show if closure provided)
                if let onMarkComplete = onMarkComplete {
                    Divider()
                    Button(action: onMarkComplete) {
                        Label("Mark Complete", systemImage: "checkmark.circle")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .padding()
                }
            }
        }
        .background(.background.secondary)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    // MARK: - Header

    private var hikeHeader: some View {
        Button(action: { withAnimation { isExpanded.toggle() } }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hike \(hike.number)")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(hike.dogCount) dogs • \(String(format: "%.1f km", hike.totalDistance / 1000))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.blue)
                    .imageScale(.small)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dog List

    private var dogList: some View {
        VStack(spacing: 0) {
            ForEach(Array(hike.dogs.enumerated()), id: \.element.id) { index, dog in
                PlannedHikeDogRow(
                    dog: dog,
                    pickupOrder: index + 1,
                    showAddedBadge: showAddedBadge(dog),
                    isEditing: isEditing,
                    onRemove: onRemoveDog
                )

                if index < hike.dogs.count - 1 {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
    }

    private func showAddedBadge(_ dog: Dog) -> Bool {
        scheduleOverrides.contains { override in
            Calendar.current.isDate(override.date, inSameDayAs: currentDate) &&
            override.dogId == dog.id &&
            override.type == .isPresent
        }
    }

    // MARK: - Map

    private var routeMap: some View {
        Map(initialPosition: mapPosition) {
            // Show pickup locations as numbered markers
            ForEach(Array(hike.route.enumerated()), id: \.offset) { index, coordinate in
                Annotation("\(index + 1)", coordinate: coordinate) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 30)
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
            }

            // Draw route line
            if hike.route.count > 1 {
                MapPolyline(coordinates: hike.route)
                    .stroke(.blue, lineWidth: 3)
            }
        }
        .mapStyle(.standard)
        .allowsHitTesting(false)
    }

    // MARK: - Trail Suggestion

    private func trailSuggestion(_ trail: HikingLocation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Suggested Trail")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(trail.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(trail.region)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Planned Hike Dog Row

private struct PlannedHikeDogRow: View {
    let dog: Dog
    let pickupOrder: Int
    let showAddedBadge: Bool
    let isEditing: Bool
    let onRemove: ((Dog) -> Void)?

    var body: some View {
        NavigationLink {
            DogDetailView(dog: dog)
        } label: {
            HStack(spacing: 12) {
                // Pickup number badge
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Text("\(pickupOrder)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }

                // Dog info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(dog.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        // "Added" badge (always visible if override)
                        if showAddedBadge {
                            Badge(text: "Added", color: .green)
                        }
                    }

                    if let address = dog.locationAddress {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Remove button (only in edit mode)
                if isEditing, let onRemove = onRemove {
                    Button {
                        onRemove(dog)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                }

                // Payment rate
                Text("$\(dog.paymentRate as NSDecimalNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        // Swipe actions (iOS only)
        #if os(iOS)
        .swipeActions(edge: .trailing) {
            if let onRemove = onRemove {
                Button(role: .destructive) {
                    onRemove(dog)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        #endif
    }
}

// FutureHikeCard removed - now using PlannedHikeCard for both today and future days

#Preview {
    NavigationStack {
        DayDetailView(date: Date())
    }
}
