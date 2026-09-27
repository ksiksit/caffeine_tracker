//
//  NotificationDTO.swift
//  captest1
//
//  로컬 알림 계획(/api/notifications/plan) 응답 DTO. 무엇을 언제 어떤 문구로 울릴지는 서버가 정한다.
//

import Foundation

nonisolated struct NotificationPlanResponse: Decodable, Sendable {
    /// 요청 now(UTC).
    let now: Date
    /// now 이후에 울릴 항목만, fireAt 오름차순. 설정에서 꺼진 종류는 빠져 있다.
    let items: [NotificationItemDTO]
}

nonisolated struct NotificationItemDTO: Decodable, Sendable, Equatable {
    /// CUTOFF · BEDTIME_RESIDUAL · RECORD_REMINDER
    let type: String
    let fireAt: Date
    let title: String
    let body: String
}
