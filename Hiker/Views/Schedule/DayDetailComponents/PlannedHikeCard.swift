//
//  PlannedHikeCard.swift
//  Hiker
//
//  Extracted from DayDetailView on 12/26/25.
//

import SwiftUI
import SwiftData
import MapKit
import UniformTypeIdentifiers

/// Displays a planned/uncompleted hike with edit capabilities and stale warnings
/// Supports edit mode with dog add/remove, route optimization, and schedule reset
struct PlannedHikeCard: View {
    @Environment(\.modelContext) private var modelContext
    let hike: DailyHike
    let isEditing: Bool
    let scheduleOverrides: [ScheduleOverride]
    let currentDate: Date
    let onMarkComplete: (() -> Void)?
    let onRemoveDog: ((UUID) -> Void)?
    let onRegroupAll: (() -> Void)?             // Regroup all hikes geographically
    let onSplitHike: ((UUID) -> Void)?          // Create second hike with specified dog
    let onMoveDog: ((UUID, DailyHike) -> Void)?  // Move dog to this hike from another
    let onMoveDogToPosition: ((UUID, DailyHike, Int) -> Void)?  // Move dog to this hike at specific position
    let onReorderDogs: (([UUID]) -> Void)?       // Reorder dogs within this hike
    @Binding var draggedDogId: UUID?             // Shared drag state across all hike cards
    let totalHikeCount: Int                       // Total number of hikes (for drop zone visibility)

    @State private var isExpanded = true
    @State private var dropTargetDogId: UUID?  // Dog being hovered over during drag
    @State private var isCrossHikeDropTarget = false  // Hovering over this hike for cross-hike drop

    private var mapPosition: MapCameraPosition {
        if let firstCoordinate = hike.route.first {
            return .region(MKCoordinateRegion(
                center: firstCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
        return .automatic
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Over-capacity warning banner (if exceeds soft cap)
            if hike.dogCount > hike.suggestedMaxDogs {
                overCapacityWarningBanner
            }

            // Header with expand/collapse
            hikeHeader
                .padding()
                .background(Color.blue.opacity(0.1))

            if isExpanded {
                Divider()

                // Dog List with pickup order
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
                    trailSuggestion(trailName)
                        .padding()
                }

                // Mark Complete Button (only show if closure provided)
                if let onMarkComplete = onMarkComplete {
                    Divider()
                    Button(action: onMarkComplete) {
                        Label("Mark Complete", systemImage: "checkmark.circle")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .padding()
                }
            }
        }
        .background(.background.secondary)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    // MARK: - Warning Banners

    private var overCapacityWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .imageScale(.large)

            VStack(alignment: .leading, spacing: 2) {
                Text("Large Hike")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(hike.dogCount) dogs exceeds recommended capacity of \(hike.suggestedMaxDogs)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Show the same "Regroup All Hikes" button from day-level actions
            if let onRegroupAll = onRegroupAll {
                Button("Regroup All") {
                    onRegroupAll()
                }
                .buttonStyle(.bordered)
                .tint(.yellow)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.15))
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
                VStack(spacing: 0) {
                    PlannedHikeDogRow(
                        participation: participation,
                        pickupOrder: index + 1,
                        showAddedBadge: showAddedBadge(participation.dogId),
                        isEditing: isEditing,
                        onRemove: onRemoveDog,
                        onStartDrag: {
                            // Mark this dog as being dragged (called when drag handle is used)
                            draggedDogId = participation.dogId
                        }
                    )
                    .background(
                        // Highlight background when hovering
                        dropTargetDogId == participation.dogId
                            ? Color.blue.opacity(0.1)
                            : Color.clear
                    )
                    .padding(.top, dropTargetDogId == participation.dogId ? 50 : 0)  // Animated spacing
                    .animation(.spring(response: 0.3), value: dropTargetDogId)
                }
                .onDrop(of: [.text], delegate: DogReorderDropDelegate(
                    targetDogId: participation.dogId,
                    draggedDogId: $draggedDogId,
                    dropTargetDogId: $dropTargetDogId,
                    hike: hike,
                    onReorder: onReorderDogs,
                    onMoveDog: onMoveDog,
                    onMoveDogToPosition: onMoveDogToPosition
                ))

                if index < participations.count - 1 {
                    Divider()
                        .padding(.leading, 60)
                }
            }

            // Drop zone for creating 2nd hike (only shows in edit mode when there's 1 hike and dragging)
            if isEditing && totalHikeCount == 1 && draggedDogId != nil {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.leading, 60)

                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Drop here to create a second hike")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(isCrossHikeDropTarget ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1))
                }
                .onDrop(of: [.text], isTargeted: $isCrossHikeDropTarget) { providers in
                    handleCrossHikeDrop(providers)
                }
            }
        }
    }

    private func showAddedBadge(_ dogId: UUID) -> Bool {
        scheduleOverrides.contains { override in
            Calendar.current.isDate(override.date, inSameDayAs: currentDate) &&
            override.dogId == dogId &&
            override.type == .isPresent
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
        .allowsHitTesting(false)
    }

    // MARK: - Trail Suggestion

    private func trailSuggestion(_ trailName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Suggested Trail")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(trailName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
    }

    // MARK: - Drag and Drop Handlers

    /// Handle drop to create second hike with the dragged dog (when there's only 1 hike)
    private func handleCrossHikeDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadObject(ofClass: NSString.self) { object, error in
            if let dogIdString = object as? String,
               let dogId = UUID(uuidString: dogIdString) {
                // Create second hike with this specific dog
                DispatchQueue.main.async {
                    onSplitHike?(dogId)
                    // Clear drag state
                    draggedDogId = nil
                }
            }
        }

        return true
    }
}

