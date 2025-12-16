//
//  SampleData.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
class SampleData {

    /// Creates sample data for testing and development
    static func createSampleData(in context: ModelContext) {
        // Clear existing data (for fresh start)
        try? context.delete(model: Client.self)
        try? context.delete(model: Dog.self)
        try? context.delete(model: Payment.self)
        try? context.delete(model: ScheduleOverride.self)
        try? context.delete(model: HikingLocation.self)
        try? context.delete(model: CompletedHike.self)
        try? context.delete(model: DogAttendance.self)

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

        // Create sample completed hikes first (for testing historical views and payment linking)
        let completedHikes = createCompletedHikes(for: clientsAndDogs, locations: locations)
        completedHikes.forEach { context.insert($0) }

        // Create some sample payments linked to completed hikes
        let payments = createSamplePayments(for: clientsAndDogs, completedHikes: completedHikes)
        payments.forEach { context.insert($0) }

        // Create some realistic schedule overrides
        let overrides = createScheduleOverrides(for: clientsAndDogs)
        overrides.forEach { context.insert($0) }

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

        // HIKE 1: Bedford Area Dogs

        // Maya - M/W schedule
        let mayaClient = Client(
            ownerName: "Maya's Owner",
            phone: "902-555-0101",
            email: "maya@email.com",
            address: "101 Bedford Highway, Bedford, NS",
            latitude: 44.7321,
            longitude: -63.6841
        )
        let maya = Dog(
            name: "Maya",
            client: mayaClient,
            locationLatitude: 44.7321,
            locationLongitude: -63.6841,
            locationAddress: "101 Bedford Highway, Bedford, NS",
            regularSchedule: [.monday, .wednesday],
            paymentRate: 30.00,
            notes: "Occasionally adds Friday"
        )
        mayaClient.dogs = [maya]
        clients.append(mayaClient)

        // Finn - W/F schedule
        let finnClient = Client(
            ownerName: "Finn's Owner",
            phone: "902-555-0102",
            email: "finn@email.com",
            address: "102 Shore Drive, Bedford, NS",
            latitude: 44.7285,
            longitude: -63.6798
        )
        let finn = Dog(
            name: "Finn",
            client: finnClient,
            locationLatitude: 44.7285,
            locationLongitude: -63.6798,
            locationAddress: "102 Shore Drive, Bedford, NS",
            regularSchedule: [.wednesday, .friday],
            paymentRate: 30.00,
            notes: "Schedule varies occasionally"
        )
        finnClient.dogs = [finn]
        clients.append(finnClient)

        // Denver - M/W schedule
        let denverClient = Client(
            ownerName: "Denver's Owner",
            phone: "902-555-0103",
            email: "denver@email.com",
            address: "103 Rocky Lake Drive, Bedford, NS",
            latitude: 44.7356,
            longitude: -63.6823
        )
        let denver = Dog(
            name: "Denver",
            client: denverClient,
            locationLatitude: 44.7356,
            locationLongitude: -63.6823,
            locationAddress: "103 Rocky Lake Drive, Bedford, NS",
            regularSchedule: [.monday, .wednesday],
            paymentRate: 30.00,
            notes: "Sometimes switches days"
        )
        denverClient.dogs = [denver]
        clients.append(denverClient)

        // Huxley - Thu only
        let huxleyClient = Client(
            ownerName: "Huxley's Owner",
            phone: "902-555-0104",
            email: "huxley@email.com",
            address: "104 Bedford Basin Road, Bedford, NS",
            latitude: 44.7298,
            longitude: -63.6754
        )
        let huxley = Dog(
            name: "Huxley",
            client: huxleyClient,
            locationLatitude: 44.7298,
            locationLongitude: -63.6754,
            locationAddress: "104 Bedford Basin Road, Bedford, NS",
            regularSchedule: [.thursday],
            paymentRate: 30.00,
            notes: "Thursday regular"
        )
        huxleyClient.dogs = [huxley]
        clients.append(huxleyClient)

        // Halle - Inactive
        let halleClient = Client(
            ownerName: "Halle's Owner",
            phone: "902-555-0105",
            email: "halle@email.com",
            address: "105 Basinview Drive, Bedford, NS",
            latitude: 44.7334,
            longitude: -63.6812
        )
        let halle = Dog(
            name: "Halle",
            client: halleClient,
            locationLatitude: 44.7334,
            locationLongitude: -63.6812,
            locationAddress: "105 Basinview Drive, Bedford, NS",
            regularSchedule: [],
            paymentRate: 30.00,
            notes: "Currently inactive"
        )
        halleClient.dogs = [halle]
        clients.append(halleClient)

        // Jude - M/W schedule
        let judeClient = Client(
            ownerName: "Jude's Owner",
            phone: "902-555-0106",
            email: "jude@email.com",
            address: "106 Papermill Lake Drive, Bedford, NS",
            latitude: 44.7312,
            longitude: -63.6789
        )
        let jude = Dog(
            name: "Jude",
            client: judeClient,
            locationLatitude: 44.7312,
            locationLongitude: -63.6789,
            locationAddress: "106 Papermill Lake Drive, Bedford, NS",
            regularSchedule: [.monday, .wednesday],
            paymentRate: 30.00,
            notes: "Sometimes adds Thursday"
        )
        judeClient.dogs = [jude]
        clients.append(judeClient)

        // Navi - T/F schedule
        let naviClient = Client(
            ownerName: "Navi's Owner",
            phone: "902-555-0107",
            email: "navi@email.com",
            address: "107 Larry Uteck Boulevard, Bedford, NS",
            latitude: 44.7389,
            longitude: -63.6867
        )
        let navi = Dog(
            name: "Navi",
            client: naviClient,
            locationLatitude: 44.7389,
            locationLongitude: -63.6867,
            locationAddress: "107 Larry Uteck Boulevard, Bedford, NS",
            regularSchedule: [.tuesday, .friday],
            paymentRate: 30.00,
            notes: "Very consistent T/F schedule"
        )
        naviClient.dogs = [navi]
        clients.append(naviClient)

        // HIKE 2: Sackville/Beaver Bank Area Dogs

        // Nala - T/Th schedule
        let nalaClient = Client(
            ownerName: "Nala's Owner",
            phone: "902-555-0108",
            email: "nala@email.com",
            address: "201 Sackville Drive, Sackville, NS",
            latitude: 44.7643,
            longitude: -63.6534
        )
        let nala = Dog(
            name: "Nala",
            client: nalaClient,
            locationLatitude: 44.7643,
            locationLongitude: -63.6534,
            locationAddress: "201 Sackville Drive, Sackville, NS",
            regularSchedule: [.tuesday, .thursday],
            paymentRate: 30.00,
            notes: "Sometimes adds Friday"
        )
        nalaClient.dogs = [nala]
        clients.append(nalaClient)

        // Weski - Thu only
        let weskiClient = Client(
            ownerName: "Weski's Owner",
            phone: "902-555-0109",
            email: "weski@email.com",
            address: "202 Beaver Bank Road, Sackville, NS",
            latitude: 44.7689,
            longitude: -63.6478
        )
        let weski = Dog(
            name: "Weski",
            client: weskiClient,
            locationLatitude: 44.7689,
            locationLongitude: -63.6478,
            locationAddress: "202 Beaver Bank Road, Sackville, NS",
            regularSchedule: [.thursday],
            paymentRate: 30.00,
            notes: "Thursday regular"
        )
        weskiClient.dogs = [weski]
        clients.append(weskiClient)

        // Cali - Thu schedule
        let caliClient = Client(
            ownerName: "Cali's Owner",
            phone: "902-555-0110",
            email: "cali@email.com",
            address: "203 First Lake Drive, Sackville, NS",
            latitude: 44.7723,
            longitude: -63.6512
        )
        let cali = Dog(
            name: "Cali",
            client: caliClient,
            locationLatitude: 44.7723,
            locationLongitude: -63.6512,
            locationAddress: "203 First Lake Drive, Sackville, NS",
            regularSchedule: [.thursday],
            paymentRate: 30.00,
            notes: "Occasionally switches to Tuesday"
        )
        caliClient.dogs = [cali]
        clients.append(caliClient)

        // Loki - F only, $25 rate
        let lokiClient = Client(
            ownerName: "Loki's Owner",
            phone: "902-555-0111",
            email: "loki@email.com",
            address: "204 Springfield Lake Road, Sackville, NS",
            latitude: 44.7756,
            longitude: -63.6445
        )
        let loki = Dog(
            name: "Loki",
            client: lokiClient,
            locationLatitude: 44.7756,
            locationLongitude: -63.6445,
            locationAddress: "204 Springfield Lake Road, Sackville, NS",
            regularSchedule: [.friday],
            paymentRate: 25.00,
            notes: "Friday regular, special rate"
        )
        lokiClient.dogs = [loki]
        clients.append(lokiClient)

        // Harris - M/W schedule
        let harrisClient = Client(
            ownerName: "Harris's Owner",
            phone: "902-555-0112",
            email: "harris@email.com",
            address: "205 Cobequid Road, Sackville, NS",
            latitude: 44.7612,
            longitude: -63.6589
        )
        let harris = Dog(
            name: "Harris",
            client: harrisClient,
            locationLatitude: 44.7612,
            locationLongitude: -63.6589,
            locationAddress: "205 Cobequid Road, Sackville, NS",
            regularSchedule: [.monday, .wednesday],
            paymentRate: 30.00,
            notes: "Regular M/W"
        )
        harrisClient.dogs = [harris]
        clients.append(harrisClient)

        // Lily GR - F only
        let lilyGRClient = Client(
            ownerName: "Lily GR's Owner",
            phone: "902-555-0113",
            email: "lilygr@email.com",
            address: "206 Walker Avenue, Sackville, NS",
            latitude: 44.7678,
            longitude: -63.6423
        )
        let lilyGR = Dog(
            name: "Lily GR",
            client: lilyGRClient,
            locationLatitude: 44.7678,
            locationLongitude: -63.6423,
            locationAddress: "206 Walker Avenue, Sackville, NS",
            regularSchedule: [.friday],
            paymentRate: 30.00,
            notes: "Friday regular"
        )
        lilyGRClient.dogs = [lilyGR]
        clients.append(lilyGRClient)

        // Ruthie - F only
        let ruthieClient = Client(
            ownerName: "Ruthie's Owner",
            phone: "902-555-0114",
            email: "ruthie@email.com",
            address: "207 Glendale Drive, Sackville, NS",
            latitude: 44.7734,
            longitude: -63.6501
        )
        let ruthie = Dog(
            name: "Ruthie",
            client: ruthieClient,
            locationLatitude: 44.7734,
            locationLongitude: -63.6501,
            locationAddress: "207 Glendale Drive, Sackville, NS",
            regularSchedule: [.friday],
            paymentRate: 30.00,
            notes: "Friday regular"
        )
        ruthieClient.dogs = [ruthie]
        clients.append(ruthieClient)

        // Luna - F only
        let lunaClient = Client(
            ownerName: "Luna's Owner",
            phone: "902-555-0115",
            email: "luna@email.com",
            address: "208 Sackville Drive, Sackville, NS",
            latitude: 44.7598,
            longitude: -63.6556
        )
        let luna = Dog(
            name: "Luna",
            client: lunaClient,
            locationLatitude: 44.7598,
            locationLongitude: -63.6556,
            locationAddress: "208 Sackville Drive, Sackville, NS",
            regularSchedule: [.friday],
            paymentRate: 30.00,
            notes: "Friday regular"
        )
        lunaClient.dogs = [luna]
        clients.append(lunaClient)

        // Finn GR - T/Th schedule
        let finnGRClient = Client(
            ownerName: "Finn GR's Owner",
            phone: "902-555-0116",
            email: "finngr@email.com",
            address: "209 Beaver Bank Road, Beaver Bank, NS",
            latitude: 44.8023,
            longitude: -63.6123
        )
        let finnGR = Dog(
            name: "Finn GR",
            client: finnGRClient,
            locationLatitude: 44.8023,
            locationLongitude: -63.6123,
            locationAddress: "209 Beaver Bank Road, Beaver Bank, NS",
            regularSchedule: [.tuesday, .thursday],
            paymentRate: 30.00,
            notes: "Very consistent T/Th schedule"
        )
        finnGRClient.dogs = [finnGR]
        clients.append(finnGRClient)

        // Sadie - T/Th schedule
        let sadieClient = Client(
            ownerName: "Sadie's Owner",
            phone: "902-555-0117",
            email: "sadie@email.com",
            address: "210 Windsor Junction Road, Beaver Bank, NS",
            latitude: 44.8156,
            longitude: -63.6089
        )
        let sadie = Dog(
            name: "Sadie",
            client: sadieClient,
            locationLatitude: 44.8156,
            locationLongitude: -63.6089,
            locationAddress: "210 Windsor Junction Road, Beaver Bank, NS",
            regularSchedule: [.tuesday, .thursday],
            paymentRate: 30.00,
            notes: "Very consistent T/Th schedule"
        )
        sadieClient.dogs = [sadie]
        clients.append(sadieClient)

        return clients
    }

