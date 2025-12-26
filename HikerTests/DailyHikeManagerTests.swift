//
//  DailyHikeManagerTests.swift
//  HikerTests
//
//  Created by Claude on 12/16/25.
//

import Foundation
import Testing
import SwiftData
import CoreLocation
@testable import Hiker

/// Integration tests for DailyHikeManager schedule computation.
///
/// ## Currently Disabled - SwiftData Cross-Module Issue
///
/// These tests require a working `ModelContext` to:
/// 1. Create and persist Dog/Client entities
/// 2. Create ScheduleOverride records
/// 3. Query dogs scheduled for specific dates
///
/// However, SwiftData's `@Model` macro generates type metadata that cannot be
/// resolved when `ModelContainer` is created in a separate test target. The symptom
/// is `EXC_BREAKPOINT` crash at `context.insert()` with objects showing as
/// `_SwiftDataNoType` in the debugger.
///
/// ## What These Tests Cover (When Enabled)
///
/// - Weekend handling (returns empty schedule for Sat/Sun)
/// - Hike capacity (max 8 dogs per hike, splits into 2 hikes at 9+)
/// - Dog filtering (only active dogs scheduled for that day)
/// - Schedule override integration (.isPresent adds, .isAbsent removes)
/// - Trail suggestion (finds closest trail to last pickup)
/// - Route optimization integration
///
/// ## How to Run These Tests
///
/// **Option 1: UI Tests**
/// Move this logic to UI tests which run in the app's process and have
/// access to the proper SwiftData type metadata.
///
/// **Option 2: Shared Framework**
/// Move models to a shared framework that both app and test targets link against.
/// This ensures type metadata is available to both.
///
/// **Option 3: Wait for Apple Fix**
/// Apple may improve SwiftData testing support in future Xcode versions.
///
/// ## Test Helper (Preserved for Future Use)
///
/// The `createTestContext()` helper below creates an in-memory container.
/// It compiles but crashes at runtime due to the type metadata issue.
///
/// ## API Update (December 2025)
///
/// DailyHikeManager has been updated to use persistent DailyHike models:
/// - `getDailyHikes(for:)` returns [DailyHike] - lazy-loads or returns existing
/// - `getOrCreateDailyHike(for:hikeNumber:)` returns single hike
/// - `resetDailyHike(_:)` deletes a hike (caller regenerates)
/// - `markAffectedHikesStale(for:after:)` sets `staleReason = .scheduleChanged`
///
/// ## Stale Reason API (December 2025)
///
/// The `isStale: Bool` flag was replaced with context-aware `staleReason: StaleReason?`:
/// - `.routeNeedsOptimization` - Dogs manually added/removed, re-optimize route only
/// - `.scheduleChanged` - Dog schedule changed, sync dog list with schedule
/// - `nil` - Hike is up-to-date
/// - `isStale: Bool` remains as computed property for backward compatibility
@Suite(.disabled("SwiftData context not available in unit tests - see file header for details"))
@MainActor
struct DailyHikeManagerTests {

    // MARK: - Test Helpers

