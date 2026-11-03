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
    /// 카페 근처 알림 금지 구간. 설정에서 꺼져 있으면 빈 배열. 오늘 구간, 기록 없는 다음 날의 기본 구간 순.
    let cafeNearbyWindows: [CafeNearbyWindowDTO]

    init(now: Date, items: [NotificationItemDTO], cafeNearbyWindows: [CafeNearbyWindowDTO] = []) {
        self.now = now
        self.items = items
        self.cafeNearbyWindows = cafeNearbyWindows
    }

    private enum CodingKeys: String, CodingKey { case now, items, cafeNearbyWindows }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        now = try c.decode(Date.self, forKey: .now)
        items = try c.decode([NotificationItemDTO].self, forKey: .items)
        // 카페 근처 알림 이전 서버는 이 필드가 없다 — 배포 순서와 무관하게 디코딩되도록 없으면 빈 배열.
        cafeNearbyWindows = try c.decodeIfPresent([CafeNearbyWindowDTO].self, forKey: .cafeNearbyWindows) ?? []
    }
}

nonisolated struct NotificationItemDTO: Decodable, Sendable, Equatable {
    /// CUTOFF · BEDTIME_RESIDUAL · RECORD_REMINDER
    let type: String
    let fireAt: Date
    let title: String
    let body: String
}

/// "이 구간에 카페 구역에 들어서면 울려라". 서버는 언제만 알고 어디는 모른다 — 판정은 앱이 진입 순간 기기에서 한다.
/// 앱이 꺼져 있다가 위치 이벤트로 깨어나도 판정할 수 있게 기기에 저장해 두므로 Encodable도 채택한다.
nonisolated struct CafeNearbyWindowDTO: Codable, Sendable, Equatable {
    /// ALREADY_EXCEEDED · DAILY_LIMIT_EXCEEDED · CUTOFF_PASSED
    let reason: String
    /// 구간 시작(포함). 과거일 수 있다.
    let activeFrom: Date
    /// 구간 끝(미포함). 그날 하루 경계(다음 05:00).
    let activeUntil: Date
    let title: String
    let body: String
}
