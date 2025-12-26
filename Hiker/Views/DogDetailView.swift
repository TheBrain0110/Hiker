//
//  DogDetailView.swift
//  Hiker
//
//  Created by Claude on 12/15/25.
//

import SwiftUI
import SwiftData

enum DogScheduleViewMode {
    case weeklyPattern
    case calendar
}

struct DogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var dog: Dog

    @State private var showingEditDog = false
    @State private var scheduleViewMode: DogScheduleViewMode = .weeklyPattern

    var body: some View {
        List {
            // Dog Header
            Section {
                dogHeader
            }

            // Schedule - With view mode picker
            Section {
                // Segmented picker
                Picker("View Mode", selection: $scheduleViewMode) {
                    Text("Weekly Pattern").tag(DogScheduleViewMode.weeklyPattern)
                    Text("Calendar").tag(DogScheduleViewMode.calendar)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 8)

                // Conditional view
                if scheduleViewMode == .weeklyPattern {
                    EditableWeeklySchedule(dog: dog)
                } else {
                    DogScheduleCalendarView(dog: dog)
                        .frame(height: 380)
                }
            } header: {
                Text("Schedule")
            } footer: {
                if scheduleViewMode == .calendar {
                    Text("Tap dates to override your weekly pattern. Tap again to revert.")
                } else {
                    Text("Tap days to toggle. Changes save automatically.")
                }
            }

            // Pickup Location
            Section("Pickup Location") {
                if let address = dog.locationAddress, !address.isEmpty {
                    Text(address)
                } else {
                    Text("Using client's address")
                        .foregroundStyle(.secondary)
                }
            }

            // Payment
            Section("Payment") {
                LabeledContent("Rate per Hike") {
                    Text("$\(dog.paymentRate as NSDecimalNumber)")
                }

                // Future: Payment history and balance
                NavigationLink {
                    PaymentHistoryPlaceholder(dog: dog)
                } label: {
                    HStack {
                        Text("Payment History")
                        Spacer()
                        Text("\(dog.payments.count) payments")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Notes
            if !dog.notes.isEmpty {
                Section("Notes") {
                    Text(dog.notes)
                        .foregroundStyle(.secondary)
                }
            }

            // Status
            Section {
                Toggle("Active", isOn: $dog.isActive)
            } footer: {
                Text("Inactive dogs won't appear in daily schedules.")
            }
        }
        .navigationTitle(dog.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditDog = true
                }
            }
        }
        .sheet(isPresented: $showingEditDog) {
            EditDogView(dog: dog)
        }
    }

    private var dogHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(dog.isActive ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: "pawprint.fill")
                    .font(.title)
                    .foregroundStyle(dog.isActive ? .blue : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dog.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if !dog.isActive {
                        Badge(text: "Inactive", color: .gray)
                    }
                }

                if let owner = dog.client?.ownerName {
                    Text(owner)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !dog.regularSchedule.isEmpty {
                    Text(scheduleDescription)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var scheduleDescription: String {
        let days = dog.regularSchedule.sorted { $0.rawValue < $1.rawValue }
        if days.count == 5 {
            return "Every weekday"
        } else if days.count == 0 {
            return "No regular schedule"
        } else {
            return days.map { $0.shortName }.joined(separator: ", ")
        }
    }
}

// MARK: - Editable Weekly Schedule

struct EditableWeeklySchedule: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var dog: Dog

    var body: some View {
        VStack(spacing: 16) {
            // Day buttons
            HStack(spacing: 8) {
                ForEach(DayOfWeek.allCases) { day in
                    ScheduleDayButton(
                        day: day,
                        isSelected: dog.regularSchedule.contains(day)
                    ) {
                        toggleDay(day)
                    }
                }
            }

            // Summary
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)

                if dog.regularSchedule.isEmpty {
                    Text("No days selected")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(dog.regularSchedule.count) days per week")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(weeklyTotal)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 8)
    }

    private var weeklyTotal: String {
        let total = dog.paymentRate * Decimal(dog.regularSchedule.count)
        return "$\(total as NSDecimalNumber)/week"
    }

    private func toggleDay(_ day: DayOfWeek) {
        var schedule = dog.regularSchedule
        if let index = schedule.firstIndex(of: day) {
            schedule.remove(at: index)
        } else {
            schedule.append(day)
            schedule.sort { $0.rawValue < $1.rawValue }
        }
        dog.regularSchedule = schedule

        // Mark future hikes as stale since schedule changed
        let manager = DailyHikeManager(modelContext: modelContext)
        manager.markAffectedHikesStale(for: dog.id, after: Date())
    }
}

struct ScheduleDayButton: View {
    let day: DayOfWeek
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(String(day.shortName.prefix(1)))
                    .font(.headline)
                    .fontWeight(.bold)
                Text(day.shortName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.15))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.name), \(isSelected ? "selected" : "not selected")")
    }
}

// MARK: - Edit Dog View

struct EditDogView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var dog: Dog

    @State private var selectedDays: Set<DayOfWeek> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Dog Information") {
                    TextField("Name", text: $dog.name)

                    HStack {
                        Text("Rate")
                        Spacer()
                        TextField("Rate", value: $dog.paymentRate, format: .currency(code: "CAD"))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Pickup Address") {
                    TextField("Address", text: Binding(
                        get: { dog.locationAddress ?? "" },
                        set: { dog.locationAddress = $0.isEmpty ? nil : $0 }
                    ))
                    .textContentType(.fullStreetAddress)
                }

                Section("Notes") {
                    TextField("Notes", text: $dog.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Dog")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Payment History Placeholder

struct PaymentHistoryPlaceholder: View {
    let dog: Dog

    var body: some View {
        Group {
            if dog.payments.isEmpty {
                ContentUnavailableView(
                    "No Payments",
                    systemImage: "dollarsign.circle",
                    description: Text("Payment tracking coming soon.")
                )
            } else {
                List(dog.payments.sorted { $0.date > $1.date }) { payment in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.headline)
                            if let notes = payment.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("$\(payment.amount as NSDecimalNumber)")
                                .font(.headline)
                            if payment.paid {
                                Badge(text: "Paid", color: .green)
                            } else {
                                Badge(text: "Pending", color: .orange)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Payments")
    }
}

#Preview {
    let schema = Schema([Client.self, Dog.self, Payment.self, ScheduleOverride.self, HikingLocation.self, DailyHike.self, HikeParticipation.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    SampleData.createSampleData(in: container.mainContext)

    // Get first dog from sample data (Maya)
    let descriptor = FetchDescriptor<Dog>(sortBy: [SortDescriptor(\.name)])
    let dogs = try! container.mainContext.fetch(descriptor)

    return NavigationStack {
        if let dog = dogs.first {
            DogDetailView(dog: dog)
        } else {
            Text("No dogs available")
        }
    }
    .modelContainer(container)
}
