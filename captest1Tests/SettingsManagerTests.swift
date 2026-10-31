//
//  SettingsManagerTests.swift
//  captest1Tests
//
//  서버 권위 값 적용과 디바운스 PUT. UserDefaults는 테스트별 suite로 격리한다.
//

import Foundation
import Testing
@testable import captest1

@MainActor
struct SettingsManagerTests {

    private func makeManager() -> SettingsManager {
        let suite = "test.captest1.settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return SettingsManager(defaults: defaults)
    }

    @Test func halfLifeChange_resetsLearnedPrior() {
        let settings = makeManager()
        settings.halfLife = 5.5
        #expect(settings.learnedHalfLifeMean == 5.5)
        #expect(settings.learnedHalfLifeVariance == SettingsManager.populationPriorVariance)
        #expect(settings.lastLearnedDate == nil)
    }

    @Test func loadFromServer_learnedValuesSurviveHalfLifeReset() async {
        let repo = FakeSettingsRepository()
        repo.getResult = .success(.fixture(halfLife: 6.0, learnedMean: 4.2, learnedVariance: 0.8, lastLearnedDate: "2026-06-01"))
        let settings = makeManager()
        settings.attach(repository: repo)

        await settings.loadFromServer()

        #expect(settings.halfLife == 6.0)
        #expect(settings.learnedHalfLifeMean == 4.2)      // halfLife didSet의 prior 리셋이 서버 learned*로 덮여야 함
        #expect(settings.learnedHalfLifeVariance == 0.8)
        #expect(settings.lastLearnedDate == ServerDateCoding.localDate.date(from: "2026-06-01"))
        #expect(repo.updateRequests.isEmpty)               // 서버 값 적용은 PUT을 유발하지 않음
    }

    @Test func scheduleSync_debouncesRapidEditsToOnePut() async throws {
        let repo = FakeSettingsRepository()
        let settings = makeManager()
        settings.attach(repository: repo)
        await settings.loadFromServer()

        settings.referenceDoseMg = 80
        settings.scheduleSync()
        settings.bedtimeHour = 22
        settings.scheduleSync()
        try await Task.sleep(for: .milliseconds(900))

        #expect(repo.updateRequests.count == 1)
        #expect(repo.updateRequests.first?.referenceDoseMg == 80)
        #expect(repo.updateRequests.first?.bedtimeHour == 22)
    }

    @Test func scheduleSync_withoutChanges_doesNotPut() async throws {
        let repo = FakeSettingsRepository()
        let settings = makeManager()
        settings.attach(repository: repo)
        await settings.loadFromServer()

        settings.scheduleSync()
        try await Task.sleep(for: .milliseconds(700))

        #expect(repo.updateRequests.isEmpty)
    }

    @Test func loadFromServer_appliesNotificationTogglesAndBumpsRevision() async {
        let repo = FakeSettingsRepository()
        repo.getResult = .success(.fixture(
            notifications: NotificationSettingsDTO(cutoff: false, bedtimeResidual: true, recordReminder: false)))
        let settings = makeManager()
        settings.attach(repository: repo)
        let before = settings.serverRevision

        await settings.loadFromServer()

        #expect(settings.notifyCutoff == false)
        #expect(settings.notifyBedtimeResidual == true)
        #expect(settings.notifyRecordReminder == false)
        #expect(settings.serverRevision == before + 1)   // 알림 계획 재조회 신호
    }

    @Test func notificationToggle_isSentWithPut() async throws {
        let repo = FakeSettingsRepository()
        let settings = makeManager()
        settings.attach(repository: repo)
        await settings.loadFromServer()

        settings.notifyRecordReminder = false
        settings.scheduleSync()
        try await Task.sleep(for: .milliseconds(900))

        // 서버는 notifications 세 필드를 필수로 받는다 — 빠지면 400.
        #expect(repo.updateRequests.count == 1)
        #expect(repo.updateRequests.first?.notifications
                == NotificationSettingsDTO(cutoff: true, bedtimeResidual: true, recordReminder: false))
        #expect(settings.notifyRecordReminder == false)
    }

    @Test func cafeNearbyToggle_isSentWithPutAndAppliedFromServer() async throws {
        let repo = FakeSettingsRepository()
        let settings = makeManager()
        settings.attach(repository: repo)
        await settings.loadFromServer()
        #expect(settings.notifyCafeNearby == false)   // 서버 기본 꺼짐

        settings.notifyCafeNearby = true
        settings.scheduleSync()
        try await Task.sleep(for: .milliseconds(900))

        #expect(repo.updateRequests.count == 1)
        #expect(repo.updateRequests.first?.notifications.cafeNearby == true)
        #expect(settings.notifyCafeNearby == true)
    }

    @Test func loadFromServer_appliesCafeNearby() async {
        let repo = FakeSettingsRepository()
        repo.getResult = .success(.fixture(notifications: NotificationSettingsDTO(
            cutoff: true, bedtimeResidual: true, recordReminder: true, cafeNearby: true)))
        let settings = makeManager()
        settings.attach(repository: repo)

        await settings.loadFromServer()

        #expect(settings.notifyCafeNearby == true)
    }

    @Test func edit_beforeServerLoad_doesNotOverwriteServer() async throws {
        let repo = FakeSettingsRepository()
        let settings = makeManager()
        settings.attach(repository: repo)

        settings.referenceDoseMg = 80
        settings.scheduleSync()
        try await Task.sleep(for: .milliseconds(700))

        #expect(repo.updateRequests.isEmpty)
        #expect(settings.syncErrorMessage != nil)
    }

    @Test func putFailure_setsErrorAndRetryClearsIt() async throws {
        let repo = FakeSettingsRepository()
        let settings = makeManager()
        settings.attach(repository: repo)
        await settings.loadFromServer()

        repo.updateOverride = .failure(APIError.network)
        settings.referenceDoseMg = 80
        settings.scheduleSync()
        try await Task.sleep(for: .milliseconds(700))
        #expect(settings.syncErrorMessage != nil)

        repo.updateOverride = nil
        await settings.retrySync()
        #expect(settings.syncErrorMessage == nil)
        #expect(repo.updateRequests.last?.referenceDoseMg == 80)
    }

    @Test func resetForSignOut_restoresDefaultsAndBlocksPutUntilLoad() async throws {
        let repo = FakeSettingsRepository()
        repo.getResult = .success(.fixture(halfLife: 6, condition: 3))
        let settings = makeManager()
        settings.attach(repository: repo)
        await settings.loadFromServer()
        #expect(settings.conditionRawValue == 3)

        settings.resetForSignOut()

        #expect(settings.conditionRawValue == CaffeineCondition.none.rawValue)
        #expect(settings.halfLife == AppConstants.Pharmacokinetics.defaultHalfLifeHours)
        settings.bedtimeHour = 22
        settings.scheduleSync()
        try await Task.sleep(for: .milliseconds(700))
        #expect(repo.updateRequests.isEmpty)
    }

    @Test func effectiveHalfLife_appliesConditionMultiplier() {
        let settings = makeManager()
        settings.isLearningEnabled = false
        settings.halfLife = 4.0
        settings.conditionRawValue = CaffeineCondition.smoker.rawValue
        #expect(settings.effectiveHalfLifeHours == 2.0)
    }
}
