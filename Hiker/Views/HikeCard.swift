//
//  HikeCard.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import SwiftUI
import MapKit

struct HikeCard: View {
    let hike: DailyHike.Hike

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

                // Suggested Trail
                if let trail = hike.suggestedTrail {
                    Divider()
                    trailSuggestion(trail)
                        .padding()
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    // MARK: - Header

    private var hikeHeader: some View {
        Button(action: { withAnimation { isExpanded.toggle() } }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hike \(hike.number)")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(hike.dogCount) dogs • \(hike.totalDistance.kilometersFormatted)")
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
            ForEach(Array(hike.dogs.enumerated()), id: \.element.id) { index, dog in
                DogListItem(dog: dog, pickupOrder: index + 1)

                if index < hike.dogs.count - 1 {
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

            // Show suggested trail
            if let trail = hike.suggestedTrail {
                Annotation(trail.name, coordinate: trail.coordinate) {
                    Image(systemName: "figure.hiking")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .padding(8)
                        .background(Circle().fill(.white))
                        .shadow(radius: 2)
                }
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

    // MARK: - Trail Suggestion

    private func trailSuggestion(_ trail: HikingLocation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.hiking")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Suggested Trail")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(trail.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(trail.region)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Dog List Item

struct DogListItem: View {
    let dog: Dog
    let pickupOrder: Int

    var body: some View {
        HStack(spacing: 12) {
            // Pickup order badge
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                Text("\(pickupOrder)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }

            // Dog info
            VStack(alignment: .leading, spacing: 2) {
                Text(dog.name)
                    .font(.body)
                    .fontWeight(.medium)

                if let owner = dog.client?.ownerName {
                    Text(owner)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let address = dog.locationAddress {
                    Text(address)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Notes indicator
            if !dog.notes.isEmpty {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Client.self, configurations: config)
    let context = container.mainContext

    // Create sample data
    SampleData.createSampleData(in: context)

    // Get a daily schedule
    let manager = DailyHikeManager(modelContext: context)
    let schedule = manager.dailySchedule(for: Date())

    return Group {
        if let hike = schedule.hike1 {
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
