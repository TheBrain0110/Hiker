//
//  DogAttendance.swift
//  Hiker
//
//  Created by Claude on 12/16/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class DogAttendance {
    @Attribute(.unique) var id: UUID
    var dogId: UUID                         // Reference to Dog
    var dogName: String                     // Denormalized for history
    var pickupOrder: Int                    // 1-8, order in route

    // Pickup location (denormalized)
    var pickupLatitude: Double?
    var pickupLongitude: Double?
    var pickupAddress: String?

    // Payment tracking
    var paymentId: UUID?                    // Link to Payment record
    var amountCharged: Decimal              // Snapshot of rate at time

    var completedHike: CompletedHike?

    init(
        id: UUID = UUID(),
        dogId: UUID,
        dogName: String,
        pickupOrder: Int,
        pickupLatitude: Double? = nil,
        pickupLongitude: Double? = nil,
        pickupAddress: String? = nil,
        paymentId: UUID? = nil,
        amountCharged: Decimal = 25.00
    ) {
        self.id = id
        self.dogId = dogId
        self.dogName = dogName
        self.pickupOrder = pickupOrder
        self.pickupLatitude = pickupLatitude
        self.pickupLongitude = pickupLongitude
        self.pickupAddress = pickupAddress
        self.paymentId = paymentId
        self.amountCharged = amountCharged
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
