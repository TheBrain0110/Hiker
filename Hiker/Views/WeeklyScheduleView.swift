//
//  WeeklyScheduleView.swift
//  Hiker
//
//  Created by Gemini on 12/14/25.
//

import SwiftUI
import SwiftData

struct WeeklyScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate: Date = Date()
    
    // Fetch all dogs to show available/scheduled
    @Query(sort: \Dog.name) private var allDogs: [Dog]
    
    // Fetch overrides for the relevant period (we might filter in memory for MVP simplicity)
    @Query private var overrides: [ScheduleOverride]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. Week Calendar Strip
                WeekStrip(selectedDate: $selectedDate)
                    .padding()
                    .background(.background.secondary)
                
                // 2. Scheduled Dogs List
                List {
                    Section(header: Text("Scheduled for \(selectedDate.formatted(date: .abbreviated, time: .omitted))")) {
                        if scheduledDogs.isEmpty {
                            ContentUnavailableView(
                                "No Dogs Scheduled",
                                systemImage: "pawprint"
                            )
                        } else {
                            ForEach(scheduledDogs) { dog in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(dog.name)
                                            .font(.headline)
                                        Text(dog.client?.ownerName ?? "Unknown Owner")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    // Status Badge (Regular vs Added)
                                    if isOverriddenPresent(dog) {
                                        Badge(text: "Added", color: .green)
                                    } else if isRescheduled(dog) {
                                        Badge(text: "Rescheduled", color: .orange)
                                    }
                                    
                                    Button {
                                        removeDog(dog)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        removeDog(dog)
                                    } label: {
                                        Label("Remove", systemImage: "xmark.circle")
                                    }
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Available to Add")) {
                        ForEach(availableDogs) { dog in
                            HStack {
                                Text(dog.name)
                                Spacer()
                                Button {
                                    addDog(dog)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Weekly Schedule")
        }
    }
    
    // MARK: - Logic
    
    var scheduledDogs: [Dog] {
        allDogs.filter { isScheduled($0) }
    }
    
    var availableDogs: [Dog] {
        allDogs.filter { !isScheduled($0) && $0.isActive }
    }
    
    func isScheduled(_ dog: Dog) -> Bool {
        // Same logic as DailyHikeManager, but local for View reactivity
        let dayOfWeek = selectedDate.dayOfWeek
        
        // Find override for this specific day
        if let override = overrides.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && $0.dogId == dog.id
        }) {
            return override.type == .isPresent
        }
        
        // Fallback to regular schedule
        guard let dayOfWeek else { return false } // Weekend?
        return dog.regularSchedule.contains(dayOfWeek)
    }
    
    func isOverriddenPresent(_ dog: Dog) -> Bool {
        // Check if explicitly added
        return overrides.contains(where: {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && $0.dogId == dog.id && $0.type == .isPresent
        })
    }
    
    func isRescheduled(_ dog: Dog) -> Bool {
        // Placeholder complexity: If moved from another day
        return false 
    }
    
    // MARK: - Actions
    
    func addDog(_ dog: Dog) {
        // Create override .isPresent
        let override = ScheduleOverride(dogId: dog.id, date: selectedDate, type: .isPresent)
        modelContext.insert(override)
        // If there was an .isAbsent override, delete it? 
        // Logic: Search for existing override for this day.
        if let existing = overrides.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && $0.dogId == dog.id
        }) {
            // Updating existing override
            existing.type = .isPresent
        } else {
            // Create new
            modelContext.insert(override)
        }
    }
    
    func removeDog(_ dog: Dog) {
        // If dog has regular schedule today, we need .isAbsent override.
        // If dog was only here because of .isPresent override, we just delete that override.
        
        if let existing = overrides.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && $0.dogId == dog.id
        }) {
             if existing.type == .isPresent {
                 // It was added manually, so just remove the override to go back to "Not Scheduled"
                 modelContext.delete(existing)
                 return
             }
        }
        
        // Otherwise, presume it's regular schedule, so add .isAbsent
        let override = ScheduleOverride(dogId: dog.id, date: selectedDate, type: .isAbsent)
        modelContext.insert(override)
    }
}

// MARK: - Subviews

struct WeekStrip: View {
    @Binding var selectedDate: Date
    // Simplify: Just show Mon-Fri of current week
    // For MVP: Just +/- days buttons or a simple 5-day view
    
    var weekDates: [Date] {
        let today = Date()
        let calendar = Calendar.current
        let startOfWeek = today.startOfWeek // Assuming Extension exists
        // Mon-Fri
        return (0..<5).compactMap { dayOffset in
             calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }
    
    var body: some View {
        HStack {
            ForEach(weekDates, id: \.self) { date in
                VStack {
                    Text(date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption)
                    Text(date.formatted(.dateTime.day()))
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .padding(8)
                .background(Calendar.current.isDate(selectedDate, inSameDayAs: date) ? Color.blue : Color.clear)
                .foregroundColor(Calendar.current.isDate(selectedDate, inSameDayAs: date) ? .white : .primary)
                .clipShape(Capsule())
                .onTapGesture {
                    selectedDate = date
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
