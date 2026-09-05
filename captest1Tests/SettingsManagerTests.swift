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

    @Test func effectiveHalfLife_appliesConditionMultiplier() {
        let settings = makeManager()
        settings.isLearningEnabled = false
        settings.halfLife = 4.0
        settings.conditionRawValue = CaffeineCondition.smoker.rawValue
        #expect(settings.effectiveHalfLifeHours == 2.0)
    }
}
