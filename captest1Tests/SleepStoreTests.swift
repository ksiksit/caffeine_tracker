//
//  SleepStoreTests.swift
//  captest1Tests
//
//  원시 샘플 업로드 조건, 서버 요약 → 표시 모델 매핑, 병렬 로드 결과 순서.
//

import Foundation
import Testing
@testable import captest1

@MainActor
struct SleepStoreTests {

    private var todayKey: String { ServerDateCoding.localDate.string(from: Date()) }

    @Test func loadData_skipsUploadWhenNoSamples() async {
        let source = FakeSleepSampleSource()
        let repo = FakeSleepRepository()
        let store = SleepStore(samples: source, repository: repo)

        await store.loadData()

        #expect(repo.uploads.isEmpty)
        #expect(repo.summaryDates.count == AppConstants.Sleep.recentHistoryDays)
        #expect(store.lastNightSummary == nil)
        #expect(store.recentSummaries.isEmpty)
        #expect(store.hasLoadedData == true)
        #expect(store.errorMessage == nil)
    }

    @Test func loadData_uploadsEachDayWhenSamplesExist() async {
        let source = FakeSleepSampleSource()
        source.samples = [RawSleepSample(clientUuid: "u1", start: Date().addingTimeInterval(-8 * 3600), end: Date().addingTimeInterval(-7 * 3600), hkValue: 3)]
        let repo = FakeSleepRepository()
        let store = SleepStore(samples: source, repository: repo)

        await store.loadData()

        #expect(repo.uploads.count == AppConstants.Sleep.recentHistoryDays)
        #expect(repo.uploads.first?.samples.first?.clientUuid == "u1")
    }

    @Test func loadData_mapsServerSummaryWithoutRecomputing() async {
        let repo = FakeSleepRepository()
        repo.summaryByDate[todayKey] = .fixture(date: todayKey, totalSleepSeconds: 6 * 3600, timeInBedSeconds: 8 * 3600, sleepOnsetLatencySeconds: nil)
        let store = SleepStore(samples: FakeSleepSampleSource(), repository: repo)

        await store.loadData()

        let summary = try? #require(store.lastNightSummary)
        let total: TimeInterval = 6 * 3600
        let inBed: TimeInterval = 8 * 3600
        #expect(summary?.totalSleepDuration == total)
        #expect(summary?.timeInBed == inBed)
        #expect(summary?.sleepEfficiency == 0.75)
        #expect(summary?.sleepOnsetLatency == nil)
        let stages: [SleepStage] = summary?.stageBreakdown.map(\.stage) ?? []
        let durations: [TimeInterval] = summary?.stageBreakdown.map(\.duration) ?? []
        #expect(stages == [.asleepDeep, .asleepREM])
        #expect(durations == [3600, 1800])
        #expect(store.recentSummaries.count == 1)
    }

    @Test func loadData_ordersRecentSummariesTodayFirst() async {
        let repo = FakeSleepRepository()
        let yesterdayKey = ServerDateCoding.localDate.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        repo.summaryByDate[todayKey] = .fixture(date: todayKey, totalSleepSeconds: 7 * 3600)
        repo.summaryByDate[yesterdayKey] = .fixture(date: yesterdayKey, totalSleepSeconds: 5 * 3600)
        let store = SleepStore(samples: FakeSleepSampleSource(), repository: repo)

        await store.loadData()

        let expected: [TimeInterval] = [7 * 3600, 5 * 3600]
        let actual: [TimeInterval] = store.recentSummaries.map(\.totalSleepDuration)
        #expect(actual == expected)
        let lastNight: TimeInterval = 7 * 3600
        #expect(store.lastNightSummary?.totalSleepDuration == lastNight)
    }

    @Test func loadData_sourceFailure_setsErrorMessage() async {
        let source = FakeSleepSampleSource()
        source.error = FakeError()
        let store = SleepStore(samples: source, repository: FakeSleepRepository())

        await store.loadData()

        #expect(store.errorMessage != nil)
        #expect(store.hasLoadedData == false)
    }

    @Test func loadDataIfNeeded_loadsOnlyOnce() async {
        let repo = FakeSleepRepository()
        let store = SleepStore(samples: FakeSleepSampleSource(), repository: repo)

        await store.loadDataIfNeeded()
        await store.loadDataIfNeeded()

        #expect(repo.summaryDates.count == AppConstants.Sleep.recentHistoryDays)
    }
}