    /// Creates an in-memory ModelContext for testing.
    ///
    /// > Warning: This crashes with `EXC_BREAKPOINT` when `context.insert()` is called
    /// > due to SwiftData type metadata not being accessible across module boundaries.
    /// > Preserved here for when/if Apple fixes this issue.
    private func createTestContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Client.self, Dog.self, Payment.self, ScheduleOverride.self,
            HikingLocation.self, DailyHike.self, HikeParticipation.self,
            configurations: config
        )
        return container.mainContext
    }

    private func createTestDog(
        name: String,
        regularSchedule: [DayOfWeek],
        latitude: Double = 44.7324,
        longitude: Double = -63.6567,
        in context: ModelContext
    ) -> Dog {
        let client = Client(ownerName: "Owner of \(name)", address: "123 Test St")
        context.insert(client)

        let dog = Dog(
            name: name,
            client: client,
            locationLatitude: latitude,
            locationLongitude: longitude,
            locationAddress: "123 Test St",
            regularSchedule: regularSchedule,
            paymentRate: 25.00
        )
        context.insert(dog)

        return dog
    }

    private func createTestTrail(
        name: String,
        latitude: Double,
        longitude: Double,
        in context: ModelContext
    ) -> HikingLocation {
        let trail = HikingLocation(
            name: name,
            latitude: latitude,
            longitude: longitude,
            region: "Test Region"
        )
        context.insert(trail)
        return trail
    }

    private func getMonday() -> Date {
        // Find the next Monday from a known date
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 15 // December 15, 2025 is a Monday
        return calendar.date(from: components)!
    }

    private func getSaturday() -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 20 // December 20, 2025 is a Saturday
        return calendar.date(from: components)!
    }

    // MARK: - Weekend Handling Tests

    @Test("Weekend returns empty schedule")
    func testWeekendReturnsEmptySchedule() throws {
        let context = try createTestContext()
        let _ = createTestDog(
            name: "Buddy",
            regularSchedule: [.monday, .wednesday, .friday],
            in: context
        )

        let manager = DailyHikeManager(modelContext: context)
        let saturday = getSaturday()
        let hikes = manager.getDailyHikes(for: saturday)

        #expect(hikes.isEmpty)
    }

    @Test("Weekday with scheduled dogs returns hikes")
    func testWeekdayWithScheduledDogsReturnsHikes() throws {
        let context = try createTestContext()
        let _ = createTestDog(
            name: "Buddy",
            regularSchedule: [.monday, .wednesday, .friday],
            in: context
        )

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(!hikes.isEmpty)
        #expect(hikes[0].participations.count == 1)
        #expect(hikes[0].participations[0].dogName == "Buddy")
    }

    // MARK: - Hike Capacity Tests

    @Test("Up to 8 dogs fit in single hike")
    func testUpTo8DogsInSingleHike() throws {
        let context = try createTestContext()

        // Create 8 dogs all scheduled for Monday
        for i in 1...8 {
            let _ = createTestDog(
                name: "Dog\(i)",
                regularSchedule: [.monday],
                latitude: 44.7 + Double(i) * 0.01,
                longitude: -63.6,
                in: context
            )
        }

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(hikes.count == 1)
        #expect(hikes[0].participations.count == 8)
    }

    @Test("9 dogs split into 2 hikes")
    func test9DogsSplitInto2Hikes() throws {
        let context = try createTestContext()

        // Create 9 dogs all scheduled for Monday
        for i in 1...9 {
            let _ = createTestDog(
                name: "Dog\(i)",
                regularSchedule: [.monday],
                latitude: 44.7 + Double(i) * 0.01,
                longitude: -63.6,
                in: context
            )
        }

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(hikes.count == 2)
        // 9 dogs split: 4 and 5 (or similar balanced split)
        let totalDogs = hikes.reduce(0) { $0 + $1.participations.count }
        #expect(totalDogs == 9)
    }

    @Test("16 dogs split evenly into 2 hikes of 8")
    func test16DogsSplitEvenly() throws {
        let context = try createTestContext()

        // Create 16 dogs all scheduled for Monday
        for i in 1...16 {
            let _ = createTestDog(
                name: "Dog\(i)",
                regularSchedule: [.monday],
                latitude: 44.7 + Double(i) * 0.01,
                longitude: -63.6,
                in: context
            )
        }

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(hikes.count == 2)
        #expect(hikes[0].participations.count == 8)
        #expect(hikes[1].participations.count == 8)
    }

    @Test("More than 16 dogs capped at 16")
    func testMoreThan16DogsCapped() throws {
        let context = try createTestContext()

        // Create 20 dogs all scheduled for Monday
        for i in 1...20 {
            let _ = createTestDog(
                name: "Dog\(i)",
                regularSchedule: [.monday],
                latitude: 44.7 + Double(i) * 0.01,
                longitude: -63.6,
                in: context
            )
        }

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(hikes.count == 2)
        let totalDogs = hikes.reduce(0) { $0 + $1.participations.count }
        #expect(totalDogs == 16) // Capped at 16
    }

    // MARK: - Dog Scheduling Tests

    @Test("Only dogs scheduled for that day are included")
    func testOnlyScheduledDogsIncluded() throws {
        let context = try createTestContext()

        // Buddy: Mon, Wed, Fri
        let _ = createTestDog(
            name: "Buddy",
            regularSchedule: [.monday, .wednesday, .friday],
            in: context
        )

        // Max: Tue, Thu
        let _ = createTestDog(
            name: "Max",
            regularSchedule: [.tuesday, .thursday],
            in: context
        )

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(hikes.count == 1)
        #expect(hikes[0].participations.count == 1)
        #expect(hikes[0].participations[0].dogName == "Buddy")
    }

    @Test("Inactive dogs are excluded")
    func testInactiveDogsExcluded() throws {
        let context = try createTestContext()

        let _ = createTestDog(
            name: "ActiveDog",
            regularSchedule: [.monday],
            in: context
        )

        let inactiveDog = createTestDog(
            name: "InactiveDog",
            regularSchedule: [.monday],
            in: context
        )
        inactiveDog.isActive = false

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(hikes.count == 1)
        #expect(hikes[0].participations.count == 1)
        #expect(hikes[0].participations[0].dogName == "ActiveDog")
    }

    @Test("Dogs without schedule not included")
    func testDogsWithoutScheduleNotIncluded() throws {
        let context = try createTestContext()

        let _ = createTestDog(
            name: "ScheduledDog",
            regularSchedule: [.monday],
            in: context
        )

        let _ = createTestDog(
            name: "UnscheduledDog",
            regularSchedule: [], // No regular schedule
            in: context
        )

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(hikes.count == 1)
        #expect(hikes[0].participations.count == 1)
        #expect(hikes[0].participations[0].dogName == "ScheduledDog")
    }

    // MARK: - Empty Schedule Tests

    @Test("No dogs returns empty schedule")
    func testNoDogsReturnsEmptySchedule() throws {
        let context = try createTestContext()
        // No dogs created

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(hikes.isEmpty)
    }

    @Test("No dogs scheduled for specific day returns empty")
    func testNoDogsScheduledForDayReturnsEmpty() throws {
        let context = try createTestContext()

        // Dog only scheduled for Tuesday
        let _ = createTestDog(
            name: "TuesdayDog",
            regularSchedule: [.tuesday],
            in: context
        )

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(hikes.isEmpty)
    }

    // MARK: - Trail Suggestion Tests

    @Test("Trail suggestion finds closest trail to last pickup")
    func testTrailSuggestionFindsClosest() throws {
        let context = try createTestContext()

        // Dog in Bedford
        let _ = createTestDog(
            name: "Buddy",
            regularSchedule: [.monday],
            latitude: 44.7324,
            longitude: -63.6567,
            in: context
        )

        // Two trails - one close, one far
        let _ = createTestTrail(
            name: "Close Trail",
            latitude: 44.7400,
            longitude: -63.6500,
            in: context
        )
        let _ = createTestTrail(
            name: "Far Trail",
            latitude: 45.0000,
            longitude: -64.0000,
            in: context
        )

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(hikes.count == 1)
        #expect(hikes[0].trailName == "Close Trail")
    }

    @Test("No trails returns nil suggestion")
    func testNoTrailsReturnsNilSuggestion() throws {
        let context = try createTestContext()

        let _ = createTestDog(
            name: "Buddy",
            regularSchedule: [.monday],
            in: context
        )
        // No trails created

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(hikes.count == 1)
        #expect(hikes[0].trailName == nil)
    }

    // MARK: - Route Optimization Tests

    @Test("Hike includes optimized route coordinates")
    func testHikeIncludesRouteCoordinates() throws {
        let context = try createTestContext()

        let _ = createTestDog(
            name: "Dog1",
            regularSchedule: [.monday],
            latitude: 44.7324,
            longitude: -63.6567,
            in: context
        )
        let _ = createTestDog(
            name: "Dog2",
            regularSchedule: [.monday],
            latitude: 44.7500,
            longitude: -63.6700,
            in: context
        )

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(hikes.count == 1)
        #expect(hikes[0].route.count == 2)
        #expect(hikes[0].totalDistance > 0)
    }

    @Test("Dogs are alphabetically sorted before grouping")
    func testDogsAreSortedAlphabetically() throws {
        let context = try createTestContext()

        // Create dogs in reverse alphabetical order
        let _ = createTestDog(name: "Zoe", regularSchedule: [.monday], in: context)
        let _ = createTestDog(name: "Buddy", regularSchedule: [.monday], in: context)
        let _ = createTestDog(name: "Max", regularSchedule: [.monday], in: context)

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()
        let hikes = manager.getDailyHikes(for: monday)

        #expect(hikes.count == 1)
        // The dogs are fetched sorted by name, then route-optimized
        // We can't guarantee final order due to route optimization,
        // but all 3 dogs should be present
        let dogNames = Set(hikes[0].participations.map { $0.dogName })
        #expect(dogNames == Set(["Buddy", "Max", "Zoe"]))
    }

    // MARK: - Staleness Tracking Tests

    @Test("markAffectedHikesStale sets scheduleChanged reason on future uncompleted hikes")
    func testMarkAffectedHikesStaleMarksFutureHikes() throws {
        let context = try createTestContext()
        let dog = createTestDog(name: "Buddy", regularSchedule: [.monday], in: context)

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()

        // Create a hike for this dog
        let hikes = manager.getDailyHikes(for: monday)
        #expect(hikes.count == 1)
        #expect(hikes[0].staleReason == nil)
        #expect(hikes[0].isStale == false)

        // Mark affected hikes as stale (simulating schedule change)
        manager.markAffectedHikesStale(for: dog.id, after: Date())

        // Verify hike now has scheduleChanged reason
        let updatedHikes = manager.fetchExistingHikes(for: monday)
        #expect(updatedHikes.count == 1)
        #expect(updatedHikes[0].staleReason == .scheduleChanged)
        #expect(updatedHikes[0].isStale == true)
    }

    @Test("markAffectedHikesStale does not affect completed hikes")
    func testMarkAffectedHikesStaleIgnoresCompleted() throws {
        let context = try createTestContext()
        let dog = createTestDog(name: "Buddy", regularSchedule: [.monday], in: context)

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()

        // Create and complete a hike
        let hikes = manager.getDailyHikes(for: monday)
        #expect(hikes.count == 1)
        hikes[0].completedAt = Date()  // Mark as completed
        #expect(hikes[0].isCompleted == true)

        // Try to mark as stale
        manager.markAffectedHikesStale(for: dog.id, after: Date())

        // Verify completed hike has no stale reason (should be ignored)
        let updatedHikes = manager.fetchExistingHikes(for: monday)
        #expect(updatedHikes.count == 1)
        #expect(updatedHikes[0].staleReason == nil)
        #expect(updatedHikes[0].isStale == false)
    }

    @Test("markAffectedHikesStale does not affect past hikes")
    func testMarkAffectedHikesStaleIgnoresPast() throws {
        let context = try createTestContext()
        let dog = createTestDog(name: "Buddy", regularSchedule: [.monday], in: context)

        let manager = DailyHikeManager(modelContext: context)

        // Create a hike in the past
        let pastMonday = Calendar.current.date(byAdding: .day, value: -7, to: getMonday())!
        _ = manager.getDailyHikes(for: pastMonday)

        // Mark stale starting from today (past hike should be unaffected)
        manager.markAffectedHikesStale(for: dog.id, after: Date())

        // Verify past hike has no stale reason
        let updatedHikes = manager.fetchExistingHikes(for: pastMonday)
        if !updatedHikes.isEmpty {
            #expect(updatedHikes[0].staleReason == nil)
            #expect(updatedHikes[0].isStale == false)
        }
    }

    @Test("markAffectedHikesStale only affects hikes with matching dogId")
    func testMarkAffectedHikesStaleOnlyAffectsMatchingDog() throws {
        let context = try createTestContext()
        let buddy = createTestDog(name: "Buddy", regularSchedule: [.monday], in: context)
        let _ = createTestDog(name: "Max", regularSchedule: [.monday], in: context)

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()

        // Create hikes (both dogs in same hike)
        let hikes = manager.getDailyHikes(for: monday)
        #expect(hikes.count == 1)
        #expect(hikes[0].participations.count == 2)
        #expect(hikes[0].staleReason == nil)

        // Mark only Buddy's hikes as stale
        manager.markAffectedHikesStale(for: buddy.id, after: Date())

        // The hike contains Buddy, so it should have scheduleChanged reason
        let updatedHikes = manager.fetchExistingHikes(for: monday)
        #expect(updatedHikes[0].staleReason == .scheduleChanged)
        #expect(updatedHikes[0].isStale == true)
    }

    // MARK: - Reset Hike Tests

    @Test("resetDailyHike deletes existing hike")
    func testResetDailyHikeDeletesExisting() throws {
        let context = try createTestContext()
        let _ = createTestDog(name: "Buddy", regularSchedule: [.monday], in: context)

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()

        // Create a hike
        let hikes = manager.getDailyHikes(for: monday)
        #expect(hikes.count == 1)
        let originalId = hikes[0].id

        // Reset the hike
        manager.resetDailyHike(hikes[0])

        // Verify old hike is gone
        let existingHikes = manager.fetchExistingHikes(for: monday)
        #expect(existingHikes.isEmpty)

        // Regenerate
        let newHikes = manager.getDailyHikes(for: monday)
        #expect(newHikes.count == 1)
        #expect(newHikes[0].id != originalId)  // New hike has different ID
    }

    @Test("resetDailyHike clears stale reason on regeneration")
    func testResetDailyHikeClearsStaleReason() throws {
        let context = try createTestContext()
        let dog = createTestDog(name: "Buddy", regularSchedule: [.monday], in: context)

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()

        // Create a hike and mark it stale with scheduleChanged reason
        _ = manager.getDailyHikes(for: monday)
        manager.markAffectedHikesStale(for: dog.id, after: Date())

        let staleHikes = manager.fetchExistingHikes(for: monday)
        #expect(staleHikes[0].staleReason == .scheduleChanged)
        #expect(staleHikes[0].isStale == true)

        // Reset the stale hike
        manager.resetDailyHike(staleHikes[0])

        // Regenerate - new hike should have no stale reason
        let freshHikes = manager.getDailyHikes(for: monday)
        #expect(freshHikes[0].staleReason == nil)
        #expect(freshHikes[0].isStale == false)
    }

    @Test("resetDailyHike regenerates with current schedule")
    func testResetDailyHikeUsesCurrentSchedule() throws {
        let context = try createTestContext()
        let dog = createTestDog(name: "Buddy", regularSchedule: [.monday], in: context)

        let manager = DailyHikeManager(modelContext: context)
        let monday = getMonday()

        // Create initial hike
        let hikes = manager.getDailyHikes(for: monday)
        #expect(hikes[0].participations.count == 1)
        #expect(hikes[0].participations[0].dogName == "Buddy")

        // Change dog's schedule to remove Monday
        dog.regularSchedule = [.tuesday, .wednesday]

        // Reset the hike
        manager.resetDailyHike(hikes[0])

        // Regenerate - Buddy should no longer be included
        let newHikes = manager.getDailyHikes(for: monday)
        #expect(newHikes.isEmpty)  // No dogs scheduled for Monday anymore
    }
}
