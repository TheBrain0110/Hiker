//
//  ScheduleOverrideTests.swift
//  HikerTests
//
//  Created by Claude on 12/16/25.
//

import Foundation
import Testing
import SwiftData
@testable import Hiker

/// Integration tests for ScheduleOverride state transitions and badge logic.
///
/// ## Currently Disabled - SwiftData Cross-Module Issue
///
/// These tests verify the schedule override system which allows temporary
/// modifications to a dog's regular weekly schedule. They require `ModelContext`
/// to create, query, and delete `ScheduleOverride` records.
///
/// See `DailyHikeManagerTests.swift` header for full explanation of the
/// SwiftData cross-module type metadata issue that prevents these from running.
///
/// ## What These Tests Cover (When Enabled)
///
/// **Override State Transitions:**
/// - Adding `.isAbsent` override removes dog from their regular day
/// - Adding `.isPresent` override adds dog to a non-regular day
/// - Deleting override reverts to regular schedule
///
/// **DailyHikeManager Integration:**
/// - Verifies manager respects `.isAbsent` (excludes dog)
/// - Verifies manager respects `.isPresent` (includes dog)
///
/// **Badge Logic:**
/// - `.isPresent` override → shows "Added" badge (green)
/// - `.isAbsent` override → shows "Removed" badge (red)
/// - No override → no badge (following regular schedule)
///
/// ## Alternative Testing Approaches
///
/// The `ScheduleOverride.type` computed property IS testable without context
/// (see ModelTests.swift). What's NOT testable is the integration with
/// fetching/querying overrides for a specific dog and date.
@Suite(.disabled("SwiftData context not available in unit tests - see DailyHikeManagerTests for details"))
@MainActor
struct ScheduleOverrideTests {

    // MARK: - Test Helpers

