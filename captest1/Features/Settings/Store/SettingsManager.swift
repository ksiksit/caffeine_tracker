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
        static let learnedMean = "learnedHalfLifeMean"
        static let learnedVariance = "learnedHalfLifeVariance"
        static let isLearningEnabled = "isLearningEnabled"
        static let lastLearnedDate = "lastLearnedDate"
        static let notifyCutoff = "notifyCutoff"
        static let notifyBedtimeResidual = "notifyBedtimeResidual"
        static let notifyRecordReminder = "notifyRecordReminder"
        static let notifyCafeNearby = "notifyCafeNearby"
    }

    /// Koletzko 2021 모집단 표준편차 (h). prior reset 시 사용.
    static let populationPriorVariance: Double = 1.5 * 1.5

    var halfLife: Double {
        didSet {
            defaults.set(halfLife, forKey: Keys.halfLife)
            // 슬라이더 조작 시 prior 리셋 (학습값을 슬라이더값으로, 분산을 모집단으로)
            learnedHalfLifeMean = halfLife
            learnedHalfLifeVariance = Self.populationPriorVariance
            lastLearnedDate = nil
        }
    }

    var conditionRawValue: Int {
        didSet { defaults.set(conditionRawValue, forKey: Keys.condition) }
    }

    var bedtimeHour: Int {
        didSet { defaults.set(bedtimeHour, forKey: Keys.bedtimeHour) }
    }

    var bedtimeMinute: Int {
        didSet { defaults.set(bedtimeMinute, forKey: Keys.bedtimeMinute) }
    }

    var referenceDoseMg: Int {
        didSet { defaults.set(referenceDoseMg, forKey: Keys.referenceDoseMg) }
    }

    /// 학습된 사후 평균 (h, base half-life). 학습 OFF 시에는 사용되지 않음.
    var learnedHalfLifeMean: Double {
        didSet { defaults.set(learnedHalfLifeMean, forKey: Keys.learnedMean) }
    }

    /// 학습된 사후 분산 (h²).
    var learnedHalfLifeVariance: Double {
        didSet { defaults.set(learnedHalfLifeVariance, forKey: Keys.learnedVariance) }
    }

    /// 자동 학습 ON/OFF.
    var isLearningEnabled: Bool {
        didSet { defaults.set(isLearningEnabled, forKey: Keys.isLearningEnabled) }
    }

    /// 마지막 학습이 수행된 날짜 (해당 밤의 startOfDay). nil이면 학습 이력 없음.
    var lastLearnedDate: Date? {
        didSet { defaults.set(lastLearnedDate, forKey: Keys.lastLearnedDate) }
    }

    /// 알림 종류별 on/off (서버 notifications.*). 꺼진 종류는 서버 알림 계획에서 빠진다.
    var notifyCutoff: Bool {
        didSet { defaults.set(notifyCutoff, forKey: Keys.notifyCutoff) }
    }

    var notifyBedtimeResidual: Bool {
        didSet { defaults.set(notifyBedtimeResidual, forKey: Keys.notifyBedtimeResidual) }
    }

    var notifyRecordReminder: Bool {
        didSet { defaults.set(notifyRecordReminder, forKey: Keys.notifyRecordReminder) }
    }

    /// 카페 근처 알림 on/off (서버 notifications.cafeNearby, 기본 꺼짐). 동 선택·위치 권한은 알림 기능이 따로 관리한다.
    var notifyCafeNearby: Bool {
        didSet { defaults.set(notifyCafeNearby, forKey: Keys.notifyCafeNearby) }
    }

    /// 서버 권위 값을 반영할 때마다 1씩 오른다. 알림 계획처럼 "설정이 바뀌면 다시 받아야 하는" 쪽이 관찰한다.
    private(set) var serverRevision = 0

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

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.halfLife = (defaults.object(forKey: Keys.halfLife) as? Double)
            ?? AppConstants.Pharmacokinetics.defaultHalfLifeHours
        self.conditionRawValue = (defaults.object(forKey: Keys.condition) as? Int)
            ?? CaffeineCondition.none.rawValue
        self.bedtimeHour = (defaults.object(forKey: Keys.bedtimeHour) as? Int) ?? 23
        self.bedtimeMinute = (defaults.object(forKey: Keys.bedtimeMinute) as? Int) ?? 0
        self.referenceDoseMg = (defaults.object(forKey: Keys.referenceDoseMg) as? Int)
            ?? AppConstants.Caffeine.defaultReferenceDoseMg
        self.learnedHalfLifeMean = (defaults.object(forKey: Keys.learnedMean) as? Double)
            ?? AppConstants.Pharmacokinetics.defaultHalfLifeHours
        self.learnedHalfLifeVariance = (defaults.object(forKey: Keys.learnedVariance) as? Double)
            ?? Self.populationPriorVariance
        self.isLearningEnabled = (defaults.object(forKey: Keys.isLearningEnabled) as? Bool) ?? true
        self.lastLearnedDate = defaults.object(forKey: Keys.lastLearnedDate) as? Date
        self.notifyCutoff = (defaults.object(forKey: Keys.notifyCutoff) as? Bool) ?? true
        self.notifyBedtimeResidual = (defaults.object(forKey: Keys.notifyBedtimeResidual) as? Bool) ?? true
        self.notifyRecordReminder = (defaults.object(forKey: Keys.notifyRecordReminder) as? Bool) ?? true
        self.notifyCafeNearby = (defaults.object(forKey: Keys.notifyCafeNearby) as? Bool) ?? false
    }

    /// 로그아웃 시 이전 계정의 설정을 기본값으로 되돌린다. 다음 계정은 서버 값을 받기 전까지 PUT하지 않는다.
    func resetForSignOut() {
        syncTask?.cancel()
        isApplyingServer = true
        defer { isApplyingServer = false }
        halfLife = AppConstants.Pharmacokinetics.defaultHalfLifeHours
        conditionRawValue = CaffeineCondition.none.rawValue
        bedtimeHour = 23
        bedtimeMinute = 0
        referenceDoseMg = AppConstants.Caffeine.defaultReferenceDoseMg
        isLearningEnabled = true
        learnedHalfLifeMean = AppConstants.Pharmacokinetics.defaultHalfLifeHours
        learnedHalfLifeVariance = Self.populationPriorVariance
        lastLearnedDate = nil
        notifyCutoff = true
        notifyBedtimeResidual = true
        notifyRecordReminder = true
        notifyCafeNearby = false
        lastSyncedSnapshot = nil
        syncErrorMessage = nil
    }

    // MARK: - 서버 동기화 (server-authoritative)

    private var repository: (any SettingsRepository)?
    private var syncTask: Task<Void, Never>?
    private var isApplyingServer = false
    private var lastSyncedSnapshot: Snapshot?
    /// 설정 저장 실패 안내. 실패를 숨기면 화면은 새 값, 서버 계산은 옛 값인 채로 남는다.
    var syncErrorMessage: String?

    private struct Snapshot: Equatable {
        let halfLife: Double
        let condition: Int
        let bedtimeHour: Int
        let bedtimeMinute: Int
        let referenceDoseMg: Int
        let isLearningEnabled: Bool
        let notifications: NotificationSettingsDTO
    }

    private var notificationSettings: NotificationSettingsDTO {
        NotificationSettingsDTO(cutoff: notifyCutoff, bedtimeResidual: notifyBedtimeResidual,
                                recordReminder: notifyRecordReminder, cafeNearby: notifyCafeNearby)
    }

    private func currentSnapshot() -> Snapshot {
        Snapshot(halfLife: halfLife, condition: conditionRawValue, bedtimeHour: bedtimeHour,
                 bedtimeMinute: bedtimeMinute, referenceDoseMg: referenceDoseMg,
                 isLearningEnabled: isLearningEnabled, notifications: notificationSettings)
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

    /// 저장 실패 안내에서 다시 시도할 때 호출.
    func retrySync() async {
        await syncToServer()
    }

    private func syncToServer() async {
        guard let repository else { return }
        // PUT은 전체 교체다. 서버 값을 받기 전에 보내면 로컬 값이 서버 설정과 학습 상태를 덮어쓴다.
        guard lastSyncedSnapshot != nil else {
            await loadFromServer()
            syncErrorMessage = "서버 설정을 먼저 불러와야 해서 방금 변경은 저장하지 않았어요. 다시 변경해 주세요."
            return
        }
        let req = UpdateSettingsRequest(
            halfLife: halfLife, condition: conditionRawValue,
            bedtimeHour: bedtimeHour, bedtimeMinute: bedtimeMinute,
            referenceDoseMg: referenceDoseMg, isLearningEnabled: isLearningEnabled,
            notifications: notificationSettings)
        do {
            applyServer(try await repository.updateSettings(req))
            syncErrorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            syncErrorMessage = "설정을 저장하지 못했어요. 연결을 확인하고 다시 시도해주세요."
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
        notifyCutoff = dto.notifications.cutoff
        notifyBedtimeResidual = dto.notifications.bedtimeResidual
        notifyRecordReminder = dto.notifications.recordReminder
        notifyCafeNearby = dto.notifications.cafeNearby
        lastSyncedSnapshot = currentSnapshot()
        serverRevision += 1
    }
}
