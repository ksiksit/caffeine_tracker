//
//  NotificationRepository.swift
//  captest1
//
//  알림 도메인 포트(서버 domain/notification). 서버는 푸시를 보내지 않고 계획만 계산한다.
//

import Foundation

nonisolated protocol NotificationRepository: Sendable {
    func plan(now: Date, timeZone: TimeZone) async throws -> NotificationPlanResponse
}

extension NotificationRepository {
    /// 현재 시각·현재 타임존 기준 알림 계획.
    func plan() async throws -> NotificationPlanResponse {
        try await plan(now: Date(), timeZone: .current)
    }
}
