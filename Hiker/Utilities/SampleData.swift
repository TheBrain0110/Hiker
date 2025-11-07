//
//  SampleData.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation
import SwiftData

@MainActor
class SampleData {

    /// Creates sample data for testing and development
    static func createSampleData(in context: ModelContext) {
        // Clear existing data (for fresh start)
        try? context.delete(model: Client.self)
        try? context.delete(model: Dog.self)
        try? context.delete(model: Payment.self)
        try? context.delete(model: ScheduleException.self)
        try? context.delete(model: HikingLocation.self)

        // Create hiking locations in Halifax area
        let locations = createHikingLocations()
        locations.forEach { context.insert($0) }

        // Create sample clients and dogs
        let clientsAndDogs = createClientsAndDogs()
        clientsAndDogs.forEach { client in
            context.insert(client)
            client.dogs.forEach { dog in
                context.insert(dog)
            }
        }

        // Create some sample payments
        let payments = createSamplePayments(for: clientsAndDogs)
        payments.forEach { context.insert($0) }

        // Save all changes
        try? context.save()
    }

    private static func createHikingLocations() -> [HikingLocation] {
        return [
            HikingLocation(
                name: "Blue Mountain-Birch Cove Lakes",
                latitude: 44.6884,
                longitude: -63.7064,
                region: "Bedford",
                notes: "Popular trail with lake access"
            ),
            HikingLocation(
                name: "Shubenacadie Canal Trail",
                latitude: 44.7394,
                longitude: -63.6732,
                region: "Sackville",
                notes: "Easy walking trail along canal"
            ),
            HikingLocation(
                name: "Hemlock Ravine Park",
                latitude: 44.6845,
                longitude: -63.6531,
                region: "Bedford",
                notes: "Forested trails, good for groups"
            ),
            HikingLocation(
                name: "Springfield Lake",
                latitude: 44.7742,
                longitude: -63.6234,
                region: "Sackville",
                notes: "Lake trail with beach area"
            ),
            HikingLocation(
                name: "Silver Mine Trails",
                latitude: 44.8123,
                longitude: -63.5892,
                region: "Beaver Bank",
                notes: "Quiet trails, less crowded"
            )
        ]
    }

