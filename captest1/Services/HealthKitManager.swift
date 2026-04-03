//
//  HealthKitManager.swift
//  captest1
//

import Foundation
import HealthKit

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

    private let healthStore: HKHealthStore
    private let fetchService: SleepFetchService

    init() {
        let store = HKHealthStore()
        healthStore = store
        fetchService = SleepFetchService(healthStore: store)
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
            lastNightSummary = try await fetchService.fetchSleepSummary(for: today)
            recentSummaries = try await fetchService.fetchRecentSummaries(days: AppConstants.Sleep.recentHistoryDays)
            hasLoadedData = true
        } catch {
            errorMessage = "수면 데이터를 불러오는데 실패했습니다: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
