//
//  HealthKitManager.swift
//  captest1
//
//  HealthKit 가용성·권한 상태만 담당한다(Core). 수면 데이터 업로드·요약은 Features/Sleep의 수면 스토어.
//  HealthKit은 읽기 권한 허용 여부를 알려주지 않으므로 "요청한 적 있음" 플래그로 상태를 추정한다.
//

import Foundation
import HealthKit

nonisolated enum HealthKitAccessState: Equatable {
    case unavailable
    case needsRequest
    case requestCompleted
}

@MainActor
@Observable
final class HealthKitManager {
    var isAvailable: Bool = false
    var accessState: HealthKitAccessState = .needsRequest
    var errorMessage: String?

    var canAttemptDataLoad: Bool {
        accessState == .requestCompleted
    }

    /// 권한 요청을 한 번이라도 했는지. 설정 스토어에서 이전했으며 UserDefaults 키는 그대로라 기존 사용자 상태가 보존된다.
    private(set) var hasRequestedAuthorization: Bool {
        didSet { defaults.set(hasRequestedAuthorization, forKey: Self.hasRequestedKey) }
    }

    private static let hasRequestedKey = "hasRequestedHealthKitAuthorization"
    private let healthStore: HKHealthStore
    private let defaults: UserDefaults

    init(healthStore: HKHealthStore = HKHealthStore(), defaults: UserDefaults = .standard) {
        self.healthStore = healthStore
        self.defaults = defaults
        hasRequestedAuthorization = defaults.bool(forKey: Self.hasRequestedKey)
        isAvailable = HKHealthStore.isHealthDataAvailable()
        accessState = Self.accessState(
            isAvailable: isAvailable,
            requestStatus: nil,
            hasRequestedBefore: hasRequestedAuthorization
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
                hasRequestedBefore: hasRequestedAuthorization
            )
            return accessState
        }

        // 상태 조회 실패는 "모름"으로 두고 플래그로 추정한다.
        let requestStatus = try? await requestStatus(for: sleepType)
        accessState = Self.accessState(
            isAvailable: isAvailable,
            requestStatus: requestStatus,
            hasRequestedBefore: hasRequestedAuthorization
        )
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
            hasRequestedAuthorization = true
        } catch {
            errorMessage = "HealthKit 권한 요청에 실패했습니다: \(error.localizedDescription)"
        }
        await refreshAccessState()
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