    private static func createSamplePayments(for clients: [Client], completedHikes: [CompletedHike]) -> [Payment] {
        var payments: [Payment] = []
        let calendar = Calendar.current
        let allDogs = clients.flatMap { $0.dogs }

        // Create a dictionary to quickly find dogs by ID
        let dogsByName = Dictionary(uniqueKeysWithValues: allDogs.map { ($0.name, $0) })

        // For each completed hike, create payment records for most (but not all) dog attendances
        for hike in completedHikes {
            // Randomly decide if this hike's payments are current (~85% paid)
            let isPaidHike = Double.random(in: 0...1) < 0.85

            for attendance in hike.dogAttendances {
                guard let dog = dogsByName[attendance.dogName] else { continue }

                // Create payment for this specific hike if it's a paid hike
                if isPaidHike {
                    let payment = Payment(
                        dog: dog,
                        date: hike.date,
                        amount: attendance.amountCharged,
                        paid: true,
                        method: "e-transfer",
                        completedHikeId: hike.id
                    )
                    payments.append(payment)
                }
                // Otherwise leave unpaid (the "X" scenario in CSV)
            }
        }

        // Add some additional advance payments (not linked to completed hikes yet)
        let today = calendar.startOfDay(for: Date())

        // Maya - recent e-transfer with note
        if let maya = dogsByName["Maya"] {
            let mayaAdvance = Payment(
                dog: maya,
                date: calendar.date(byAdding: .day, value: -3, to: today)!,
                amount: 60.00,  // 2 hikes advance
                paid: true,
                method: "e-transfer",
                notes: "2 weeks advance payment"
            )
            payments.append(mayaAdvance)
        }

        // Finn - overdue, last payment was 3 weeks ago
        if let finn = dogsByName["Finn"] {
            let finnOld = Payment(
                dog: finn,
                date: calendar.date(byAdding: .day, value: -21, to: today)!,
                amount: 60.00,
                paid: true,
                method: "cash",
                notes: "Payment now overdue"
            )
            payments.append(finnOld)
        }

        // Denver - current, paid last week
        if let denver = dogsByName["Denver"] {
            let denverRecent = Payment(
                dog: denver,
                date: calendar.date(byAdding: .day, value: -7, to: today)!,
                amount: 60.00,
                paid: true,
                method: "e-transfer"
            )
            payments.append(denverRecent)
        }

        // Nala - very current, paid yesterday
        if let nala = dogsByName["Nala"] {
            let nalaRecent = Payment(
                dog: nala,
                date: calendar.date(byAdding: .day, value: -1, to: today)!,
                amount: 60.00,
                paid: true,
                method: "e-transfer",
                notes: "Reliable client"
            )
            payments.append(nalaRecent)
        }

        // Harris - hasn't paid in a while
        if let harris = dogsByName["Harris"] {
            let harrisOld = Payment(
                dog: harris,
                date: calendar.date(byAdding: .day, value: -25, to: today)!,
                amount: 60.00,
                paid: true,
                method: "e-transfer",
                notes: "Need to follow up"
            )
            payments.append(harrisOld)
        }

        return payments
    }