    /// Creates an in-memory ModelContext for testing.
    /// See DailyHikeManagerTests for why this crashes at runtime.
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
        in context: ModelContext
    ) -> Dog {
        let client = Client(ownerName: "Test Owner", address: "123 Test St")
        context.insert(client)

        let dog = Dog(
            name: name,
            client: client,
            locationAddress: "123 Test St",
            regularSchedule: regularSchedule,
            paymentRate: 25.00
        )
        context.insert(dog)

        return dog
    }

    private func getOverride(
        for dogId: UUID,
        on date: Date,
        in context: ModelContext
    ) -> ScheduleOverride? {
        let descriptor = FetchDescriptor<ScheduleOverride>()
        let allOverrides = try? context.fetch(descriptor)

        return allOverrides?.first { override in
            override.dogId == dogId &&
            Calendar.current.isDate(override.date, inSameDayAs: date)
        }
    }

    // MARK: - Override State Transition Tests

    @Test("Dog in regular schedule can be removed with .isAbsent override")
    func testRemoveDogFromRegularSchedule() async throws {
        let context = try createTestContext()
        let dog = createTestDog(
            name: "Buddy",
            regularSchedule: [.monday, .wednesday, .friday],
            in: context
        )

        let monday = Date() // Assume today is Monday for simplicity

        // Initial state: No override
        #expect(getOverride(for: dog.id, on: monday, in: context) == nil)

        // Remove dog from Monday (their regular day)
        let override = ScheduleOverride(
            dogId: dog.id,
            date: monday,
            type: .isAbsent
        )
        context.insert(override)

        // Verify .isAbsent override was created
        let result = getOverride(for: dog.id, on: monday, in: context)
        #expect(result != nil)
        #expect(result?.type == .isAbsent)
    }

    @Test("Dog NOT in regular schedule can be added with .isPresent override")
    func testAddDogToNonRegularDay() async throws {
        let context = try createTestContext()
        let dog = createTestDog(
            name: "Max",
            regularSchedule: [.tuesday, .thursday],
            in: context
        )

        let monday = Date() // Dog not scheduled for Monday

        // Initial state: No override
        #expect(getOverride(for: dog.id, on: monday, in: context) == nil)

        // Add dog to Monday (not their regular day)
        let override = ScheduleOverride(
            dogId: dog.id,
            date: monday,
            type: .isPresent
        )
        context.insert(override)

        // Verify .isPresent override was created
        let result = getOverride(for: dog.id, on: monday, in: context)
        #expect(result != nil)
        #expect(result?.type == .isPresent)
    }

    @Test("Removing .isAbsent override reverts to regular schedule")
    func testRevertAbsentOverride() async throws {
        let context = try createTestContext()
        let dog = createTestDog(
            name: "Luna",
            regularSchedule: [.monday, .wednesday, .friday],
            in: context
        )

        let monday = Date()

        // Create .isAbsent override
        let override = ScheduleOverride(
            dogId: dog.id,
            date: monday,
            type: .isAbsent
        )
        context.insert(override)

        // Verify override exists
        #expect(getOverride(for: dog.id, on: monday, in: context) != nil)

        // Delete override (revert to regular schedule)
        context.delete(override)

        // Verify override is gone
        #expect(getOverride(for: dog.id, on: monday, in: context) == nil)
    }

    @Test("Removing .isPresent override reverts to not scheduled")
    func testRevertPresentOverride() async throws {
        let context = try createTestContext()
        let dog = createTestDog(
            name: "Charlie",
            regularSchedule: [.tuesday, .thursday],
            in: context
        )

        let monday = Date()

        // Create .isPresent override
        let override = ScheduleOverride(
            dogId: dog.id,
            date: monday,
            type: .isPresent
        )
        context.insert(override)

        // Verify override exists
        #expect(getOverride(for: dog.id, on: monday, in: context)?.type == .isPresent)

        // Delete override (revert to not scheduled)
        context.delete(override)

        // Verify override is gone
        #expect(getOverride(for: dog.id, on: monday, in: context) == nil)
    }

    // MARK: - DailyHikeManager Integration Tests

    @Test("DailyHikeManager respects .isAbsent override")
    func testDailyHikeManagerRespectsAbsent() async throws {
        let context = try createTestContext()
        let dog = createTestDog(
            name: "Buddy",
            regularSchedule: [.monday, .wednesday, .friday],
            in: context
        )

        // Create a specific Monday date
        let calendar = Calendar.current
        let components = DateComponents(year: 2025, month: 12, day: 15) // Monday
        guard let monday = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        // Initially, dog should be scheduled on Monday
        let manager = DailyHikeManager(modelContext: context)
        let initialHikes = manager.getDailyHikes(for: monday)
        let initialDogIds = initialHikes.flatMap { $0.participations.map { $0.dogId } }
        #expect(initialDogIds.contains(dog.id))

        // Add .isAbsent override for Monday
        let override = ScheduleOverride(
            dogId: dog.id,
            date: monday,
            type: .isAbsent
        )
        context.insert(override)

        // Now dog should NOT be scheduled on Monday
        let updatedHikes = manager.getDailyHikes(for: monday)
        let updatedDogIds = updatedHikes.flatMap { $0.participations.map { $0.dogId } }
        #expect(!updatedDogIds.contains(dog.id))
    }

    @Test("DailyHikeManager respects .isPresent override")
    func testDailyHikeManagerRespectsPresent() async throws {
        let context = try createTestContext()
        let dog = createTestDog(
            name: "Max",
            regularSchedule: [.tuesday, .thursday],
            in: context
        )

        // Create a specific Monday date (dog not normally scheduled)
        let calendar = Calendar.current
        let components = DateComponents(year: 2025, month: 12, day: 15) // Monday
        guard let monday = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        // Initially, dog should NOT be scheduled on Monday
        let manager = DailyHikeManager(modelContext: context)
        let initialHikes = manager.getDailyHikes(for: monday)
        let initialDogIds = initialHikes.flatMap { $0.participations.map { $0.dogId } }
        #expect(!initialDogIds.contains(dog.id))

        // Add .isPresent override for Monday
        let override = ScheduleOverride(
            dogId: dog.id,
            date: monday,
            type: .isPresent
        )
        context.insert(override)

        // Now dog SHOULD be scheduled on Monday
        let updatedHikes = manager.getDailyHikes(for: monday)
        let updatedDogIds = updatedHikes.flatMap { $0.participations.map { $0.dogId } }
        #expect(updatedDogIds.contains(dog.id))
    }

    // MARK: - Badge Logic Tests

    @Test("isPresent override should show Added badge")
    func testAddedBadgeLogic() async throws {
        let context = try createTestContext()
        let dog = createTestDog(
            name: "Luna",
            regularSchedule: [.tuesday],
            in: context
        )

        let monday = Date()

        // Create .isPresent override
        let override = ScheduleOverride(
            dogId: dog.id,
            date: monday,
            type: .isPresent
        )
        context.insert(override)

        // Fetch all overrides
        let descriptor = FetchDescriptor<ScheduleOverride>()
        let allOverrides = try context.fetch(descriptor)

        // Check badge logic (mimics showAddedBadge function)
        let shouldShowBadge = allOverrides.contains { override in
            Calendar.current.isDate(override.date, inSameDayAs: monday) &&
            override.dogId == dog.id &&
            override.type == .isPresent
        }

        #expect(shouldShowBadge == true)
    }

    @Test("isAbsent override should show Removed badge")
    func testRemovedBadgeLogic() async throws {
        let context = try createTestContext()
        let dog = createTestDog(
            name: "Charlie",
            regularSchedule: [.monday, .wednesday],
            in: context
        )

        let monday = Date()

        // Create .isAbsent override
        let override = ScheduleOverride(
            dogId: dog.id,
            date: monday,
            type: .isAbsent
        )
        context.insert(override)

        // Fetch all overrides
        let descriptor = FetchDescriptor<ScheduleOverride>()
        let allOverrides = try context.fetch(descriptor)

        // Check badge logic (mimics isOverriddenAbsent function)
        let shouldShowBadge = allOverrides.contains { override in
            Calendar.current.isDate(override.date, inSameDayAs: monday) &&
            override.dogId == dog.id &&
            override.type == .isAbsent
        }

        #expect(shouldShowBadge == true)
    }

    @Test("No override should show no badge")
    func testNoBadgeWhenNoOverride() async throws {
        let context = try createTestContext()
        let dog = createTestDog(
            name: "Buddy",
            regularSchedule: [.monday],
            in: context
        )

        let monday = Date()

        // No override created

        // Fetch all overrides (should be empty)
        let descriptor = FetchDescriptor<ScheduleOverride>()
        let allOverrides = try context.fetch(descriptor)

        // Check badge logic - neither badge should show
        let shouldShowAdded = allOverrides.contains { override in
            Calendar.current.isDate(override.date, inSameDayAs: monday) &&
            override.dogId == dog.id &&
            override.type == .isPresent
        }

        let shouldShowRemoved = allOverrides.contains { override in
            Calendar.current.isDate(override.date, inSameDayAs: monday) &&
            override.dogId == dog.id &&
            override.type == .isAbsent
        }

        #expect(shouldShowAdded == false)
        #expect(shouldShowRemoved == false)
    }
}
