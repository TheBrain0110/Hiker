//
//  ClientDetailView.swift
//  Hiker
//
//  Created by Claude on 12/15/25.
//

import SwiftUI
import SwiftData

struct ClientDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var client: Client

    @State private var showingAddDog = false
    @State private var showingEditClient = false

    var activeDogs: [Dog] {
        client.dogs.filter { $0.isActive }.sorted { $0.name < $1.name }
    }

    var inactiveDogs: [Dog] {
        client.dogs.filter { !$0.isActive }.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            // Client Info Section
            Section {
                clientInfoHeader
            }

            // Contact Info
            Section("Contact") {
                if let phone = client.phone, !phone.isEmpty {
                    LabeledContent("Phone", value: phone)
                }
                if let email = client.email, !email.isEmpty {
                    LabeledContent("Email", value: email)
                }
                LabeledContent("Address", value: client.address)
            }

            // Active Dogs
            Section {
                if activeDogs.isEmpty {
                    Text("No active dogs")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activeDogs) { dog in
                        NavigationLink {
                            DogDetailView(dog: dog)
                        } label: {
                            DogRow(dog: dog)
                        }
                    }
                    .onDelete { indexSet in
                        deleteDogs(at: indexSet, from: activeDogs)
                    }
                }
            } header: {
                HStack {
                    Text("Dogs")
                    Spacer()
                    Button {
                        showingAddDog = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }

            // Inactive Dogs
            if !inactiveDogs.isEmpty {
                Section("Inactive Dogs") {
                    ForEach(inactiveDogs) { dog in
                        NavigationLink {
                            DogDetailView(dog: dog)
                        } label: {
                            DogRow(dog: dog)
                        }
                    }
                    .onDelete { indexSet in
                        deleteDogs(at: indexSet, from: inactiveDogs)
                    }
                }
            }

            // Client Status
            Section {
                Toggle("Active Client", isOn: $client.isActive)
            } footer: {
                Text("Inactive clients and their dogs won't appear in schedules.")
            }
        }
        .navigationTitle(client.ownerName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditClient = true
                }
            }
        }
        .sheet(isPresented: $showingAddDog) {
            AddDogView(client: client)
        }
        .sheet(isPresented: $showingEditClient) {
            EditClientView(client: client)
        }
    }

    private var clientInfoHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(client.isActive ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                Text(client.ownerName.prefix(1).uppercased())
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(client.isActive ? .blue : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(client.ownerName)
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    Label("\(client.dogs.count) dogs", systemImage: "pawprint.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !client.isActive {
                        Badge(text: "Inactive", color: .gray)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func deleteDogs(at offsets: IndexSet, from dogList: [Dog]) {
        for index in offsets {
            let dog = dogList[index]
            modelContext.delete(dog)
        }
    }
}

// MARK: - Dog Row

struct DogRow: View {
    let dog: Dog

    var scheduleText: String {
        if dog.regularSchedule.isEmpty {
            return "No schedule set"
        }
        return dog.regularSchedule
            .sorted { $0.rawValue < $1.rawValue }
            .map { $0.shortName }
            .joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Dog avatar
            ZStack {
                Circle()
                    .fill(dogColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: "pawprint.fill")
                    .font(.body)
                    .foregroundStyle(dogColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dog.name)
                        .font(.headline)

                    if !dog.isActive {
                        Badge(text: "Inactive", color: .gray)
                    }
                }

                Text(scheduleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Rate badge
            Text("$\(dog.paymentRate as NSDecimalNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var dogColor: Color {
        guard dog.isActive else { return .gray }
        if let colorString = dog.color {
            switch colorString.lowercased() {
            case "red": return .red
            case "blue": return .blue
            case "green": return .green
            case "orange": return .orange
            case "purple": return .purple
            case "pink": return .pink
            default: return .blue
            }
        }
        return .blue
    }
}

// MARK: - Add Dog View

struct AddDogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let client: Client

    @State private var name = ""
    @State private var address = ""
    @State private var paymentRate: Decimal = 25.00
    @State private var notes = ""
    @State private var selectedDays: Set<DayOfWeek> = []

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dog Information") {
                    TextField("Name", text: $name)

                    TextField("Pickup Address", text: $address)
                        .textContentType(.fullStreetAddress)

                    HStack {
                        Text("Rate")
                        Spacer()
                        TextField("Rate", value: $paymentRate, format: .currency(code: "CAD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Weekly Schedule") {
                    WeeklySchedulePicker(selectedDays: $selectedDays)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addDog()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func addDog() {
        let dog = Dog(
            name: name.trimmingCharacters(in: .whitespaces),
            client: client,
            locationAddress: address.isEmpty ? client.address : address,
            regularSchedule: Array(selectedDays).sorted { $0.rawValue < $1.rawValue },
            paymentRate: paymentRate,
            notes: notes
        )

        // Use client's coordinates if no specific pickup address
        if address.isEmpty, let lat = client.latitude, let lon = client.longitude {
            dog.locationLatitude = lat
            dog.locationLongitude = lon
        }

        modelContext.insert(dog)
        dismiss()
    }
}

// MARK: - Edit Client View

struct EditClientView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var client: Client

    var body: some View {
        NavigationStack {
            Form {
                Section("Owner Information") {
                    TextField("Name", text: $client.ownerName)
                        .textContentType(.name)

                    TextField("Phone", text: Binding(
                        get: { client.phone ?? "" },
                        set: { client.phone = $0.isEmpty ? nil : $0 }
                    ))
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)

                    TextField("Email", text: Binding(
                        get: { client.email ?? "" },
                        set: { client.email = $0.isEmpty ? nil : $0 }
                    ))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                }

                Section("Address") {
                    TextField("Address", text: $client.address)
                        .textContentType(.fullStreetAddress)
                }
            }
            .navigationTitle("Edit Client")
            .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Weekly Schedule Picker

struct WeeklySchedulePicker: View {
    @Binding var selectedDays: Set<DayOfWeek>

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DayOfWeek.allCases) { day in
                DayToggle(day: day, isSelected: selectedDays.contains(day)) {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct DayToggle: View {
    let day: DayOfWeek
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(String(day.shortName.prefix(1)))
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Client.self, configurations: config)

    let client = Client(
        ownerName: "Sarah Johnson",
        phone: "902-555-0123",
        email: "sarah@example.com",
        address: "123 Main Street, Bedford"
    )
    container.mainContext.insert(client)

    let dog = Dog(
        name: "Buddy",
        client: client,
        locationAddress: "123 Main Street, Bedford",
        regularSchedule: [.monday, .wednesday, .friday],
        paymentRate: 25.00
    )
    container.mainContext.insert(dog)

    return NavigationStack {
        ClientDetailView(client: client)
    }
    .modelContainer(container)
}
