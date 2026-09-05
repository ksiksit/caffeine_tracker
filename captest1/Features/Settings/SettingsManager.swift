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

    var condition: CaffeineCondition {
        CaffeineCondition(rawValue: conditionRawValue) ?? .none
    }

    /// 학습 활성화 시 사후 평균, 아니면 슬라이더 값 (둘 다 base, condition 미적용).
    var inferredBaseHalfLife: Double {
        isLearningEnabled ? learnedHalfLifeMean : halfLife
    }

    var effectiveHalfLifeHours: Double {
        condition.effectiveHalfLife(base: inferredBaseHalfLife)
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

    /// 로그아웃 등 사용자 전환 시 베이지안 학습 결과를 초기화한다.
    func resetLearnedData() {
        learnedHalfLifeMean = AppConstants.Pharmacokinetics.defaultHalfLifeHours
        learnedHalfLifeVariance = Self.populationPriorVariance
        lastLearnedDate = nil
    }

    // MARK: - 서버 동기화 (server-authoritative)

    private var repository: (any SettingsRepository)?
    private var syncTask: Task<Void, Never>?
    private var isApplyingServer = false
    private var lastSyncedSnapshot: Snapshot?

    private struct Snapshot: Equatable {
        let halfLife: Double
        let condition: Int
        let bedtimeHour: Int
        let bedtimeMinute: Int
        let referenceDoseMg: Int
        let isLearningEnabled: Bool
    }

    private func currentSnapshot() -> Snapshot {
        Snapshot(halfLife: halfLife, condition: conditionRawValue, bedtimeHour: bedtimeHour,
                 bedtimeMinute: bedtimeMinute, referenceDoseMg: referenceDoseMg,
                 isLearningEnabled: isLearningEnabled)
    }

    func attach(repository: any SettingsRepository) {
        self.repository = repository
    }

    /// 로그인 직후 서버 설정을 로컬 미러로 가져온다.
    func loadFromServer() async {
        guard let repository else { return }
        if let dto = try? await repository.settings() {
            applyServer(dto)
        }
    }

    /// 편집 변경 시 호출(디바운스). 서버 PUT 후 권위 값을 다시 적용한다.
    func scheduleSync() {
        guard repository != nil, !isApplyingServer else { return }
        guard currentSnapshot() != lastSyncedSnapshot else { return }
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, !Task.isCancelled else { return }
            await self.syncToServer()
        }
    }

    private func syncToServer() async {
        guard let repository else { return }
        let req = UpdateSettingsRequest(
            halfLife: halfLife, condition: conditionRawValue,
            bedtimeHour: bedtimeHour, bedtimeMinute: bedtimeMinute,
            referenceDoseMg: referenceDoseMg, isLearningEnabled: isLearningEnabled)
        if let dto = try? await repository.updateSettings(req) {
            applyServer(dto)
        }
    }

    /// 서버 권위 값을 로컬에 반영. didSet 의 prior 리셋을 덮어쓰도록 learned* 를 halfLife 뒤에 적용.
    private func applyServer(_ dto: SettingsResponse) {
        isApplyingServer = true
        defer { isApplyingServer = false }
        halfLife = dto.halfLife
        conditionRawValue = dto.condition
        bedtimeHour = dto.bedtimeHour
        bedtimeMinute = dto.bedtimeMinute
        referenceDoseMg = dto.referenceDoseMg
        isLearningEnabled = dto.isLearningEnabled
        learnedHalfLifeMean = dto.learnedMean
        learnedHalfLifeVariance = dto.learnedVariance
        lastLearnedDate = dto.lastLearnedDate.flatMap { ServerDateCoding.localDate.date(from: $0) }
        lastSyncedSnapshot = currentSnapshot()
    }
}
