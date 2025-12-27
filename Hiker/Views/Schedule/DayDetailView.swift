//
//  DayDetailView.swift
//  Hiker
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData
import MapKit
import UniformTypeIdentifiers

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
    @State private var draggedDogId: UUID?  // Shared across all hike cards for cross-hike dragging

    // Business logic manager
    private var scheduleManager: DayScheduleManager {
        DayScheduleManager(modelContext: modelContext)
    }

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
                    if isEditing {
                        // Optimize all routes before exiting edit mode
                        scheduleManager.optimizeAllRoutesForDay(currentDate, plannedHikes: plannedHikesForDay)
                    }
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
        .onDisappear {
            if isEditing {
                // Optimize routes before leaving
                scheduleManager.optimizeAllRoutesForDay(currentDate, plannedHikes: plannedHikesForDay)
                isEditing = false
            }
        }
        .onChange(of: currentDate) {
            // Exit edit mode when changing days
            isEditing = false
            loadHikesIfNeeded()
        }
        // Note: Removed onChange handlers for activeDogs/scheduleOverrides
        // Stale flags and action buttons handle schedule changes
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
                        onRegroupAll: { regroupAllHikes() },
                        onSplitHike: { dogId in createSecondHike(with: dogId, from: hike) },
                        onMoveDog: { dogId, targetHike in moveDog(dogId, to: targetHike) },
                        onMoveDogToPosition: { dogId, targetHike, position in moveDog(dogId, to: targetHike, at: position) },
                        onReorderDogs: { orderedIds in reorderDogs(in: hike, orderedIds: orderedIds) },
                        draggedDogId: $draggedDogId,
                        totalHikeCount: plannedHikesForDay.count
                    )
                }

                // Day-level action buttons (only in edit mode)
                if isEditing && hasPendingHikes {
                    dayLevelActions
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

    // MARK: - Day-Level Actions

    private var dayLevelActions: some View {
        VStack(spacing: 12) {
            Text("Day Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            // Regroup All Hikes - always visible in edit mode
            Button {
                regroupAllHikes()
            } label: {
                Label("Regroup All Hikes", systemImage: "square.grid.2x2")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .padding(.horizontal)

            // Reset Day to Schedule - always visible in edit mode
            Button {
                resetToSchedule()
            } label: {
                Label("Reset Day to Schedule", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .padding(.horizontal)
        }
        .padding(.top, 16)
    }

    private var allScheduledDogIds: Set<UUID> {
        Set(plannedHikesForDay.flatMap { $0.participations.map { $0.dogId } })
    }

    private var availableDogs: [Dog] {
        scheduleManager.getAvailableDogs(allActiveDogs: activeDogs, plannedHikes: plannedHikesForDay)
    }

    private func isOverriddenAbsent(_ dog: Dog) -> Bool {
        scheduleManager.hasAbsentOverride(
            dogId: dog.id,
            on: currentDate,
            overrides: Array(scheduleOverrides)
        )
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
        scheduleManager.addDog(
            dog,
            to: plannedHikesForDay,
            on: currentDate,
            existingOverrides: Array(scheduleOverrides)
        )
    }

    private func removeDog(_ dogId: UUID, from hike: DailyHike) {
        scheduleManager.removeDog(
            dogId,
            from: hike,
            on: currentDate,
            activeDogs: activeDogs,
            existingOverrides: Array(scheduleOverrides)
        )
    }

    private func recalculateRoute(_ hike: DailyHike) {
        scheduleManager.recalculateRoute(for: hike)
    }

    private func resetToSchedule() {
        scheduleManager.resetToSchedule(
            for: currentDate,
            existingHikes: hikesForDay,
            existingOverrides: Array(scheduleOverrides)
        )
    }

    private func regroupAllHikes() {
        scheduleManager.regroupAllHikes(for: currentDate)
    }

    private func moveDog(_ dogId: UUID, to targetHike: DailyHike) {
        // Find the source hike
        guard let sourceHike = plannedHikesForDay.first(where: { hike in
            hike.participations.contains { $0.dogId == dogId }
        }) else { return }

        // Don't move if already in target hike
        guard sourceHike.id != targetHike.id else { return }

        scheduleManager.moveDog(dogId, from: sourceHike, to: targetHike)
    }

    private func moveDog(_ dogId: UUID, to targetHike: DailyHike, at targetIndex: Int) {
        // Find the source hike
        guard let sourceHike = plannedHikesForDay.first(where: { hike in
            hike.participations.contains { $0.dogId == dogId }
        }) else { return }

        // Don't move if already in target hike
        guard sourceHike.id != targetHike.id else { return }

        scheduleManager.moveDog(dogId, from: sourceHike, to: targetHike, at: targetIndex)
    }

    private func reorderDogs(in hike: DailyHike, orderedIds: [UUID]) {
        scheduleManager.reorderDogs(in: hike, orderedDogIds: orderedIds)
    }

    private func splitHike(_ hike: DailyHike) {
        scheduleManager.splitHike(hike)
    }

    private func createSecondHike(with dogId: UUID, from hike: DailyHike) {
        scheduleManager.createSecondHike(with: dogId, from: hike)
    }
}

// MARK: - Completed Hike Card
// Extracted to DayDetailComponents/CompletedHikeCard.swift

// MARK: - Completed Hike Dog Row
// Extracted to DayDetailComponents/CompletedHikeDogRow.swift

// MARK: - Planned Hike Card
// Extracted to DayDetailComponents/PlannedHikeCard.swift

// MARK: - Planned Hike Dog Row
// Extracted to DayDetailComponents/PlannedHikeDogRow.swift

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
