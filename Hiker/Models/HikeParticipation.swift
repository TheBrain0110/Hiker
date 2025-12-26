//
//  HikeParticipation.swift
//  Hiker
//
//  Created by Claude on 12/25/25.
//

import Foundation
import SwiftData
import CoreLocation

/// Tracks a dog's participation in a hike (planned or completed)
@Model
final class HikeParticipation {
    @Attribute(.unique) var id: UUID
    var dogId: UUID                         // Reference to Dog
    var dogName: String                     // Denormalized for history
    var pickupOrder: Int                    // 1-8, position in route

    // Pickup location (denormalized)
    var pickupLatitude: Double?
    var pickupLongitude: Double?
    var pickupAddress: String?

    // Payment tracking
    var paymentId: UUID?                    // Link to Payment record
    var rate: Decimal                       // Snapshot of dog.paymentRate

    // Status tracking
    var isConfirmed: Bool = false           // True when user confirms attendance
    var wasAddedViaOverride: Bool = false   // True if dog had .isPresent override (shows "Added" badge)

    // Relationship to parent hike
    var dailyHike: DailyHike?

    init(
        id: UUID = UUID(),
        dogId: UUID,
        dogName: String,
        pickupOrder: Int,
        pickupLatitude: Double? = nil,
        pickupLongitude: Double? = nil,
        pickupAddress: String? = nil,
        paymentId: UUID? = nil,
        rate: Decimal = 25.00,
        isConfirmed: Bool = false,
        wasAddedViaOverride: Bool = false
    ) {
        self.id = id
        self.dogId = dogId
        self.dogName = dogName
        self.pickupOrder = pickupOrder
        self.pickupLatitude = pickupLatitude
        self.pickupLongitude = pickupLongitude
        self.pickupAddress = pickupAddress
        self.paymentId = paymentId
        self.rate = rate
        self.isConfirmed = isConfirmed
        self.wasAddedViaOverride = wasAddedViaOverride
    }

    var pickupLocation: CLLocationCoordinate2D? {
        get {
            guard let lat = pickupLatitude, let lon = pickupLongitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        set {
            pickupLatitude = newValue?.latitude
            pickupLongitude = newValue?.longitude
        }
    }
}