    private static func createClientsAndDogs() -> [Client] {
        var clients: [Client] = []

        // Bedford clients
        let client1 = Client(
            ownerName: "Sarah Johnson",
            phone: "902-555-0101",
            email: "sarah.j@email.com",
            address: "123 Bedford Highway, Bedford, NS",
            latitude: 44.7321,
            longitude: -63.6841
        )
        let dog1 = Dog(
            name: "Max",
            client: client1,
            locationLatitude: 44.7321,
            locationLongitude: -63.6841,
            locationAddress: "123 Bedford Highway, Bedford, NS",
            regularSchedule: [.monday, .wednesday, .friday],
            paymentRate: 30.00,
            notes: "Very energetic, loves water"
        )
        client1.dogs = [dog1]
        clients.append(client1)

        let client2 = Client(
            ownerName: "Michael Chen",
            phone: "902-555-0102",
            email: "mchen@email.com",
            address: "456 Shore Drive, Bedford, NS",
            latitude: 44.7412,
            longitude: -63.6723
        )
        let dog2 = Dog(
            name: "Luna",
            client: client2,
            locationLatitude: 44.7412,
            locationLongitude: -63.6723,
            locationAddress: "456 Shore Drive, Bedford, NS",
            regularSchedule: [.monday, .wednesday],
            paymentRate: 25.00,
            notes: "Friendly with all dogs"
        )
        let dog3 = Dog(
            name: "Charlie",
            client: client2,
            locationLatitude: 44.7412,
            locationLongitude: -63.6723,
            locationAddress: "456 Shore Drive, Bedford, NS",
            regularSchedule: [.tuesday, .thursday],
            paymentRate: 25.00,
            notes: "Senior dog, needs gentle pace"
        )
        client2.dogs = [dog2, dog3]
        clients.append(client2)

        // Sackville clients
        let client3 = Client(
            ownerName: "Emily MacDonald",
            phone: "902-555-0103",
            email: "emacdonald@email.com",
            address: "789 Sackville Drive, Sackville, NS",
            latitude: 44.7643,
            longitude: -63.6534
        )
        let dog4 = Dog(
            name: "Bella",
            client: client3,
            locationLatitude: 44.7643,
            locationLongitude: -63.6534,
            locationAddress: "789 Sackville Drive, Sackville, NS",
            regularSchedule: [.monday, .tuesday, .thursday],
            paymentRate: 30.00,
            notes: "High energy, needs lots of running"
        )
        client3.dogs = [dog4]
        clients.append(client3)

        let client4 = Client(
            ownerName: "David Smith",
            phone: "902-555-0104",
            email: "dsmith@email.com",
            address: "234 First Lake Drive, Sackville, NS",
            latitude: 44.7789,
            longitude: -63.6412
        )
        let dog5 = Dog(
            name: "Cooper",
            client: client4,
            locationLatitude: 44.7789,
            locationLongitude: -63.6412,
            locationAddress: "234 First Lake Drive, Sackville, NS",
            regularSchedule: [.wednesday, .friday],
            paymentRate: 25.00,
            notes: "Loves to swim"
        )
        let dog6 = Dog(
            name: "Daisy",
            client: client4,
            locationLatitude: 44.7789,
            locationLongitude: -63.6412,
            locationAddress: "234 First Lake Drive, Sackville, NS",
            regularSchedule: [.monday, .wednesday, .friday],
            paymentRate: 25.00,
            notes: "Very social, great with other dogs"
        )
        client4.dogs = [dog5, dog6]
        clients.append(client4)

        // Beaver Bank clients
        let client5 = Client(
            ownerName: "Jennifer Williams",
            phone: "902-555-0105",
            email: "jwilliams@email.com",
            address: "567 Beaver Bank Road, Beaver Bank, NS",
            latitude: 44.8234,
            longitude: -63.5923
        )
        let dog7 = Dog(
            name: "Rocky",
            client: client5,
            locationLatitude: 44.8234,
            locationLongitude: -63.5923,
            locationAddress: "567 Beaver Bank Road, Beaver Bank, NS",
            regularSchedule: [.tuesday, .thursday],
            paymentRate: 30.00,
            notes: "Needs to be picked up last, reactive with unfamiliar dogs initially"
        )
        client5.dogs = [dog7]
        clients.append(client5)

        let client6 = Client(
            ownerName: "Robert Taylor",
            phone: "902-555-0106",
            email: "rtaylor@email.com",
            address: "890 Windsor Junction Road, Beaver Bank, NS",
            latitude: 44.8123,
            longitude: -63.5834
        )
        let dog8 = Dog(
            name: "Molly",
            client: client6,
            locationLatitude: 44.8123,
            locationLongitude: -63.5834,
            locationAddress: "890 Windsor Junction Road, Beaver Bank, NS",
            regularSchedule: [.monday, .tuesday, .wednesday, .thursday, .friday],
            paymentRate: 25.00,
            notes: "Regular 5 days/week, very reliable client"
        )
        client6.dogs = [dog8]
        clients.append(client6)

        return clients
    }

    private static func createSamplePayments(for clients: [Client]) -> [Payment] {
        var payments: [Payment] = []
        let calendar = Calendar.current
        let today = Date()

        // Create payments for each dog
        for client in clients {
            for dog in client.dogs {
                // Most recent payment (within 2 weeks - not overdue)
                let recentPayment = Payment(
                    dog: dog,
                    date: calendar.date(byAdding: .day, value: -7, to: today)!,
                    amount: dog.paymentRate * 2,  // 2 weeks advance
                    paid: true,
                    method: "e-transfer"
                )
                payments.append(recentPayment)

                // Previous payment (4 weeks ago)
                let previousPayment = Payment(
                    dog: dog,
                    date: calendar.date(byAdding: .day, value: -28, to: today)!,
                    amount: dog.paymentRate * 2,
                    paid: true,
                    method: "e-transfer"
                )
                payments.append(previousPayment)
            }
        }

        // Make one dog overdue for testing
        if let firstDog = clients.first?.dogs.first {
            // Remove recent payments for this dog
            payments.removeAll { $0.dog?.id == firstDog.id }

            // Add only an old payment (20 days ago - overdue)
            let overduePayment = Payment(
                dog: firstDog,
                date: calendar.date(byAdding: .day, value: -20, to: today)!,
                amount: firstDog.paymentRate * 2,
                paid: true,
                method: "cash",
                notes: "This payment is now overdue"
            )
            payments.append(overduePayment)
        }

        return payments
    }
}