    private static func createScheduleOverrides(for clients: [Client]) -> [ScheduleOverride] {
        var overrides: [ScheduleOverride] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let allDogs = clients.flatMap { $0.dogs }

        // Create a dictionary to quickly find dogs by name
        let dogsByName = Dictionary(uniqueKeysWithValues: allDogs.map { ($0.name, $0) })

        // Maya - away next Wednesday
        if let maya = dogsByName["Maya"], let nextWed = calendar.nextDate(after: today, matching: DateComponents(weekday: 4), matchingPolicy: .nextTime) {
            overrides.append(ScheduleOverride(
                dogId: maya.id,
                date: nextWed,
                type: .isAbsent
            ))
        }

        // Maya - added for next Friday (exception)
        if let maya = dogsByName["Maya"], let nextFri = calendar.nextDate(after: today, matching: DateComponents(weekday: 6), matchingPolicy: .nextTime) {
            overrides.append(ScheduleOverride(
                dogId: maya.id,
                date: nextFri,
                type: .isPresent
            ))
        }

        // Denver - away in 2 weeks
        if let denver = dogsByName["Denver"], let futureDate = calendar.date(byAdding: .day, value: 10, to: today) {
            overrides.append(ScheduleOverride(
                dogId: denver.id,
                date: futureDate,
                type: .isAbsent
            ))
        }

        // Jude - added Thursday next week (exception)
        if let jude = dogsByName["Jude"], let nextThu = calendar.nextDate(after: today, matching: DateComponents(weekday: 5), matchingPolicy: .nextTime) {
            overrides.append(ScheduleOverride(
                dogId: jude.id,
                date: nextThu,
                type: .isPresent
            ))
        }

        // Nala - added Friday in 2 weeks (exception)
        if let nala = dogsByName["Nala"], let futureFri = calendar.date(byAdding: .day, value: 12, to: today) {
            overrides.append(ScheduleOverride(
                dogId: nala.id,
                date: futureFri,
                type: .isPresent
            ))
        }

        // Harris - off for an upcoming week (Monday and Wednesday)
        if let harris = dogsByName["Harris"] {
            if let mon = calendar.date(byAdding: .day, value: 14, to: today) {
                overrides.append(ScheduleOverride(
                    dogId: harris.id,
                    date: mon,
                    type: .isAbsent
                ))
            }
            if let wed = calendar.date(byAdding: .day, value: 16, to: today) {
                overrides.append(ScheduleOverride(
                    dogId: harris.id,
                    date: wed,
                    type: .isAbsent
                ))
            }
        }

        // Finn - schedule change from regular pattern
        if let finn = dogsByName["Finn"], let mon = calendar.nextDate(after: today, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) {
            overrides.append(ScheduleOverride(
                dogId: finn.id,
                date: mon,
                type: .isPresent
            ))
        }

        return overrides
    }

