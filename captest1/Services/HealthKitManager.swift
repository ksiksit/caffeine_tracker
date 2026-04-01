//
//  HealthKitManager.swift
//  captest1
//

import Foundation
import HealthKit

extension HKCategorySample: SleepSampleProtocol {
    public var sleepValue: Int { value }
}

@Observable
class HealthKitManager {
    var isAvailable: Bool = false
    var hasRequestedAuthorization: Bool = UserDefaults.standard.bool(forKey: "hasRequestedHealthKitAuthorization") {
        didSet {
            UserDefaults.standard.set(hasRequestedAuthorization, forKey: "hasRequestedHealthKitAuthorization")
        }
    }
    var lastNightSummary: SleepSummary?
    var recentSummaries: [SleepSummary] = []
    var isLoading: Bool = false
    var errorMessage: String?
    private(set) var hasLoadedData: Bool = false

    private let healthStore = HKHealthStore()

    init() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isAvailable else { return }

        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            hasRequestedAuthorization = true
        } catch {
            errorMessage = "HealthKit 권한 요청에 실패했습니다: \(error.localizedDescription)"
        }
    }

    func loadDataIfNeeded() async {
        guard !hasLoadedData else { return }
        await loadData()
    }

    func loadData() async {
        guard isAvailable, hasRequestedAuthorization else { return }

        isLoading = true
        errorMessage = nil

        do {
            let today = Date()
            lastNightSummary = try await fetchSleepData(for: today)
            recentSummaries = try await fetchRecentSleepData(days: AppConstants.Sleep.recentHistoryDays)
            hasLoadedData = true
        } catch {
            errorMessage = "수면 데이터를 불러오는데 실패했습니다: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func fetchSleepData(for date: Date) async throws -> SleepSummary? {
        let calendar = Calendar.current

        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: date),
              let startOfWindow = calendar.date(
                  bySettingHour: AppConstants.Sleep.windowStartHour,
                  minute: 0, second: 0, of: previousDay
              ),
              let endOfWindow = calendar.date(
                  bySettingHour: AppConstants.Sleep.windowEndHour,
                  minute: 0, second: 0, of: date
              ),
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        else { return nil }

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfWindow,
            end: endOfWindow,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }

        guard !samples.isEmpty else { return nil }

        let records = SleepDataProcessor.mergeSamples(samples).map { interval in
            SleepRecord(
                startDate: interval.start,
                endDate: interval.end,
                stage: SleepStage(from: interval.sleepValue)
            )
        }

        return SleepSummary(date: date, records: records)
    }

    private func fetchRecentSleepData(days: Int) async throws -> [SleepSummary] {
        let calendar = Calendar.current
        var summaries: [SleepSummary] = []

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            if let summary = try await fetchSleepData(for: date) {
                summaries.append(summary)
            }
        }

        return summaries
    }
}
