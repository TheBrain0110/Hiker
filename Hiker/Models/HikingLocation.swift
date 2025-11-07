//
//  HikingLocation.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class HikingLocation {
    @Attribute(.unique) var id: UUID
    var name: String

    // Store coordinates separately
    var latitude: Double
    var longitude: Double

    var region: String  // "Bedford", "Sackville", "Beaver Bank"
    var notes: String?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        region: String,
        notes: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.region = region
        self.notes = notes
        self.isActive = isActive
    }

    // Computed property for convenience
    var coordinate: CLLocationCoordinate2D {
        get {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
}