    private static func createCompletedHikes(for clients: [Client], locations: [HikingLocation]) -> [CompletedHike] {
        var completedHikes: [CompletedHike] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get all dogs for easy access
        let allDogs = clients.flatMap { $0.dogs }

        // Separate dogs by region
        let bedfordDogs = allDogs.prefix(7)  // Maya through Navi
        let sackvilleDogs = allDogs.dropFirst(7)  // Nala through Sadie

        // Helper to create sample route coordinates around a center point
        func createSampleRoute(centerLat: Double, centerLon: Double, dogCount: Int) -> ([Double], [Double]) {
            var latitudes: [Double] = []
            var longitudes: [Double] = []

            // Create a simple route with slight variations
            for i in 0..<dogCount {
                let offset = Double(i) * 0.002  // Small offset for each pickup
                latitudes.append(centerLat + offset)
                longitudes.append(centerLon + offset * 0.5)
            }

            return (latitudes, longitudes)
        }

        // Create completed hikes for the past 15 weekdays (3 weeks)
        for daysAgo in 1...21 {
            guard let hikeDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }

            // Skip weekends
            let weekday = calendar.component(.weekday, from: hikeDate)
            if weekday == 1 || weekday == 7 { continue }

            guard let dayOfWeek = hikeDate.dayOfWeek else { continue }

            // Determine which dogs should have been on each hike based on their schedules
            let scheduledBedfordDogs = bedfordDogs.filter { $0.regularSchedule.contains(dayOfWeek) }
            let scheduledSackvilleDogs = sackvilleDogs.filter { $0.regularSchedule.contains(dayOfWeek) }

            // Create Hike 1 (Bedford) if there are dogs
            if !scheduledBedfordDogs.isEmpty {
                let trail = locations.first { $0.region == "Bedford" } ?? locations.first
                let dogs = Array(scheduledBedfordDogs)
                let (lats, lons) = createSampleRoute(
                    centerLat: 44.73,
                    centerLon: -63.68,
                    dogCount: dogs.count
                )

                let hike1 = CompletedHike(
                    date: hikeDate,
                    hikeNumber: 1,
                    routeLatitudes: lats,
                    routeLongitudes: lons,
                    trailLocationId: trail?.id,
                    trailName: trail?.name,
                    totalDistance: Double.random(in: 4000...6000),
                    notes: daysAgo == 1 ? "Beautiful day, great hike!" : nil
                )

                // Create attendance records for each dog
                for (index, dog) in dogs.enumerated() {
                    let attendance = DogAttendance(
                        dogId: dog.id,
                        dogName: dog.name,
                        pickupOrder: index + 1,
                        pickupLatitude: dog.locationLatitude,
                        pickupLongitude: dog.locationLongitude,
                        pickupAddress: dog.locationAddress,
                        amountCharged: dog.paymentRate
                    )
                    attendance.completedHike = hike1
                }

                completedHikes.append(hike1)
            }

            // Create Hike 2 (Sackville/Beaver Bank) if there are dogs
            if !scheduledSackvilleDogs.isEmpty {
                let trail = locations.first { $0.region == "Sackville" || $0.region == "Beaver Bank" } ?? locations.last
                let dogs = Array(scheduledSackvilleDogs)
                let (lats, lons) = createSampleRoute(
                    centerLat: 44.77,
                    centerLon: -63.64,
                    dogCount: dogs.count
                )

                let hike2 = CompletedHike(
                    date: hikeDate,
                    hikeNumber: 2,
                    routeLatitudes: lats,
                    routeLongitudes: lons,
                    trailLocationId: trail?.id,
                    trailName: trail?.name,
                    totalDistance: Double.random(in: 4500...6500),
                    notes: daysAgo == 2 ? "Dogs loved the lake!" : nil
                )

                // Create attendance records for each dog
                for (index, dog) in dogs.enumerated() {
                    let attendance = DogAttendance(
                        dogId: dog.id,
                        dogName: dog.name,
                        pickupOrder: index + 1,
                        pickupLatitude: dog.locationLatitude,
                        pickupLongitude: dog.locationLongitude,
                        pickupAddress: dog.locationAddress,
                        amountCharged: dog.paymentRate
                    )
                    attendance.completedHike = hike2
                }

                completedHikes.append(hike2)
            }
        }

        return completedHikes
    }
}
