//
//  SleepFetchService.swift
//  captest1
//

import Foundation
import HealthKit

nonisolated struct RawSleepSample: Sendable {
    let clientUuid: String
    let start: Date
    let end: Date
    let hkValue: Int
}

struct SleepFetchService {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    /// 서버 업로드용 원시 샘플(병합 전). HK 샘플 uuid를 멱등 키로 사용.
    func fetchRawSamples(for date: Date) async throws -> [RawSleepSample] {
        let samples = try await fetchSleepSamples(for: date)
        return samples.map {
            RawSleepSample(
                clientUuid: $0.uuid.uuidString,
                start: $0.startDate,
                end: $0.endDate,
                hkValue: $0.value
            )
        }
    }

    // MARK: - Private

    private func fetchSleepSamples(for date: Date) async throws -> [HKCategorySample] {
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
        else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfWindow,
            end: endOfWindow,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
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
    }
}
