//
//  TodayView.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import SwiftUI
import SwiftData
import MapKit

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext

    // Watch for override changes to trigger re-renders
    @Query private var overrides: [ScheduleOverride]
    
    @State private var dailySchedule: DailyHike?
    @State private var isLoading = true
    @State private var showingDate: Date = Date()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading schedule...")
                } else if let schedule = dailySchedule, !schedule.isEmpty {
                    scheduleContent(schedule)
                } else {
                    emptyState
                }
            }
            .navigationTitle(navigationTitle)
            .task {
                await loadSchedule()
            }
            .refreshable {
                await loadSchedule()
            }
            .onChange(of: overrides) {
                Task { await loadSchedule() }
            }
        }
    }
    
    private var navigationTitle: String {
        if Calendar.current.isDateInToday(showingDate) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(showingDate) {
            return "Tomorrow"
        } else {
            return showingDate.formatted(.dateTime.weekday(.wide))
        }
    }

    // MARK: - Schedule Content

    @ViewBuilder
    private func scheduleContent(_ schedule: DailyHike) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header (Only show date if it's not "Today" in nav title, or always show to be safe?)
                // Nav title handles "Today"/"Tomorrow", so let's keep specific date here
                scheduleHeader(schedule)

                // Hike 1
                if let hike1 = schedule.hike1, !hike1.isEmpty {
                    HikeCard(hike: hike1)
                }

                // Hike 2
                if let hike2 = schedule.hike2, !hike2.isEmpty {
                    HikeCard(hike: hike2)
                }
            }
            .padding()
        }
    }

    private func scheduleHeader(_ schedule: DailyHike) -> some View {
        VStack(spacing: 8) {
            Text(schedule.date.mediumDateString)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                StatBadge(
                    icon: "pawprint.fill",
                    value: "\(schedule.totalDogs)",
                    label: "dogs"
                )

                StatBadge(
                    icon: "figure.hiking",
                    value: "\(schedule.hikes.filter { !$0.isEmpty }.count)",
                    label: "hikes"
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Hikes Scheduled",
            systemImage: "calendar.badge.exclamationmark",
            description: Text("No dogs are scheduled for the next 3 days.\nCheck the weekly schedule to add dogs.")
        )
    }

    // MARK: - Data Loading

    private func loadSchedule() async {
        isLoading = true
        await Task { @MainActor in
            let manager = DailyHikeManager(modelContext: modelContext)
            let today = Date()
            
            // 1. Try Today
            let scheduleToday = manager.dailySchedule(for: today)
            if !scheduleToday.isEmpty {
                self.dailySchedule = scheduleToday
                self.showingDate = today
                self.isLoading = false
                return
            }
            
            // 2. Try Tomorrow
            let tomorrow = today.addingDays(1)
            let scheduleTomorrow = manager.dailySchedule(for: tomorrow)
            if !scheduleTomorrow.isEmpty {
                self.dailySchedule = scheduleTomorrow
                self.showingDate = tomorrow
                self.isLoading = false
                return
            }
            
            // 3. Try Next Weekday (up to 3 days ahead) if weekend
            // If today is Saturday, tomorrow is Sunday (checked), next is Mon
            if today.dayOfWeek == nil || tomorrow.dayOfWeek == nil {
                 let nextDay = tomorrow.addingDays(1) // +2 days from today
                 let scheduleNext = manager.dailySchedule(for: nextDay)
                 if !scheduleNext.isEmpty {
                     self.dailySchedule = scheduleNext
                     self.showingDate = nextDay
                     self.isLoading = false
                     return
                 }
                 
                 // One more check (+3 days)
                 let nextNextDay = nextDay.addingDays(1)
                 let scheduleNextNext = manager.dailySchedule(for: nextNextDay)
                 if !scheduleNextNext.isEmpty {
                     self.dailySchedule = scheduleNextNext
                     self.showingDate = nextNextDay
                     self.isLoading = false
                     return
                 }
            }
            
            // Fallback: Show empty today
            self.dailySchedule = scheduleToday
            self.showingDate = today
            self.isLoading = false
        }.value
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.blue)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: Client.self, inMemory: true)
}
