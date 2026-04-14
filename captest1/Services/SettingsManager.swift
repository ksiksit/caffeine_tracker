//
//  SettingsManager.swift
//  captest1
//

import Foundation

@Observable
final class SettingsManager {
    private enum Keys {
        static let halfLife = "caffeineHalfLife"
        static let condition = "caffeineCondition"
        static let bedtimeHour = "bedtimeHour"
        static let bedtimeMinute = "bedtimeMinute"
        static let referenceDoseMg = "referenceDoseMg"
        static let hasRequestedHealthKit = "hasRequestedHealthKitAuthorization"
    }

    var halfLife: Double {
        didSet { UserDefaults.standard.set(halfLife, forKey: Keys.halfLife) }
    }

    var conditionRawValue: Int {
        didSet { UserDefaults.standard.set(conditionRawValue, forKey: Keys.condition) }
    }

    var bedtimeHour: Int {
        didSet { UserDefaults.standard.set(bedtimeHour, forKey: Keys.bedtimeHour) }
    }

    var bedtimeMinute: Int {
        didSet { UserDefaults.standard.set(bedtimeMinute, forKey: Keys.bedtimeMinute) }
    }

    var referenceDoseMg: Int {
        didSet { UserDefaults.standard.set(referenceDoseMg, forKey: Keys.referenceDoseMg) }
    }

    var hasRequestedHealthKitAuthorization: Bool {
        didSet { UserDefaults.standard.set(hasRequestedHealthKitAuthorization, forKey: Keys.hasRequestedHealthKit) }
    }

    var condition: CaffeineCondition {
        CaffeineCondition(rawValue: conditionRawValue) ?? .none
    }

    var effectiveHalfLifeHours: Double {
        effectiveHalfLife(base: halfLife, condition: condition)
    }

    init() {
        let defaults = UserDefaults.standard
        self.halfLife = (defaults.object(forKey: Keys.halfLife) as? Double)
            ?? AppConstants.Pharmacokinetics.defaultHalfLifeHours
        self.conditionRawValue = (defaults.object(forKey: Keys.condition) as? Int)
            ?? CaffeineCondition.none.rawValue
        self.bedtimeHour = (defaults.object(forKey: Keys.bedtimeHour) as? Int) ?? 23
        self.bedtimeMinute = (defaults.object(forKey: Keys.bedtimeMinute) as? Int) ?? 0
        self.referenceDoseMg = (defaults.object(forKey: Keys.referenceDoseMg) as? Int)
            ?? AppConstants.Caffeine.defaultReferenceDoseMg
        self.hasRequestedHealthKitAuthorization = defaults.bool(forKey: Keys.hasRequestedHealthKit)
    }
}
