//
//  Dog.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class Dog {
    @Attribute(.unique) var id: UUID
    var name: String

    var client: Client?

    // Store pickup location coordinates separately
    var locationLatitude: Double?
    var locationLongitude: Double?
    var locationAddress: String?

    // Store regular schedule as array of day raw values
    var regularScheduleDays: [Int] = []

    var paymentRate: Decimal
    var notes: String
    var color: String?
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \Payment.dog)
    var payments: [Payment] = []

    init(
        id: UUID = UUID(),
        name: String,
        client: Client? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        locationAddress: String? = nil,
        regularSchedule: [DayOfWeek] = [],
        paymentRate: Decimal = 25.00,
        notes: String = "",
        color: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.client = client
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.locationAddress = locationAddress
        self.regularScheduleDays = regularSchedule.map { $0.rawValue }
        self.paymentRate = paymentRate
        self.notes = notes
        self.color = color
        self.isActive = isActive
    }

    // Computed property for location
    var location: CLLocationCoordinate2D? {
        get {
            guard let latitude = locationLatitude,
                  let longitude = locationLongitude else { return nil }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            locationLatitude = newValue?.latitude
            locationLongitude = newValue?.longitude
        }
    }

    // Computed property for regular schedule
    var regularSchedule: [DayOfWeek] {
        get {
            regularScheduleDays.compactMap { DayOfWeek(rawValue: $0) }
        }
        set {
            regularScheduleDays = newValue.map { $0.rawValue }
        }
    }

    // Helper: Is this dog scheduled on a specific day of the week?
    func isScheduledOn(_ day: DayOfWeek) -> Bool {
        regularSchedule.contains(day)
    }
}
