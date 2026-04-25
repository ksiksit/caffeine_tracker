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
        static let learnedMean = "learnedHalfLifeMean"
        static let learnedVariance = "learnedHalfLifeVariance"
        static let isLearningEnabled = "isLearningEnabled"
        static let lastLearnedDate = "lastLearnedDate"
    }

    /// Koletzko 2021 모집단 표준편차 (h). prior reset 시 사용.
    static let populationPriorVariance: Double = 1.5 * 1.5

    var halfLife: Double {
        didSet {
            UserDefaults.standard.set(halfLife, forKey: Keys.halfLife)
            // 슬라이더 조작 시 prior 리셋 (학습값을 슬라이더값으로, 분산을 모집단으로)
            learnedHalfLifeMean = halfLife
            learnedHalfLifeVariance = Self.populationPriorVariance
            lastLearnedDate = nil
        }
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

    /// 학습된 사후 평균 (h, base half-life). 학습 OFF 시에는 사용되지 않음.
    var learnedHalfLifeMean: Double {
        didSet { UserDefaults.standard.set(learnedHalfLifeMean, forKey: Keys.learnedMean) }
    }

    /// 학습된 사후 분산 (h²).
    var learnedHalfLifeVariance: Double {
        didSet { UserDefaults.standard.set(learnedHalfLifeVariance, forKey: Keys.learnedVariance) }
    }

    /// 자동 학습 ON/OFF.
    var isLearningEnabled: Bool {
        didSet { UserDefaults.standard.set(isLearningEnabled, forKey: Keys.isLearningEnabled) }
    }

    /// 마지막 학습이 수행된 날짜 (해당 밤의 startOfDay). nil이면 학습 이력 없음.
    var lastLearnedDate: Date? {
        didSet { UserDefaults.standard.set(lastLearnedDate, forKey: Keys.lastLearnedDate) }
    }

    /// 마지막 자동 학습 시도에서 사용자에게 보여줄 수 있는 실패 사유. 앱 재실행 시 초기화.
    var lastLearningSkipReason: LearningSkipReason? = nil

    var condition: CaffeineCondition {
        CaffeineCondition(rawValue: conditionRawValue) ?? .none
    }

    /// 학습 활성화 시 사후 평균, 아니면 슬라이더 값 (둘 다 base, condition 미적용).
    var inferredBaseHalfLife: Double {
        isLearningEnabled ? learnedHalfLifeMean : halfLife
    }

    var effectiveHalfLifeHours: Double {
        effectiveHalfLife(base: inferredBaseHalfLife, condition: condition)
    }

    /// 95% 신뢰구간 반폭 (h). UI 표시용.
    var halfLifeCredibleIntervalHalfWidth: Double {
        1.96 * sqrt(learnedHalfLifeVariance)
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
        self.learnedHalfLifeMean = (defaults.object(forKey: Keys.learnedMean) as? Double)
            ?? AppConstants.Pharmacokinetics.defaultHalfLifeHours
        self.learnedHalfLifeVariance = (defaults.object(forKey: Keys.learnedVariance) as? Double)
            ?? Self.populationPriorVariance
        self.isLearningEnabled = (defaults.object(forKey: Keys.isLearningEnabled) as? Bool) ?? true
        self.lastLearnedDate = defaults.object(forKey: Keys.lastLearnedDate) as? Date
    }
}
