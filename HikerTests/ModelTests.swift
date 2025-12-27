//
//  ModelTests.swift
//  HikerTests
//
//  Created by Claude on 12/16/25.
//

import Foundation
import Testing
import CoreLocation
@testable import Hiker

/// Tests for SwiftData model computed properties and methods.
///
/// ## SwiftData Unit Testing Limitation
///
/// These tests deliberately avoid using `ModelContext` or `ModelContainer` because
/// SwiftData model type metadata is not accessible across module boundaries in unit tests.
///
/// **The Problem:**
/// When unit tests (in HikerTests target) try to create a `ModelContainer` with models
/// defined in the main app target (Hiker), the SwiftData runtime cannot resolve the
/// model types. This manifests as:
/// - `EXC_BREAKPOINT (SIGTRAP)` crash at `context.insert()`
/// - Objects showing as `Hiker.Client._SwiftDataNoType` in debugger
/// - Crash occurs even though `@testable import Hiker` provides compile-time access
///
/// **Root Cause:**
/// The `@Model` macro generates runtime type metadata that lives in the main app binary.
/// When the test target creates its own `ModelContainer`, SwiftData looks for this
/// metadata but can't find it because it's in a different module/binary.
///
/// **Workaround:**
/// Test model logic (computed properties, methods, initializers) by creating instances
/// WITHOUT inserting them into a context. SwiftData models work as regular Swift classes
/// for non-persistence operations.
///
/// **What CAN be tested without context:**
/// - Computed properties (coordinate conversions, enum wrappers, array reconstructions)
/// - Instance methods that don't require persistence
/// - Default values and initializer behavior
/// - ID uniqueness
///
/// **What REQUIRES context (currently not testable in unit tests):**
/// - Relationship navigation (client.dogs, dog.payments)
/// - Queries and fetches
/// - Cascade delete behavior
/// - Integration with managers that query data (DailyHikeManager)
///
/// For integration testing of SwiftData-dependent code, consider UI tests which run
/// within the app's process and have access to the proper type metadata.
struct ModelTests {

    // MARK: - Dog.location Tests

    @Test("Dog location computed property returns coordinate when set")
    func testDogLocationReturnsCoordinate() {
        let dog = Dog(
            name: "Buddy",
            client: nil,
            locationLatitude: 44.7324,
            locationLongitude: -63.6567
        )

        let location = dog.location
        #expect(location != nil)
        #expect(location?.latitude == 44.7324)
        #expect(location?.longitude == -63.6567)
    }

    @Test("Dog location returns nil when latitude is nil")
    func testDogLocationReturnsNilWhenLatitudeNil() {
        let dog = Dog(
            name: "Buddy",
            client: nil,
            locationLatitude: nil,
            locationLongitude: -63.6567
        )

        #expect(dog.location == nil)
    }

    @Test("Dog location returns nil when longitude is nil")
    func testDogLocationReturnsNilWhenLongitudeNil() {
        let dog = Dog(
            name: "Buddy",
            client: nil,
            locationLatitude: 44.7324,
            locationLongitude: nil
        )

        #expect(dog.location == nil)
    }

    @Test("Dog location setter updates latitude and longitude")
    func testDogLocationSetterUpdatesCoordinates() {
        let dog = Dog(name: "Buddy", client: nil)

        dog.location = CLLocationCoordinate2D(latitude: 45.0, longitude: -64.0)

        #expect(dog.locationLatitude == 45.0)
        #expect(dog.locationLongitude == -64.0)
    }

    @Test("Dog location setter handles nil")
    func testDogLocationSetterHandlesNil() {
        let dog = Dog(
            name: "Buddy",
            client: nil,
            locationLatitude: 44.7324,
            locationLongitude: -63.6567
        )

        dog.location = nil

        #expect(dog.locationLatitude == nil)
        #expect(dog.locationLongitude == nil)
    }

    // MARK: - Dog.regularSchedule Tests

    @Test("Dog regularSchedule getter converts from raw values")
    func testDogRegularScheduleGetter() {
        let dog = Dog(
            name: "Buddy",
            client: nil,
            regularSchedule: [.monday, .wednesday, .friday]
        )

        let schedule = dog.regularSchedule

        #expect(schedule.count == 3)
        #expect(schedule.contains(.monday))
        #expect(schedule.contains(.wednesday))
        #expect(schedule.contains(.friday))
    }

