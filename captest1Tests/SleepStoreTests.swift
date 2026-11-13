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

    @Test func reset_clearsAccountDataAndAllowsReload() async {
        let source = FakeSleepSampleSource()
        let repo = FakeSleepRepository()
        let store = SleepStore(samples: source, repository: repo)
        await store.loadData()
        #expect(store.hasLoadedData)
        let firstFetchCount = source.fetchCount

        await store.loadDataIfNeeded()
        #expect(source.fetchCount == firstFetchCount)

        store.reset()
        #expect(!store.hasLoadedData)
        await store.loadDataIfNeeded()
        #expect(source.fetchCount == firstFetchCount * 2)
    }

    @Test func loadDataIfNeeded_reloadsAfterMaxAge() async {
        let source = FakeSleepSampleSource()
        let store = SleepStore(samples: source, repository: FakeSleepRepository())
        await store.loadData()
        let firstFetchCount = source.fetchCount

        await store.loadDataIfNeeded(now: Date().addingTimeInterval(3601))

        #expect(source.fetchCount == firstFetchCount * 2)
        #expect(store.loadRevision == 2)
    }

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

    @Test func loadData_dropsZeroLengthSamplesBeforeUpload() async {
        let source = FakeSleepSampleSource()
        let start = Date().addingTimeInterval(-8 * 3600)
        source.samples = [
            RawSleepSample(clientUuid: "zero", start: start, end: start, hkValue: 0),
            RawSleepSample(clientUuid: "ok", start: start, end: start.addingTimeInterval(3600), hkValue: 3),
        ]
        let repo = FakeSleepRepository()
        let store = SleepStore(samples: source, repository: repo)

        await store.loadData()

        let uploadedUuids: [String] = repo.uploads.first?.samples.map(\.clientUuid) ?? []
        #expect(uploadedUuids == ["ok"])
        #expect(store.errorMessage == nil)
    }

    @Test func loadData_skipsUploadWhenOnlyZeroLengthSamples() async {
        let source = FakeSleepSampleSource()
        let start = Date().addingTimeInterval(-8 * 3600)
        source.samples = [RawSleepSample(clientUuid: "zero", start: start, end: start, hkValue: 0)]
        let repo = FakeSleepRepository()
        let store = SleepStore(samples: source, repository: repo)

        await store.loadData()

        #expect(repo.uploads.isEmpty)
        #expect(repo.summaryDates.count == AppConstants.Sleep.recentHistoryDays)
        #expect(store.hasLoadedData == true)
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

    // MARK: - 오류 문구·재시도 신호

    @Test func loadData_serverUnreachable_showsUserMessage_notInternalErrorName() async {
        // 서버가 꺼졌을 때 "작업을 완료할 수 없습니다.(captest1.APIError 오류 11.)"가 보였다
        let source = FakeSleepSampleSource()
        source.error = APIError.network
        let store = SleepStore(samples: source, repository: FakeSleepRepository())

        await store.loadData()

        let message = try? #require(store.errorMessage)
        #expect(message == "서버에 연결할 수 없어요. 인터넷 연결을 확인하거나 잠시 후 다시 시도해주세요.")
        #expect(message?.contains("APIError") == false)
    }

    @Test func userMessage_nonServerError_keepsSystemDescription() {
        let error = NSError(domain: "HK", code: 1, userInfo: [NSLocalizedDescriptionKey: "건강 데이터에 접근할 수 없습니다"])
        #expect(SleepStore.userMessage(for: error) == "수면 데이터를 불러오지 못했어요: 건강 데이터에 접근할 수 없습니다")
    }

    @Test func loadAttemptRevision_bumpsOnSuccessAndFailure() async {
        let source = FakeSleepSampleSource()
        let store = SleepStore(samples: source, repository: FakeSleepRepository())
        await store.loadData()
        #expect(store.loadAttemptRevision == 1)
        #expect(store.loadRevision == 1)

        source.error = APIError.network
        await store.loadData()
        #expect(store.loadAttemptRevision == 2)
        #expect(store.loadRevision == 1)
    }
}
