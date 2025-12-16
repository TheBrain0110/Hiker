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

@MainActor
struct ScheduleOverrideTests {

    // MARK: - Test Helpers

    private func createTestContext() -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Client.self, Dog.self, ScheduleOverride.self,
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
        let context = createTestContext()
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
        let context = createTestContext()
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
        let context = createTestContext()
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
        let context = createTestContext()
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
        let context = createTestContext()
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
        let initialSchedule = manager.dailySchedule(for: monday)
        let initialDogs = initialSchedule.hikes.flatMap { $0.dogs }
        #expect(initialDogs.contains(where: { $0.id == dog.id }))

        // Add .isAbsent override for Monday
        let override = ScheduleOverride(
            dogId: dog.id,
            date: monday,
            type: .isAbsent
        )
        context.insert(override)

        // Now dog should NOT be scheduled on Monday
        let updatedSchedule = manager.dailySchedule(for: monday)
        let updatedDogs = updatedSchedule.hikes.flatMap { $0.dogs }
        #expect(!updatedDogs.contains(where: { $0.id == dog.id }))
    }

    @Test("DailyHikeManager respects .isPresent override")
    func testDailyHikeManagerRespectsPresent() async throws {
        let context = createTestContext()
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
        let initialSchedule = manager.dailySchedule(for: monday)
        let initialDogs = initialSchedule.hikes.flatMap { $0.dogs }
        #expect(!initialDogs.contains(where: { $0.id == dog.id }))

        // Add .isPresent override for Monday
        let override = ScheduleOverride(
            dogId: dog.id,
            date: monday,
            type: .isPresent
        )
        context.insert(override)

        // Now dog SHOULD be scheduled on Monday
        let updatedSchedule = manager.dailySchedule(for: monday)
        let updatedDogs = updatedSchedule.hikes.flatMap { $0.dogs }
        #expect(updatedDogs.contains(where: { $0.id == dog.id }))
    }

    // MARK: - Badge Logic Tests

    @Test("isPresent override should show Added badge")
    func testAddedBadgeLogic() async throws {
        let context = createTestContext()
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
        let context = createTestContext()
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
        let context = createTestContext()
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
