//
//  Payment.swift
//  Hiker
//
//  Created by Claude on 11/7/25.
//

import Foundation
import SwiftData

@Model
final class Payment {
    @Attribute(.unique) var id: UUID
    var dog: Dog?
    var date: Date
    var amount: Decimal
    var paid: Bool
    var method: String?  // "e-transfer", "cash", etc.
    var notes: String?

    init(
        id: UUID = UUID(),
        dog: Dog? = nil,
        date: Date = Date(),
        amount: Decimal,
        paid: Bool = true,
        method: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.dog = dog
        self.date = date
        self.amount = amount
        self.paid = paid
        self.method = method
        self.notes = notes
    }
}
