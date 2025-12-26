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

    private let daysBack = 30
    private let daysForward = 60

    // Generate array of all dates to display
    private var allDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var dates: [Date] = []

        // Past days (newest first)
        for i in (1...daysBack).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                dates.append(date)
            }
        }

        // Today
        dates.append(today)

        // Future days
        for i in 1...daysForward {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                dates.append(date)
            }
        }

        return dates
    }

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(allDates, id: \.self) { date in
                    DayRow(
                        date: date,
                        isToday: Calendar.current.isDate(date, inSameDayAs: today),
                        completedHikes: completedHikesFor(date: date),
                        scheduledDogs: scheduledDogsFor(date: date)
                    )
                    .id(date)
                    .listRowBackground(
                        Calendar.current.isDate(date, inSameDayAs: today) ?
                        Color.blue.opacity(0.1) : nil
                    )
                }
            }
            .listStyle(.plain)
            .onAppear {
                loadHikesIfNeeded()
                // Scroll to today on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo(today, anchor: .center)
                    }
                }
            }
            // Note: Removed onChange handlers - stale flags handle schedule changes
        }
    }

    // MARK: - Helper Methods

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
        // Only show dogs if a hike already exists (was viewed before)
        let hikes = hikesFor(date: date).filter { $0.isPlanned }

        // If no existing planned hike, return empty (don't compute schedule)
        guard !hikes.isEmpty else { return [] }

        // Get all dog IDs from participations
        let dogIds = Set(hikes.flatMap { $0.participations.map { $0.dogId } })

        // Return dogs that match those IDs
        return activeDogs.filter { dogIds.contains($0.id) }
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