    @Test("Dog regularSchedule setter stores as raw values")
    func testDogRegularScheduleSetter() {
        let dog = Dog(name: "Buddy", client: nil)

        dog.regularSchedule = [.tuesday, .thursday]

        #expect(dog.regularScheduleDays.count == 2)
        #expect(dog.regularScheduleDays.contains(DayOfWeek.tuesday.rawValue))
        #expect(dog.regularScheduleDays.contains(DayOfWeek.thursday.rawValue))
    }

    @Test("Dog empty schedule returns empty array")
    func testDogEmptySchedule() {
        let dog = Dog(
            name: "Buddy",
            client: nil,
            regularSchedule: []
        )

        #expect(dog.regularSchedule.isEmpty)
        #expect(dog.regularScheduleDays.isEmpty)
    }

    // MARK: - Dog.isScheduledOn Tests

    @Test("isScheduledOn returns true for scheduled day")
    func testIsScheduledOnReturnsTrue() {
        let dog = Dog(
            name: "Buddy",
            client: nil,
            regularSchedule: [.monday, .wednesday, .friday]
        )

        #expect(dog.isScheduledOn(.monday) == true)
        #expect(dog.isScheduledOn(.wednesday) == true)
        #expect(dog.isScheduledOn(.friday) == true)
    }

    @Test("isScheduledOn returns false for unscheduled day")
    func testIsScheduledOnReturnsFalse() {
        let dog = Dog(
            name: "Buddy",
            client: nil,
            regularSchedule: [.monday, .wednesday, .friday]
        )

        #expect(dog.isScheduledOn(.tuesday) == false)
        #expect(dog.isScheduledOn(.thursday) == false)
    }

    // MARK: - Dog Default Values Tests

    @Test("Dog initializes with correct defaults")
    func testDogDefaultValues() {
        let dog = Dog(name: "Buddy", client: nil)

        #expect(dog.paymentRate == 25.00)
        #expect(dog.notes == "")
        #expect(dog.isActive == true)
        #expect(dog.color == nil)
        #expect(dog.regularSchedule.isEmpty)
    }

    @Test("Dog id is unique")
    func testDogIdIsUnique() {
        let dog1 = Dog(name: "Buddy", client: nil)
        let dog2 = Dog(name: "Max", client: nil)

        #expect(dog1.id != dog2.id)
    }

    // MARK: - Client.coordinate Tests

    @Test("Client coordinate returns value when both lat/lon set")
    func testClientCoordinateReturnsValue() {
        let client = Client(
            ownerName: "Test Owner",
            address: "123 Test St",
            latitude: 44.6488,
            longitude: -63.5752
        )

        let coord = client.coordinate
        #expect(coord != nil)
        #expect(coord?.latitude == 44.6488)
        #expect(coord?.longitude == -63.5752)
    }

    @Test("Client coordinate returns nil when latitude is nil")
    func testClientCoordinateNilLatitude() {
        let client = Client(
            ownerName: "Test Owner",
            address: "123 Test St",
            latitude: nil,
            longitude: -63.5752
        )

        #expect(client.coordinate == nil)
    }

    @Test("Client coordinate setter updates lat/lon")
    func testClientCoordinateSetter() {
        let client = Client(ownerName: "Test Owner", address: "123 Test St")

        client.coordinate = CLLocationCoordinate2D(latitude: 44.65, longitude: -63.58)

        #expect(client.latitude == 44.65)
        #expect(client.longitude == -63.58)
    }

    @Test("Client defaults are correct")
    func testClientDefaults() {
        let client = Client(ownerName: "Test Owner", address: "123 Test St")

        #expect(client.isActive == true)
        #expect(client.phone == nil)
        #expect(client.email == nil)
        #expect(client.latitude == nil)
        #expect(client.longitude == nil)
    }

    // MARK: - ScheduleOverride.type Tests

    @Test("ScheduleOverride type getter returns correct enum")
    func testScheduleOverrideTypeGetter() {
        let dogId = UUID()
        let override = ScheduleOverride(dogId: dogId, date: Date(), type: .isPresent)

        #expect(override.type == .isPresent)
    }

