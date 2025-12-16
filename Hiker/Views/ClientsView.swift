//
//  ClientsView.swift
//  Hiker
//
//  Created by Claude on 12/15/25.
//

import SwiftUI
import SwiftData

struct ClientsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.ownerName) private var clients: [Client]

    @State private var searchText = ""
    @State private var showingAddClient = false

    var filteredClients: [Client] {
        if searchText.isEmpty {
            return clients
        }
        return clients.filter { client in
            client.ownerName.localizedCaseInsensitiveContains(searchText) ||
            client.dogs.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var activeClients: [Client] {
        filteredClients.filter { $0.isActive }
    }

    var inactiveClients: [Client] {
        filteredClients.filter { !$0.isActive }
    }

    var body: some View {
        NavigationStack {
            Group {
                if clients.isEmpty {
                    ContentUnavailableView(
                        "No Clients",
                        systemImage: "person.2",
                        description: Text("Add clients to start managing their dogs and schedules.")
                    )
                } else {
                    clientList
                }
            }
            .navigationTitle("Clients")
            .searchable(text: $searchText, prompt: "Search clients or dogs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddClient = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddClient) {
                AddClientView()
            }
        }
    }

    private var clientList: some View {
        List {
            if !activeClients.isEmpty {
                Section("Active Clients") {
                    ForEach(activeClients) { client in
                        NavigationLink {
                            ClientDetailView(client: client)
                        } label: {
                            ClientRow(client: client)
                        }
                    }
                    .onDelete { indexSet in
                        deleteClients(at: indexSet, from: activeClients)
                    }
                }
            }

            if !inactiveClients.isEmpty {
                Section("Inactive Clients") {
                    ForEach(inactiveClients) { client in
                        NavigationLink {
                            ClientDetailView(client: client)
                        } label: {
                            ClientRow(client: client)
                        }
                    }
                    .onDelete { indexSet in
                        deleteClients(at: indexSet, from: inactiveClients)
                    }
                }
            }
        }
    }

    private func deleteClients(at offsets: IndexSet, from clientList: [Client]) {
        for index in offsets {
            let client = clientList[index]
            modelContext.delete(client)
        }
    }
}

// MARK: - Client Row

struct ClientRow: View {
    let client: Client

    var activeDogs: [Dog] {
        client.dogs.filter { $0.isActive }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(client.isActive ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(client.ownerName.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundStyle(client.isActive ? .blue : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(client.ownerName)
                    .font(.headline)

                if activeDogs.isEmpty {
                    Text("No active dogs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(activeDogs.map { $0.name }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Dog count badge
            if !activeDogs.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "pawprint.fill")
                        .font(.caption2)
                    Text("\(activeDogs.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Client View

struct AddClientView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var ownerName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""

    var isValid: Bool {
        !ownerName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !address.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Owner Information") {
                    TextField("Name", text: $ownerName)
                        .textContentType(.name)

                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        #endif
                }

                Section("Address") {
                    TextField("Address", text: $address)
                        .textContentType(.fullStreetAddress)
                }
            }
            .navigationTitle("New Client")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addClient()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func addClient() {
        let client = Client(
            ownerName: ownerName.trimmingCharacters(in: .whitespaces),
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            address: address.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(client)
        dismiss()
    }
}

#Preview {
    let schema = Schema([Client.self, Dog.self, Payment.self, ScheduleOverride.self, HikingLocation.self, CompletedHike.self, DogAttendance.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    SampleData.createSampleData(in: container.mainContext)

    return ClientsView()
        .modelContainer(container)
}
