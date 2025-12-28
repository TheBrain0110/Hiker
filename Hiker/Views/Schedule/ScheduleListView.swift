//
//  ScheduleListView.swift
//  Hiker
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData

struct ScheduleListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DailyHike.date, order: .reverse)
    private var allDailyHikes: [DailyHike]

    private var completedHikes: [DailyHike] {
        allDailyHikes.filter { $0.isCompleted }
    }

    @Query(filter: #Predicate<Dog> { $0.isActive }, sort: \Dog.name)
    private var activeDogs: [Dog]

    @Query private var scheduleOverrides: [ScheduleOverride]

    // Infinite scroll state
    @State private var visibleDates: [Date] = []
    @State private var earliestLoadedDate: Date?
    @State private var latestLoadedDate: Date?

    private let initialDaysBack = 7
    private let initialDaysForward = 14
    private let paginationSize = 30  // Load 30 days at a time when scrolling

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    // NOTE: iOS SwiftData Pagination Bug Workaround
    // Using per-row .onAppear for pagination causes 100% CPU hang on iOS (not macOS).
    // When multiple rows fire .onAppear simultaneously during initial render, it triggers
    // a feedback loop between SwiftUI's state observation and SwiftData's @Query re-fetching.
    // The workaround uses sentinel views at list edges that only fire when actually scrolled to.
    // See CLAUDE.md "Known Issues" section for detailed documentation.
    var body: some View {
        ScrollViewReader { proxy in
            List {
                // Top sentinel for loading past dates (iOS-safe pagination)
                Color.clear
                    .frame(height: 1)
                    .listRowSeparator(.hidden)
                    .onAppear { loadMorePastDates() }

                ForEach(visibleDates, id: \.self) { date in
                    DayRow(
                        date: date,
                        isToday: Calendar.current.isDate(date, inSameDayAs: today),
                        completedHikes: completedHikesFor(date: date),
                        scheduledDogs: scheduledDogsFor(date: date),
                        hasPersistedHike: hasPersistedHikeFor(date: date)
                    )
                    .id(date)
                    .listRowBackground(
                        Calendar.current.isDate(date, inSameDayAs: today) ?
                        Color.blue.opacity(0.1) : nil
                    )
                }

                // Bottom sentinel for loading future dates (iOS-safe pagination)
                Color.clear
                    .frame(height: 1)
                    .listRowSeparator(.hidden)
                    .onAppear { loadMoreFutureDates() }
            }
            .listStyle(.plain)
            .onAppear {
                if visibleDates.isEmpty {
                    initializeDates()
                    loadHikesIfNeeded()
                    // Scroll to today on appear
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(today, anchor: .center)
                        }
                    }
                }
            }
            // Note: Removed onChange handlers - stale flags handle schedule changes
        }
    }

    // MARK: - Helper Methods

    private func initializeDates() {
        let calendar = Calendar.current
        var dates: [Date] = []

        // Past days (newest first)
        for i in (1...initialDaysBack).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                dates.append(date)
            }
        }

        // Today
        dates.append(today)

        // Future days
        for i in 1...initialDaysForward {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                dates.append(date)
            }
        }

        visibleDates = dates
        earliestLoadedDate = dates.first
        latestLoadedDate = dates.last
    }

    private func loadMorePastDates() {
        guard let earliest = earliestLoadedDate else { return }
        let calendar = Calendar.current
        var newDates: [Date] = []

        // Load `paginationSize` more days before the earliest date
        for i in (1...paginationSize).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: earliest) {
                newDates.append(date)
            }
        }

        guard !newDates.isEmpty else { return }

        // Prepend to visible dates
        visibleDates.insert(contentsOf: newDates, at: 0)
        earliestLoadedDate = newDates.first
    }

    private func loadMoreFutureDates() {
        guard let latest = latestLoadedDate else { return }
        let calendar = Calendar.current
        var newDates: [Date] = []

        // Load `paginationSize` more days after the latest date
        for i in 1...paginationSize {
            if let date = calendar.date(byAdding: .day, value: i, to: latest) {
                newDates.append(date)
            }
        }

        guard !newDates.isEmpty else { return }

        // Append to visible dates
        visibleDates.append(contentsOf: newDates)
        latestLoadedDate = newDates.last
    }

    private func loadHikesIfNeeded() {
        let manager = DailyHikeManager(modelContext: modelContext)
        // Only eagerly load today's hike (so user sees their schedule immediately)
        _ = manager.getDailyHikes(for: today)
        // All other days are loaded on-demand when user navigates to DayDetailView
    }

    private func completedHikesFor(date: Date) -> [DailyHike] {
        let calendar = Calendar.current
        return completedHikes.filter { hike in
            calendar.isDate(hike.date, inSameDayAs: date)
        }
    }

    private func hikesFor(date: Date) -> [DailyHike] {
        let calendar = Calendar.current
        return allDailyHikes.filter { hike in
            calendar.isDate(hike.date, inSameDayAs: date)
        }
    }

    private func scheduledDogsFor(date: Date) -> [Dog] {
        let hikes = hikesFor(date: date).filter { $0.isPlanned }

        // If a planned hike exists, use its data (includes any overrides)
        if !hikes.isEmpty {
            // Get all dog IDs from participations
            let dogIds = Set(hikes.flatMap { $0.participations.map { $0.dogId } })

            // Return dogs that match those IDs
            return activeDogs.filter { dogIds.contains($0.id) }
        }

        // No existing hike - compute ephemeral preview from regular schedules
        let manager = DailyHikeManager(modelContext: modelContext)
        return manager.getExpectedDogs(for: date)
    }

    private func hasPersistedHikeFor(date: Date) -> Bool {
        let hikes = hikesFor(date: date).filter { $0.isPlanned }
        return !hikes.isEmpty
    }
}

#Preview {
    let schema = Schema([Client.self, Dog.self, Payment.self, ScheduleOverride.self, HikingLocation.self, DailyHike.self, HikeParticipation.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    SampleData.createSampleData(in: container.mainContext)

    return NavigationStack {
        ScheduleListView()
    }
    .modelContainer(container)
}
