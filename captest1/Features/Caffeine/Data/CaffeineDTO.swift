//
//  CaffeineDTO.swift
//  captest1
//
//  카페인 기록 CRUD 요청/응답과 오늘 현황(/api/caffeine/today) DTO. 잔류량·차트·마감시각은 서버가 계산한다.
//

import Foundation

// MARK: - 카페인 기록

nonisolated struct CreateCaffeineRecordRequest: Encodable, Sendable {
    let amount: Int
    let drinkName: String
    let timestamp: Date
}

nonisolated struct UpdateCaffeineRecordRequest: Encodable, Sendable {
    let amount: Int
    let drinkName: String
    let timestamp: Date
}

nonisolated struct CaffeineRecordDTO: Decodable, Identifiable, Sendable {
    let id: Int64
    let amount: Int
    let drinkName: String
    let timestamp: Date
}

// MARK: - 오늘 현황(서버 계산)

nonisolated struct CaffeineTodayResponse: Decodable, Sendable {
    let now: Date
    /// 서버 LocalCalendar.nextBedtime: 오늘의 설정 취침시각, 이미 지났으면 내일.
    let bedtime: Date
    let records: [CaffeineRecordDTO]
    let todayTotal: Int
    let overDailyLimit: Bool
    let chart: [ChartPointDTO]
    let currentResidual: Double
    let predictedAtBedtime: Double
    let cutoff: CutoffDTO
    let effectiveHalfLifeHours: Double
    let referenceDoseMg: Int
    /// 오늘 경계(05:00) 이전이지만 서버 잔량 계산에 포함된 최근 24시간 기록. 이 필드를 모르는 이전 서버면 nil.
    var carryoverRecords: [CaffeineRecordDTO]? = nil
}

nonisolated struct ChartPointDTO: Decodable, Sendable {
    let time: Date
    let concentrationMg: Double
}

nonisolated struct CutoffDTO: Decodable, Sendable {
    /// SAFE_ANYTIME | CUTOFF | ALREADY_EXCEEDED
    let status: String
    let cutoff: Date?
    let existingAtBedtime: Double?
}
