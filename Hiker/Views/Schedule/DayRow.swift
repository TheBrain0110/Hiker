//
//  DayRow.swift
//  Hiker
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData

struct DayRow: View {
    let date: Date
    let isToday: Bool
    let completedHikes: [CompletedHike]
    let scheduledDogs: [Dog]

    private var isPast: Bool {
        date < Calendar.current.startOfDay(for: Date())
    }

    private var isFuture: Bool {
        date > Calendar.current.startOfDay(for: Date())
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }

    private var dayOfWeekFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }

    private var fullDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    var body: some View {
        NavigationLink {
            DayDetailView(date: date)
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(spacing: 16) {
            // Date badge
            ZStack {
                Circle()
                    .fill(badgeColor)
                    .frame(width: isToday ? 60 : 50, height: isToday ? 60 : 50)

                VStack(spacing: 2) {
                    Text(dateFormatter.string(from: date))
                        .font(isToday ? .title2 : .body)
                        .fontWeight(isToday ? .bold : .semibold)

                    if isToday {
                        Text("Today")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
                .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dayOfWeekFormatter.string(from: date))
                        .font(.headline)

                    Spacer()

                    // Status indicator
                    if isPast && !completedHikes.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if isToday {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }

                Text(fullDateFormatter.string(from: date))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Summary
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(summaryColor)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Computed Properties

    private var badgeColor: Color {
        if isToday {
            return .blue
        } else if isPast {
            return completedHikes.isEmpty ? .gray.opacity(0.3) : .green.opacity(0.7)
        } else {
            return scheduledDogs.isEmpty ? .gray.opacity(0.3) : .orange.opacity(0.7)
        }
    }

    private var summaryText: String {
        if isPast {
            if completedHikes.isEmpty {
                return "No hikes completed"
            } else {
                let totalDogs = completedHikes.reduce(0) { $0 + $1.dogCount }
                return "\(completedHikes.count) hike\(completedHikes.count == 1 ? "" : "s") • \(totalDogs) dog\(totalDogs == 1 ? "" : "s")"
            }
        } else {
            if scheduledDogs.isEmpty {
                // Check if it's a weekend
                let calendar = Calendar.current
                let weekday = calendar.component(.weekday, from: date)
                if weekday == 1 || weekday == 7 { // Sunday or Saturday
                    return "Weekend - No hikes scheduled"
                }
                return "No dogs scheduled"
            } else {
                // List dog names
                let names = scheduledDogs.map { $0.name }.joined(separator: ", ")
                return names
            }
        }
    }

    private var summaryColor: Color {
        if isPast {
            return completedHikes.isEmpty ? .secondary : .primary
        } else {
            return scheduledDogs.isEmpty ? .secondary : .primary
        }
    }
}

#Preview {
    List {
        DayRow(
            date: Date(),
            isToday: true,
            completedHikes: [],
            scheduledDogs: []
        )
    }
}
