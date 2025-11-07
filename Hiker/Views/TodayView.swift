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

    @State private var dailySchedule: DailyHike?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading today's schedule...")
                } else if let schedule = dailySchedule, !schedule.isEmpty {
                    scheduleContent(schedule)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadSchedule()
            }
            .refreshable {
                await loadSchedule()
            }
        }
    }

    // MARK: - Schedule Content

    @ViewBuilder
    private func scheduleContent(_ schedule: DailyHike) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
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
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Hikes Today",
            systemImage: "calendar.badge.exclamationmark",
            description: Text("No dogs are scheduled for today.\nCheck the weekly schedule to add dogs.")
        )
    }

    // MARK: - Data Loading

    private func loadSchedule() async {
        isLoading = true
        await Task { @MainActor in
            let manager = DailyHikeManager(modelContext: modelContext)
            dailySchedule = manager.dailySchedule(for: Date())
            isLoading = false
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
