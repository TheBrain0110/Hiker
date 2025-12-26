//
//  HikeCard.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import SwiftUI
import SwiftData
import MapKit

struct HikeCard: View {
    @Environment(\.modelContext) private var modelContext
    let hike: DailyHike

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            hikeHeader
                .padding()
                .background(Color.blue.opacity(0.1))

            if isExpanded {
                Divider()

                // Dog List
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
                    trailInfo(trailName)
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
                ParticipationListItem(participation: participation)

                if index < participations.count - 1 {
                    Divider()
                        .padding(.leading, 60)
                }
            }
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
        .disabled(true)  // Disable interaction for card view
    }

    private var mapPosition: MapCameraPosition {
        if !hike.route.isEmpty {
            let region = MKCoordinateRegion(
                center: hike.route[hike.route.count / 2],
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            return .region(region)
        } else {
            return .automatic
        }
    }

    // MARK: - Trail Info

    private func trailInfo(_ trailName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.hiking")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
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
}

// MARK: - Participation List Item

struct ParticipationListItem: View {
    let participation: HikeParticipation

    var body: some View {
        HStack(spacing: 12) {
            // Pickup order badge
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                Text("\(participation.pickupOrder)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }

            // Dog info (from denormalized data)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(participation.dogName)
                        .font(.body)
                        .fontWeight(.medium)

                    if participation.wasAddedViaOverride {
                        Badge(text: "Added", color: .green)
                    }
                }

                if let address = participation.pickupAddress {
                    Text(address)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    let schema = Schema([Client.self, Dog.self, Payment.self, ScheduleOverride.self, HikingLocation.self, DailyHike.self, HikeParticipation.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext

    // Create sample data
    SampleData.createSampleData(in: context)

    // Get a daily hike
    let manager = DailyHikeManager(modelContext: context)
    let hikes = manager.getDailyHikes(for: Date())

    return Group {
        if let hike = hikes.first {
            ScrollView {
                HikeCard(hike: hike)
                    .padding()
            }
        } else {
            Text("No hikes available")
        }
    }
    .modelContainer(container)
}
