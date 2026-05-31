//
//  ServerDomainDTO.swift
//  captest1
//
//  서버 도메인(카페인 기록·today 연산·설정) 요청/응답 DTO.
//  서버(Jackson)와의 JSON 날짜 계약: ISO-8601 + 오프셋. 디코딩은 소수초 유무를 모두 허용한다.
//

import Foundation

// MARK: - JSON 날짜 계약 (ISO-8601 + offset, 소수초 허용)

enum ServerDateCoding {
    /// 전송용: 현재 타임존 오프셋 포함(예: 2026-06-01T14:30:00+09:00).
    static let encoding: JSONEncoder.DateEncodingStrategy = .custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(withFractional.string(from: date))
    }

    /// 수신용: 서버 Instant("...Z")·소수초 유무 모두 허용.
    static let decoding: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let raw = try decoder.singleValueContainer().decode(String.self)
        if let d = withFractional.date(from: raw) ?? withoutFractional.date(from: raw) {
            return d
        }
        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "ISO-8601 날짜 파싱 실패: \(raw)")
        )
    }

    private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone.current
        return f
    }()

    private static let withoutFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone.current
        return f
    }()
}

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

// MARK: - 설정

nonisolated struct SettingsResponse: Decodable, Sendable {
    let halfLife: Double
    let condition: Int
    let bedtimeHour: Int
    let bedtimeMinute: Int
    let referenceDoseMg: Int
    let isLearningEnabled: Bool
    let learnedMean: Double
    let learnedVariance: Double
    let lastLearnedDate: String?   // 서버 LocalDate("2026-05-30"). 표시/시드용이라 문자열로 수신.
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
