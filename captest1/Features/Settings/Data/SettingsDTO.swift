//
//  SettingsDTO.swift
//  captest1
//
//  사용자 설정(반감기·건강 상태·취침·기준용량·학습 ON/OFF·알림 종류별 ON/OFF) 요청/응답 DTO. 서버가 권위 값이며 앱은 로컬 미러.
//

import Foundation

nonisolated struct SettingsResponse: Decodable, Sendable {
    let halfLife: Double
    let condition: Int
    let bedtimeHour: Int
    let bedtimeMinute: Int
    let referenceDoseMg: Int
    let isLearningEnabled: Bool
    let learnedMean: Double
    let learnedVariance: Double
    let lastLearnedDate: String?   // 서버 LocalDate("2026-05-30"). ServerDateCoding.localDate로 파싱.
    let inferredBaseHalfLife: Double
    let effectiveHalfLifeHours: Double
    let notifications: NotificationSettingsDTO
}

/// 알림 종류별 on/off. 서버 NotificationType 과 1:1이며, 꺼진 종류는 알림 계획에서 생략된다.
/// `cafeNearby`는 시각이 아니라 금지 구간(알림 계획 cafeNearbyWindows)으로 내려오는 카페 근처 알림. 서버 기본 꺼짐.
nonisolated struct NotificationSettingsDTO: Codable, Sendable, Equatable {
    let cutoff: Bool
    let bedtimeResidual: Bool
    let recordReminder: Bool
    /// 요청에는 항상 싣는다(서버는 생략 시 기존 값 유지). 응답에 없으면(카페 근처 알림 이전 서버) 꺼짐으로 본다.
    let cafeNearby: Bool

    init(cutoff: Bool, bedtimeResidual: Bool, recordReminder: Bool, cafeNearby: Bool = false) {
        self.cutoff = cutoff
        self.bedtimeResidual = bedtimeResidual
        self.recordReminder = recordReminder
        self.cafeNearby = cafeNearby
    }

    private enum CodingKeys: String, CodingKey { case cutoff, bedtimeResidual, recordReminder, cafeNearby }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cutoff = try c.decode(Bool.self, forKey: .cutoff)
        bedtimeResidual = try c.decode(Bool.self, forKey: .bedtimeResidual)
        recordReminder = try c.decode(Bool.self, forKey: .recordReminder)
        cafeNearby = try c.decodeIfPresent(Bool.self, forKey: .cafeNearby) ?? false
    }
}

nonisolated struct UpdateSettingsRequest: Encodable, Sendable {
    let halfLife: Double
    let condition: Int
    let bedtimeHour: Int
    let bedtimeMinute: Int
    let referenceDoseMg: Int
    let isLearningEnabled: Bool
    /// 서버 필수 필드(세 값 모두). 빠지면 400.
    let notifications: NotificationSettingsDTO
    var learnedMean: Double? = nil
    var learnedVariance: Double? = nil
    var lastLearnedDate: String? = nil
}
