//
//  CompletedHikeDogRow.swift
//  Hiker
//
//  Extracted from DayDetailView on 12/26/25.
//

import SwiftUI
import SwiftData

/// Individual dog row in a completed hike card
/// Shows pickup order, dog name, address, and amount charged
/// Provides navigation to DogDetailView if dog still exists
struct CompletedHikeDogRow: View {
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
