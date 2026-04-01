//
//  CaffeineRecord.swift
//  captest1
//

import Foundation
import SwiftData

@Model
final class CaffeineRecord {
    var amount: Int
    var drinkName: String
    var timestamp: Date

    init(amount: Int, drinkName: String, timestamp: Date = .now) {
        self.amount = amount
        self.drinkName = drinkName
        self.timestamp = timestamp
    }
}
