//
//  CompletedHikeCard.swift
//  Hiker
//
//  Extracted from DayDetailView on 12/26/25.
//

import SwiftUI
import SwiftData
import MapKit

/// Displays a completed hike with collapsible sections
/// Shows dog list, removed dogs, route map, trail info, and notes
struct CompletedHikeCard: View {
    let hike: DailyHike

    @State private var isExpanded = true

    private var mapPosition: MapCameraPosition {
        guard !hike.route.isEmpty else { return .automatic }

        // Calculate bounding box for all route points
        let latitudes = hike.route.map { $0.latitude }
        let longitudes = hike.route.map { $0.longitude }

        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // Add 20% padding to ensure all markers are visible
        let latDelta = max((maxLat - minLat) * 1.2, 0.01)
        let lonDelta = max((maxLon - minLon) * 1.2, 0.01)

        return .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with expand/collapse
            hikeHeader
                .padding()
                .background(Color.green.opacity(0.1))

            if isExpanded {
                Divider()

                // Dog List with pickup order
                if !hike.orderedParticipations.isEmpty {
                    dogList
                        .padding(.vertical, 12)
                }

                // Removed Dogs Section
                if !hike.removedDogNames.isEmpty {
                    Divider()
                    removedDogsSection
                        .padding()
                }

                // Route Map
                if !hike.route.isEmpty {
                    Divider()
                    routeMap
                        .aspectRatio(1, contentMode: .fit)  // Square: height = width
                }

                // Trail Info
                if let trailName = hike.trailName {
                    Divider()
                    trailInfo(trailName)
                        .padding()
                }

                // Notes
                if let notes = hike.notes, !notes.isEmpty {
                    Divider()
                    notesSection(notes)
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
                    HStack {
                        Text("Hike \(hike.hikeNumber)")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .imageScale(.small)
                    }

                    Text("\(hike.dogCount) dogs • \(String(format: "%.1f km", hike.totalDistance / 1000))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.green)
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
                CompletedHikeDogRow(participation: participation)

                if index < participations.count - 1 {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
    }

    // MARK: - Removed Dogs Section

    private var removedDogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .imageScale(.medium)
                Text("Removed from Schedule")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(hike.removedDogNames.enumerated()), id: \.offset) { _, dogName in
                    HStack(spacing: 12) {
                        Image(systemName: "pawprint.fill")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.6))
                            .frame(width: 20)

                        Text(dogName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Badge(text: "Removed", color: .red)

                        Spacer()
                    }
                }
            }
            .padding(.leading, 28)
        }
    }

    // MARK: - Map

    private var routeMap: some View {
        Map(initialPosition: mapPosition, interactionModes: [.pan, .zoom]) {
            // Determine if last coordinate is trail
            let hasTrailDestination = hike.route.count > hike.participations.count
            let pickupCount = hasTrailDestination ? hike.route.count - 1 : hike.route.count

            // Show pickup locations as numbered markers
            ForEach(0..<pickupCount, id: \.self) { index in
                let coordinate = hike.route[index]
                Annotation("\(index + 1)", coordinate: coordinate) {
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 30, height: 30)
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
            }

            // Show trail destination marker (if exists)
            if hasTrailDestination, let trailCoordinate = hike.route.last {
                Annotation("Trail", coordinate: trailCoordinate) {
                    VStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        Text(hike.trailName ?? "Trail")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                    .padding(6)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                }
            }

            // Draw route line (includes trail destination)
            if hike.route.count > 1 {
                MapPolyline(coordinates: hike.route)
                    .stroke(.green, lineWidth: 3)
            }
        }
        .mapStyle(.standard)
    }

    // MARK: - Trail Info

    private func trailInfo(_ trailName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
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

    // MARK: - Notes

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notes")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(notes)
                .font(.subheadline)
        }
    }
}
