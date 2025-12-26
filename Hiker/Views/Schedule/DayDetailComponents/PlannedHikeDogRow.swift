//
//  PlannedHikeDogRow.swift
//  Hiker
//
//  Extracted from DayDetailView on 12/26/25.
//

import SwiftUI
import SwiftData

/// Individual dog row in a planned hike card
/// Shows pickup order, dog name, address, and payment rate
/// Supports edit mode with remove button and iOS swipe-to-delete
struct PlannedHikeDogRow: View {
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
