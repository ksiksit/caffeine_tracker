//
//  SettingsDTO.swift
//  captest1
//
//  사용자 설정(반감기·건강 상태·취침·기준용량·학습 ON/OFF) 요청/응답 DTO. 서버가 권위 값이며 앱은 로컬 미러.
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
}

nonisolated struct UpdateSettingsRequest: Encodable, Sendable {
    let halfLife: Double
    let condition: Int
    let bedtimeHour: Int
    let bedtimeMinute: Int
    let referenceDoseMg: Int
    let isLearningEnabled: Bool
    var learnedMean: Double? = nil
    var learnedVariance: Double? = nil
    var lastLearnedDate: String? = nil
}
