//
//  PlannedHikeCard.swift
//  Hiker
//
//  Extracted from DayDetailView on 12/26/25.
//

import SwiftUI
import SwiftData
import MapKit

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
    let onRecalculateRoute: (() -> Void)?        // Route-only optimization (for .routeNeedsOptimization)
    let onApplyScheduleChanges: (() -> Void)?   // Sync dog list with schedule (for .scheduleChanged)
    let onResetToSchedule: (() -> Void)?

    // Confirmation action enum for simplified state management
    private enum ConfirmationAction: Identifiable {
        case recalculateRoute
        case applyChanges
        case resetToSchedule

        var id: Self { self }

        var title: String {
            switch self {
            case .recalculateRoute: return "Recalculate Route"
            case .applyChanges: return "Apply Schedule Changes"
            case .resetToSchedule: return "Reset to Schedule"
            }
        }

        var message: String {
            switch self {
            case .recalculateRoute:
                return "This will optimize the pickup route for the current dogs. The dog list will not change."
            case .applyChanges:
                return "This will update the dog list to match the current schedules and overrides, then optimize the route."
            case .resetToSchedule:
                return "This will remove all overrides for this day and regenerate the hike from the regular weekly schedule."
            }
        }

        var isDestructive: Bool {
            self == .resetToSchedule
        }
    }

    @State private var isExpanded = true
    @State private var confirmationAction: ConfirmationAction?

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
            // Stale warning banner (if schedule has changed)
            if hike.isStale {
                staleWarningBanner
            }

            // Header with expand/collapse
            hikeHeader
                .padding()
                .background(hike.isStale ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))

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

                // Edit mode action buttons
                if isEditing {
                    Divider()
                    VStack(spacing: 12) {
                        // Context-aware primary action button
                        if hike.staleReason == .scheduleChanged {
                            // Apply Changes - sync dog list with schedule
                            Button {
                                confirmationAction = .applyChanges
                            } label: {
                                Label("Apply Schedule Changes", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        } else {
                            // Recalculate Route - re-optimize route with current dogs
                            Button {
                                confirmationAction = .recalculateRoute
                            } label: {
                                Label("Recalculate Route", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }

                        // Reset to Schedule - removes all overrides and regenerates from default
                        Button {
                            confirmationAction = .resetToSchedule
                        } label: {
                            Label("Reset to Schedule", systemImage: "arrow.counterclockwise")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                    .padding()
                }
            }
        }
        .background(.background.secondary)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .confirmationDialog(
            confirmationAction?.title ?? "",
            isPresented: .constant(confirmationAction != nil),
            titleVisibility: .visible,
            presenting: confirmationAction
        ) { action in
            Button(action.title, role: action.isDestructive ? .destructive : nil) {
                switch action {
                case .recalculateRoute:
                    onRecalculateRoute?()
                case .applyChanges:
                    onApplyScheduleChanges?()
                case .resetToSchedule:
                    onResetToSchedule?()
                }
                confirmationAction = nil
            }
            Button("Cancel", role: .cancel) {
                confirmationAction = nil
            }
        } message: { action in
            Text(action.message)
        }
    }

    // MARK: - Stale Warning Banner

    private var staleWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .imageScale(.large)

            VStack(alignment: .leading, spacing: 2) {
                Text(staleBannerTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(staleBannerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(staleBannerButtonText) {
                if hike.staleReason == .scheduleChanged {
                    confirmationAction = .applyChanges
                } else {
                    confirmationAction = .recalculateRoute
                }
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .controlSize(.small)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }

    private var staleBannerTitle: String {
        switch hike.staleReason {
        case .scheduleChanged:
            return "Schedule Changed"
        case .routeNeedsOptimization:
            return "Route Outdated"
        case nil:
            return ""
        }
    }

    private var staleBannerSubtitle: String {
        switch hike.staleReason {
        case .scheduleChanged:
            return "Dog schedules have been modified."
        case .routeNeedsOptimization:
            return "Dogs were added or removed."
        case nil:
            return ""
        }
    }

    private var staleBannerButtonText: String {
        switch hike.staleReason {
        case .scheduleChanged:
            return "Apply Changes"
        case .routeNeedsOptimization:
            return "Recalculate"
        case nil:
            return ""
        }
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
                PlannedHikeDogRow(
                    participation: participation,
                    pickupOrder: index + 1,
                    showAddedBadge: showAddedBadge(participation.dogId),
                    isEditing: isEditing,
                    onRemove: onRemoveDog
                )

                if index < participations.count - 1 {
                    Divider()
                        .padding(.leading, 60)
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
}
