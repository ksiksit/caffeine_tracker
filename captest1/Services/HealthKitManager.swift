//
//  HealthKitManager.swift
//  captest1
//

import Foundation
import HealthKit

enum HealthKitAccessState: Equatable {
    case unavailable
    case needsRequest
    case requestCompleted
}

@MainActor
@Observable
final class HealthKitManager {
    var isAvailable: Bool = false
    var accessState: HealthKitAccessState = .needsRequest
    var lastNightSummary: SleepSummary?
    var recentSummaries: [SleepSummary] = []
    var isLoading: Bool = false
    var errorMessage: String?
    private(set) var hasLoadedData: Bool = false

    var canAttemptDataLoad: Bool {
        accessState == .requestCompleted
    }

    private let healthStore: HKHealthStore
    private let fetchService: SleepFetchService
    private let settings: SettingsManager

    init(settings: SettingsManager) {
        let store = HKHealthStore()
        healthStore = store
        fetchService = SleepFetchService(healthStore: store)
        self.settings = settings
        isAvailable = HKHealthStore.isHealthDataAvailable()
        accessState = Self.accessState(
            isAvailable: isAvailable,
            requestStatus: nil,
            hasRequestedBefore: settings.hasRequestedHealthKitAuthorization
        )
    }

    nonisolated static func accessState(
        isAvailable: Bool,
        requestStatus: HKAuthorizationRequestStatus?,
        hasRequestedBefore: Bool
    ) -> HealthKitAccessState {
        guard isAvailable else { return .unavailable }
        guard let requestStatus else {
            return hasRequestedBefore ? .requestCompleted : .needsRequest
        }

        switch requestStatus {
        case .shouldRequest:
            return .needsRequest
        case .unnecessary:
            return .requestCompleted
        case .unknown:
            return hasRequestedBefore ? .requestCompleted : .needsRequest
        @unknown default:
            return hasRequestedBefore ? .requestCompleted : .needsRequest
        }
    }

    @discardableResult
    func refreshAccessState() async -> HealthKitAccessState {
        guard isAvailable else {
            accessState = .unavailable
            return accessState
        }

        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            accessState = Self.accessState(
                isAvailable: isAvailable,
                requestStatus: nil,
                hasRequestedBefore: settings.hasRequestedHealthKitAuthorization
            )
            return accessState
        }

        do {
            let requestStatus = try await requestStatus(for: sleepType)
            accessState = Self.accessState(
                isAvailable: isAvailable,
                requestStatus: requestStatus,
                hasRequestedBefore: settings.hasRequestedHealthKitAuthorization
            )
        } catch {
            accessState = Self.accessState(
                isAvailable: isAvailable,
                requestStatus: nil,
                hasRequestedBefore: settings.hasRequestedHealthKitAuthorization
            )
        }

        return accessState
    }

    func requestAuthorization() async {
        guard isAvailable else {
            accessState = .unavailable
            return
        }

        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            settings.hasRequestedHealthKitAuthorization = true
            await refreshAccessState()
        } catch {
            errorMessage = "HealthKit 권한 요청에 실패했습니다: \(error.localizedDescription)"
            await refreshAccessState()
        }
    }

    func loadDataIfNeeded() async {
        guard !hasLoadedData else { return }
        await loadData()
    }

    func loadData() async {
        let state = await refreshAccessState()
        guard state == .requestCompleted else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let today = Date()
            lastNightSummary = try await fetchService.fetchSleepSummary(for: today)
            recentSummaries = try await fetchService.fetchRecentSummaries(days: AppConstants.Sleep.recentHistoryDays)
            hasLoadedData = true
        } catch {
            errorMessage = "수면 데이터를 불러오는데 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func requestStatus(
        for sleepType: HKObjectType
    ) async throws -> HKAuthorizationRequestStatus {
        try await withCheckedThrowingContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(
                toShare: [],
                read: [sleepType]
            ) { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
}