    @Test("ScheduleOverride type setter updates raw value")
    func testScheduleOverrideTypeSetter() {
        let dogId = UUID()
        let override = ScheduleOverride(dogId: dogId, date: Date(), type: .isPresent)

        override.type = .isAbsent

        #expect(override.type == .isAbsent)
    }

    @Test("ScheduleOverride preserves dogId and date")
    func testScheduleOverridePreservesData() {
        let dogId = UUID()
        let date = Date()
        let override = ScheduleOverride(dogId: dogId, date: date, type: .isAbsent, note: "Vacation")

        #expect(override.dogId == dogId)
        #expect(override.note == "Vacation")
    }

    // MARK: - DailyHike.route Tests

    @Test("DailyHike route reconstructs coordinates")
    func testDailyHikeRouteGetter() {
        let hike = DailyHike(date: Date(), hikeNumber: 1)
        hike.routeLatitudes = [44.65, 44.66, 44.67]
        hike.routeLongitudes = [-63.58, -63.59, -63.60]

        let route = hike.route
        #expect(route.count == 3)
        #expect(route[0].latitude == 44.65)
        #expect(route[0].longitude == -63.58)
        #expect(route[2].latitude == 44.67)
        #expect(route[2].longitude == -63.60)
    }

    @Test("DailyHike route setter stores coordinates")
    func testDailyHikeRouteSetter() {
        let hike = DailyHike(date: Date(), hikeNumber: 1)

        hike.route = [
            CLLocationCoordinate2D(latitude: 44.70, longitude: -63.50),
            CLLocationCoordinate2D(latitude: 44.71, longitude: -63.51)
        ]

        #expect(hike.routeLatitudes == [44.70, 44.71])
        #expect(hike.routeLongitudes == [-63.50, -63.51])
    }

    @Test("DailyHike empty route returns empty array")
    func testDailyHikeEmptyRoute() {
        let hike = DailyHike(date: Date(), hikeNumber: 1)

        #expect(hike.route.isEmpty)
        #expect(hike.routeLatitudes.isEmpty)
        #expect(hike.routeLongitudes.isEmpty)
    }

    @Test("DailyHike date is normalized to startOfDay")
    func testDailyHikeDateNormalized() {
        // Create a date with time component
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 16
        components.hour = 14
        components.minute = 30
        let dateWithTime = Calendar.current.date(from: components)!

        let hike = DailyHike(date: dateWithTime, hikeNumber: 1)

        let calendar = Calendar.current
        let storedComponents = calendar.dateComponents([.hour, .minute], from: hike.date)
        #expect(storedComponents.hour == 0)
        #expect(storedComponents.minute == 0)
    }

    // MARK: - HikeParticipation.pickupLocation Tests

    @Test("HikeParticipation pickupLocation returns coordinate")
    func testHikeParticipationPickupLocation() {
        let participation = HikeParticipation(
            dogId: UUID(),
            dogName: "Buddy",
            pickupOrder: 1,
            pickupLatitude: 44.65,
            pickupLongitude: -63.58
        )

        let location = participation.pickupLocation
        #expect(location != nil)
        #expect(location?.latitude == 44.65)
        #expect(location?.longitude == -63.58)
    }

    @Test("HikeParticipation pickupLocation returns nil when missing")
    func testHikeParticipationPickupLocationNil() {
        let participation = HikeParticipation(
            dogId: UUID(),
            dogName: "Buddy",
            pickupOrder: 1
        )

        #expect(participation.pickupLocation == nil)
    }

    @Test("HikeParticipation pickupLocation setter works")
    func testHikeParticipationPickupLocationSetter() {
        let participation = HikeParticipation(
            dogId: UUID(),
            dogName: "Buddy",
            pickupOrder: 1
        )

        participation.pickupLocation = CLLocationCoordinate2D(latitude: 44.70, longitude: -63.55)

        #expect(participation.pickupLatitude == 44.70)
        #expect(participation.pickupLongitude == -63.55)
    }

    @Test("HikeParticipation defaults are correct")
    func testHikeParticipationDefaults() {
        let participation = HikeParticipation(
            dogId: UUID(),
            dogName: "Buddy",
            pickupOrder: 1
        )

        #expect(participation.rate == 25.00)
        #expect(participation.wasAddedViaOverride == false)
        #expect(participation.paymentId == nil)
        #expect(participation.isConfirmed == false)
    }