/// Drop delegate for reordering dogs within a hike and cross-hike moves
private struct DogReorderDropDelegate: DropDelegate {
    let targetDogId: UUID
    @Binding var draggedDogId: UUID?
    @Binding var dropTargetDogId: UUID?
    let hike: DailyHike
    let onReorder: (([UUID]) -> Void)?
    let onMoveDog: ((UUID, DailyHike) -> Void)?
    let onMoveDogToPosition: ((UUID, DailyHike, Int) -> Void)?

    func performDrop(info: DropInfo) -> Bool {
        defer { dropTargetDogId = nil }  // Clear hover state after drop

        guard let draggedDogId = draggedDogId else { return false }

        let draggedIsInThisHike = hike.participations.contains { $0.dogId == draggedDogId }

        if draggedIsInThisHike {
            // Same-hike reordering
            var orderedDogIds = hike.orderedParticipations.map { $0.dogId }

            guard let sourceIndex = orderedDogIds.firstIndex(of: draggedDogId),
                  let destIndex = orderedDogIds.firstIndex(of: targetDogId) else {
                return false
            }

            // Reorder the array
            let movedDogId = orderedDogIds.remove(at: sourceIndex)
            // After removing source, indices shift down if source was before destination
            let adjustedDestIndex = sourceIndex < destIndex ? destIndex - 1 : destIndex
            orderedDogIds.insert(movedDogId, at: adjustedDestIndex)

            onReorder?(orderedDogIds)
        } else {
            // Cross-hike move: Move dog to this hike at the target position
            guard let targetIndex = hike.orderedParticipations.firstIndex(where: { $0.dogId == targetDogId }) else {
                return false
            }

            // Use positioned move to insert at the target position directly
            onMoveDogToPosition?(draggedDogId, hike, targetIndex)
        }

        self.draggedDogId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedDogId = draggedDogId else { return }

        // Show feedback for both same-hike reordering AND cross-hike moves
        // (but not if dropping on self)
        if draggedDogId != targetDogId {
            dropTargetDogId = targetDogId
        }
    }

    func dropExited(info: DropInfo) {
        dropTargetDogId = nil
    }
}
