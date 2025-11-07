//
//  Client.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class Client {
    @Attribute(.unique) var id: UUID
    var ownerName: String
    var phone: String?
    var email: String?
    var address: String

    // Store coordinates as separate properties (CLLocationCoordinate2D isn't Codable)
    var latitude: Double?
    var longitude: Double?

    @Relationship(deleteRule: .cascade, inverse: \Dog.client)
    var dogs: [Dog] = []

    var createdDate: Date
    var isActive: Bool

    init(
        id: UUID = UUID(),
        ownerName: String,
        phone: String? = nil,
        email: String? = nil,
        address: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        createdDate: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.ownerName = ownerName
        self.phone = phone
        self.email = email
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.createdDate = createdDate
        self.isActive = isActive
    }

    // Computed property for convenience
    var coordinate: CLLocationCoordinate2D? {
        get {
            guard let latitude, let longitude else { return nil }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue?.latitude
            longitude = newValue?.longitude
        }
    }
}