    // MARK: - DailyHike.staleReason Tests (DISABLED - functionality removed in Phase 3)

    /*
    @Test("DailyHike staleReason defaults to nil")
    func testDailyHikeStaleReasonDefaultsNil() {
        let hike = DailyHike(date: Date(), hikeNumber: 1)

        #expect(hike.staleReason == nil)
        #expect(hike.isStale == false)
    }

    @Test("DailyHike staleReason can be set to routeNeedsOptimization")
    func testDailyHikeStaleReasonRouteOptimization() {
        let hike = DailyHike(date: Date(), hikeNumber: 1)

        hike.staleReason = .routeNeedsOptimization

        #expect(hike.staleReason == .routeNeedsOptimization)
        #expect(hike.isStale == true)
    }

    @Test("DailyHike staleReason can be set to scheduleChanged")
    func testDailyHikeStaleReasonScheduleChanged() {
        let hike = DailyHike(date: Date(), hikeNumber: 1)

        hike.staleReason = .scheduleChanged

        #expect(hike.staleReason == .scheduleChanged)
        #expect(hike.isStale == true)
    }

    @Test("DailyHike staleReason can be initialized with value")
    func testDailyHikeStaleReasonInitialized() {
        let hike = DailyHike(date: Date(), hikeNumber: 1, staleReason: .scheduleChanged)

        #expect(hike.staleReason == .scheduleChanged)
        #expect(hike.isStale == true)
    }

    @Test("DailyHike staleReason can be cleared")
    func testDailyHikeStaleReasonCleared() {
        let hike = DailyHike(date: Date(), hikeNumber: 1, staleReason: .routeNeedsOptimization)

        hike.staleReason = nil

        #expect(hike.staleReason == nil)
        #expect(hike.isStale == false)
    }

    @Test("DailyHike lastModifiedAt updates when stale reason changes")
    func testDailyHikeLastModifiedAtUpdates() {
        let originalDate = Date(timeIntervalSince1970: 1000)
        let hike = DailyHike(
            date: Date(),
            hikeNumber: 1,
            lastModifiedAt: originalDate
        )

        #expect(hike.lastModifiedAt == originalDate)

        // Simulate what markAffectedHikesStale does
        hike.staleReason = .scheduleChanged
        hike.lastModifiedAt = Date()

        #expect(hike.isStale == true)
        #expect(hike.staleReason == .scheduleChanged)
        #expect(hike.lastModifiedAt > originalDate)
    }

    @Test("Completed hike can have stale reason but UI should ignore it")
    func testCompletedHikeStaleReason() {
        // A completed hike can have staleReason set, but it shouldn't affect display
        // since completed hikes show historical data
        let hike = DailyHike(
            date: Date(),
            hikeNumber: 1,
            completedAt: Date(),
            staleReason: .scheduleChanged
        )

        #expect(hike.isCompleted == true)
        #expect(hike.staleReason == .scheduleChanged)
        #expect(hike.isStale == true)
        // The UI should ignore staleReason for completed hikes
    }

    @Test("Planned hike with routeNeedsOptimization shows recalculate action")
    func testPlannedHikeRouteOptimization() {
        let hike = DailyHike(date: Date(), hikeNumber: 1, staleReason: .routeNeedsOptimization)

        #expect(hike.isPlanned == true)
        #expect(hike.staleReason == .routeNeedsOptimization)
        // UI should show "Recalculate Route" button
    }

    @Test("Planned hike with scheduleChanged shows apply changes action")
    func testPlannedHikeScheduleChanged() {
        let hike = DailyHike(date: Date(), hikeNumber: 1, staleReason: .scheduleChanged)

        #expect(hike.isPlanned == true)
        #expect(hike.staleReason == .scheduleChanged)
        // UI should show "Apply Changes" button
    }

    @Test("StaleReason raw values are stable")
    func testStaleReasonRawValues() {
        #expect(StaleReason.routeNeedsOptimization.rawValue == "routeNeedsOptimization")
        #expect(StaleReason.scheduleChanged.rawValue == "scheduleChanged")
    }
    */
}
