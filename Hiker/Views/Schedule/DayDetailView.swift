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

    @Query(sort: \DailyHike.date, order: .reverse)
    private var allDailyHikes: [DailyHike]

    @Query(filter: #Predicate<Dog> { $0.isActive }, sort: \Dog.name)
    private var activeDogs: [Dog]

    @Query private var scheduleOverrides: [ScheduleOverride]

    @State private var selectedHike: DailyHike?
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

    // Get all hikes for this day (both planned and completed)
    private var hikesForDay: [DailyHike] {
        allDailyHikes.filter { hike in
            Calendar.current.isDate(hike.date, inSameDayAs: currentDate)
        }.sorted { $0.hikeNumber < $1.hikeNumber }
    }

    private var completedHikesForDay: [DailyHike] {
        hikesForDay.filter { $0.isCompleted }
    }

    private var plannedHikesForDay: [DailyHike] {
        hikesForDay.filter { $0.isPlanned }
    }

    // Check if there are any pending (uncompleted) hikes for this day
    private var hasPendingHikes: Bool {
        !plannedHikesForDay.isEmpty
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

                // Edit button (always visible for consistent layout, disabled when no pending hikes)
                Button(isEditing ? "Done" : "Edit") {
                    withAnimation {
                        isEditing.toggle()
                    }
                }
                .disabled(!hasPendingHikes)
            }
        }
        .onAppear {
            loadHikesIfNeeded()
        }
        .onChange(of: currentDate) {
            // Exit edit mode when changing days
            isEditing = false
            loadHikesIfNeeded()
        }
        .onChange(of: activeDogs) {
            // Re-check if we need to create hikes
            loadHikesIfNeeded()
        }
        .onChange(of: scheduleOverrides) {
            // Re-check if we need to update hikes
            loadHikesIfNeeded()
        }
        .sheet(item: $selectedHike) { hike in
            CompleteHikeSheet(date: currentDate, hike: hike)
        }
        // Keyboard navigation for arrow keys
        .onKeyPress(.leftArrow) {
            previousDay()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            nextDay()
            return .handled
        }
    }

    // MARK: - Unified Day Content

    private var dayContent: some View {
        VStack(spacing: 16) {
            // Completed hikes (for past and today)
            if !completedHikesForDay.isEmpty {
                ForEach(completedHikesForDay) { hike in
                    CompletedHikeCard(hike: hike)
                }
            }

            // Planned hikes section
            if !plannedHikesForDay.isEmpty {
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

                ForEach(plannedHikesForDay) { hike in
                    PlannedHikeCard(
                        hike: hike,
                        isEditing: isEditing,
                        scheduleOverrides: scheduleOverrides,
                        currentDate: currentDate,
                        onMarkComplete: isFuture ? nil : { selectedHike = hike },  // Enable for past + today
                        onRemoveDog: isPast ? nil : { dogId in removeDog(dogId, from: hike) },     // Disable for past
                        onRecalculateRoute: { recalculateRoute(hike) },
                        onApplyScheduleChanges: { applyScheduleChanges(hike) },
                        onResetToSchedule: { resetToSchedule() }
                    )
                }
            }

            // Empty state
            if hikesForDay.isEmpty {
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

    private var allScheduledDogIds: Set<UUID> {
        Set(plannedHikesForDay.flatMap { $0.participations.map { $0.dogId } })
    }

    private var availableDogs: [Dog] {
        activeDogs.filter { !allScheduledDogIds.contains($0.id) && $0.isActive }
    }

    private func isOverriddenAbsent(_ dog: Dog) -> Bool {
        scheduleOverrides.contains { override in
            Calendar.current.isDate(override.date, inSameDayAs: currentDate) &&
            override.dogId == dog.id &&
            override.type == .isAbsent
        }
    }

    // MARK: - Helper Methods

    private func loadHikesIfNeeded() {
        // Use DailyHikeManager to lazy-load hikes if they don't exist for this day
        let manager = DailyHikeManager(modelContext: modelContext)
        _ = manager.getDailyHikes(for: currentDate)
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
        let hasExistingOverride = scheduleOverrides.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: currentDate) && $0.dogId == dog.id
        })

        if let existing = hasExistingOverride {
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
        }

        // Add participation to first available planned hike
        if let targetHike = plannedHikesForDay.first(where: { $0.participations.count < 8 }) {
            let nextOrder = (targetHike.participations.map { $0.pickupOrder }.max() ?? 0) + 1
            let wasAddedViaOverride = hasExistingOverride == nil &&
                (currentDate.dayOfWeek.map { !dog.regularSchedule.contains($0) } ?? true)

            let participation = HikeParticipation(
                dogId: dog.id,
                dogName: dog.name,
                pickupOrder: nextOrder,
                pickupLatitude: dog.locationLatitude,
                pickupLongitude: dog.locationLongitude,
                pickupAddress: dog.locationAddress,
                rate: dog.paymentRate,
                wasAddedViaOverride: wasAddedViaOverride
            )
            participation.dailyHike = targetHike

            // Mark hike as stale since route needs recalculation
            // Don't downgrade from .scheduleChanged to .routeNeedsOptimization
            if targetHike.staleReason != .scheduleChanged {
                targetHike.staleReason = .routeNeedsOptimization
            }
            targetHike.lastModifiedAt = Date()
        }

        // Mark affected future hikes as stale
        let manager = DailyHikeManager(modelContext: modelContext)
        manager.markAffectedHikesStale(for: dog.id, after: currentDate)
    }

    private func removeDog(_ dogId: UUID, from hike: DailyHike) {
        guard let dog = activeDogs.first(where: { $0.id == dogId }) else { return }

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

        // Remove dog's participation from the hike
        if let participation = hike.participations.first(where: { $0.dogId == dogId }) {
            modelContext.delete(participation)
        }

        // Mark this hike as stale since route needs recalculation
        // Don't downgrade from .scheduleChanged to .routeNeedsOptimization
        if hike.staleReason != .scheduleChanged {
            hike.staleReason = .routeNeedsOptimization
        }
        hike.lastModifiedAt = Date()

        // Mark affected future hikes as stale
        let manager = DailyHikeManager(modelContext: modelContext)
        manager.markAffectedHikesStale(for: dog.id, after: currentDate)
    }

    /// Re-optimize the pickup route for current dogs only (dog list doesn't change)
    private func recalculateRoute(_ hike: DailyHike) {
        // Get current dogs from participations
        let dogIds = hike.participations.map { $0.dogId }
        let descriptor = FetchDescriptor<Dog>(
            predicate: #Predicate<Dog> { dog in dogIds.contains(dog.id) }
        )
        guard let dogs = try? modelContext.fetch(descriptor), !dogs.isEmpty else {
            hike.staleReason = nil
            hike.lastModifiedAt = Date()
            return
        }

        // Re-run route optimizer
        let optimizedRoute = RouteOptimizer.optimizeRoute(for: dogs)

        // Update participation pickup orders
        for (index, pickup) in optimizedRoute.pickups.enumerated() {
            if let participation = hike.participations.first(where: { $0.dogId == pickup.id }) {
                participation.pickupOrder = index + 1
                // Update pickup location in case it changed
                if let dog = dogs.first(where: { $0.id == pickup.id }) {
                    participation.pickupLatitude = dog.locationLatitude
                    participation.pickupLongitude = dog.locationLongitude
                    participation.pickupAddress = dog.locationAddress
                }
            }
        }

        // Update route coordinates
        let routeCoordinates = optimizedRoute.pickups.compactMap { pickup in
            dogs.first { $0.id == pickup.id }?.location
        }
        hike.route = routeCoordinates
        hike.totalDistance = optimizedRoute.totalDistance
        hike.staleReason = nil
        hike.lastModifiedAt = Date()
    }

    /// Sync dog list with current schedule + overrides, then optimize route
    private func applyScheduleChanges(_ hike: DailyHike) {
        let manager = DailyHikeManager(modelContext: modelContext)
        let date = hike.date
        let hikeNumber = hike.hikeNumber

        // Delete the current hike and regenerate with current schedule + overrides
        manager.resetDailyHike(hike)

        // Regenerate by loading hikes for this day
        // The getOrCreateDailyHike will create a fresh one based on current schedule + overrides
        _ = manager.getOrCreateDailyHike(for: date, hikeNumber: hikeNumber)
    }

    private func resetToSchedule() {
        // Delete all overrides for this day
        let overridesForDay = scheduleOverrides.filter {
            Calendar.current.isDate($0.date, inSameDayAs: currentDate)
        }
        for override in overridesForDay {
            modelContext.delete(override)
        }

        // Delete all existing hikes for this day
        for hike in hikesForDay {
            modelContext.delete(hike)
        }

        // Regenerate hikes from the regular schedule (no overrides)
        let manager = DailyHikeManager(modelContext: modelContext)
        _ = manager.getDailyHikes(for: currentDate)
    }
}

// MARK: - Completed Hike Card

private struct CompletedHikeCard: View {
    let hike: DailyHike

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
                .background(Color.green.opacity(0.1))

            if isExpanded {
                Divider()

                // Dog List with pickup order
                if !hike.orderedParticipations.isEmpty {
                    dogList
                        .padding(.vertical, 12)
                }

                // Removed Dogs Section
                if !hike.removedDogNames.isEmpty {
                    Divider()
                    removedDogsSection
                        .padding()
                }

                // Route Map
                if !hike.route.isEmpty {
                    Divider()
                    routeMap
                        .frame(height: 200)
                }

                // Trail Info
                if let trailName = hike.trailName {
                    Divider()
                    trailInfo(trailName)
                        .padding()
                }

                // Notes
                if let notes = hike.notes, !notes.isEmpty {
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
                        Text("Hike \(hike.hikeNumber)")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .imageScale(.small)
                    }

                    Text("\(hike.dogCount) dogs • \(String(format: "%.1f km", hike.totalDistance / 1000))")
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
            let participations = hike.orderedParticipations
            ForEach(Array(participations.enumerated()), id: \.element.id) { index, participation in
                CompletedHikeDogRow(participation: participation)

                if index < participations.count - 1 {
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
                ForEach(Array(hike.removedDogNames.enumerated()), id: \.offset) { _, dogName in
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
            ForEach(Array(hike.route.enumerated()), id: \.offset) { index, coordinate in
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
            if hike.route.count > 1 {
                MapPolyline(coordinates: hike.route)
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
    let participation: HikeParticipation

    // Look up the dog by ID to enable navigation
    private var dog: Dog? {
        let dogId = participation.dogId
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
                Text("\(participation.pickupOrder)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }

            // Dog info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(participation.dogName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // "Added" badge for override dogs
                    if participation.wasAddedViaOverride {
                        Badge(text: "Added", color: .green)
                    }
                }

                if let address = participation.pickupAddress {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount charged
            Text("$\(participation.rate as NSDecimalNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Planned Hike Card

private struct PlannedHikeCard: View {
    @Environment(\.modelContext) private var modelContext
    let hike: DailyHike
    let isEditing: Bool
    let scheduleOverrides: [ScheduleOverride]
    let currentDate: Date
    let onMarkComplete: (() -> Void)?
    let onRemoveDog: ((UUID) -> Void)?
    let onRecalculateRoute: (() -> Void)?        // Route-only optimization (for .routeNeedsOptimization)
    let onApplyScheduleChanges: (() -> Void)?   // Sync dog list with schedule (for .scheduleChanged)
    let onResetToSchedule: (() -> Void)?

    @State private var isExpanded = true
    @State private var showingRecalculateConfirmation = false
    @State private var showingApplyChangesConfirmation = false
    @State private var showingResetToScheduleConfirmation = false

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
            // Stale warning banner (if schedule has changed)
            if hike.isStale {
                staleWarningBanner
            }

            // Header with expand/collapse
            hikeHeader
                .padding()
                .background(hike.isStale ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))

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

                // Trail Info
                if let trailName = hike.trailName {
                    Divider()
                    trailSuggestion(trailName)
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

                // Edit mode action buttons
                if isEditing {
                    Divider()
                    VStack(spacing: 12) {
                        // Context-aware primary action button
                        if hike.staleReason == .scheduleChanged {
                            // Apply Changes - sync dog list with schedule
                            Button {
                                showingApplyChangesConfirmation = true
                            } label: {
                                Label("Apply Schedule Changes", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        } else {
                            // Recalculate Route - re-optimize route with current dogs
                            Button {
                                showingRecalculateConfirmation = true
                            } label: {
                                Label("Recalculate Route", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }

                        // Reset to Schedule - removes all overrides and regenerates from default
                        Button {
                            showingResetToScheduleConfirmation = true
                        } label: {
                            Label("Reset to Schedule", systemImage: "arrow.counterclockwise")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                    .padding()
                }
            }
        }
        .background(.background.secondary)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .confirmationDialog(
            "Recalculate Route",
            isPresented: $showingRecalculateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Recalculate") {
                onRecalculateRoute?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will optimize the pickup route for the current dogs. The dog list will not change.")
        }
        .confirmationDialog(
            "Reset to Schedule",
            isPresented: $showingResetToScheduleConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to Schedule", role: .destructive) {
                onResetToSchedule?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all overrides for this day and regenerate the hike from the regular weekly schedule.")
        }
        .confirmationDialog(
            "Apply Schedule Changes",
            isPresented: $showingApplyChangesConfirmation,
            titleVisibility: .visible
        ) {
            Button("Apply Changes") {
                onApplyScheduleChanges?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will update the dog list to match the current schedules and overrides, then optimize the route.")
        }
    }

    // MARK: - Stale Warning Banner

    private var staleWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .imageScale(.large)

            VStack(alignment: .leading, spacing: 2) {
                Text(staleBannerTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(staleBannerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(staleBannerButtonText) {
                if hike.staleReason == .scheduleChanged {
                    showingApplyChangesConfirmation = true
                } else {
                    showingRecalculateConfirmation = true
                }
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .controlSize(.small)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }

    private var staleBannerTitle: String {
        switch hike.staleReason {
        case .scheduleChanged:
            return "Schedule Changed"
        case .routeNeedsOptimization:
            return "Route Outdated"
        case nil:
            return ""
        }
    }

    private var staleBannerSubtitle: String {
        switch hike.staleReason {
        case .scheduleChanged:
            return "Dog schedules have been modified."
        case .routeNeedsOptimization:
            return "Dogs were added or removed."
        case nil:
            return ""
        }
    }

    private var staleBannerButtonText: String {
        switch hike.staleReason {
        case .scheduleChanged:
            return "Apply Changes"
        case .routeNeedsOptimization:
            return "Recalculate"
        case nil:
            return ""
        }
    }

    // MARK: - Header

    private var hikeHeader: some View {
        Button(action: { withAnimation { isExpanded.toggle() } }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hike \(hike.hikeNumber)")
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
            let participations = hike.orderedParticipations
            ForEach(Array(participations.enumerated()), id: \.element.id) { index, participation in
                PlannedHikeDogRow(
                    participation: participation,
                    pickupOrder: index + 1,
                    showAddedBadge: showAddedBadge(participation.dogId),
                    isEditing: isEditing,
                    onRemove: onRemoveDog
                )

                if index < participations.count - 1 {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
    }

    private func showAddedBadge(_ dogId: UUID) -> Bool {
        scheduleOverrides.contains { override in
            Calendar.current.isDate(override.date, inSameDayAs: currentDate) &&
            override.dogId == dogId &&
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

    private func trailSuggestion(_ trailName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Suggested Trail")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(trailName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
    }
}

// MARK: - Planned Hike Dog Row

private struct PlannedHikeDogRow: View {
    @Environment(\.modelContext) private var modelContext
    let participation: HikeParticipation
    let pickupOrder: Int
    let showAddedBadge: Bool
    let isEditing: Bool
    let onRemove: ((UUID) -> Void)?

    // Look up the dog by ID to enable navigation
    private var dog: Dog? {
        let dogId = participation.dogId
        let descriptor = FetchDescriptor<Dog>(
            predicate: #Predicate<Dog> { $0.id == dogId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    var body: some View {
        Group {
            if let dog = dog {
                NavigationLink {
                    DogDetailView(dog: dog)
                } label: {
                    rowContent
                }
            } else {
                rowContent
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        // Swipe actions (iOS only)
        #if os(iOS)
        .swipeActions(edge: .trailing) {
            if let onRemove = onRemove {
                Button(role: .destructive) {
                    onRemove(participation.dogId)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        #endif
    }

    private var rowContent: some View {
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
                    Text(participation.dogName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // "Added" badge (always visible if override)
                    if showAddedBadge {
                        Badge(text: "Added", color: .green)
                    }
                }

                if let address = participation.pickupAddress {
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
                    onRemove(participation.dogId)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
            }

            // Payment rate
            Text("$\(participation.rate as NSDecimalNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let schema = Schema([Client.self, Dog.self, Payment.self, ScheduleOverride.self, HikingLocation.self, DailyHike.self, HikeParticipation.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    SampleData.createSampleData(in: container.mainContext)

    return NavigationStack {
        DayDetailView(date: Date())
    }
    .modelContainer(container)
}
