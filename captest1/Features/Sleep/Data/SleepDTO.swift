//
//  SleepDTO.swift
//  captest1
//
//  수면 원시 샘플 업로드 / 서버 요약 DTO. 병합·SOL 계산은 서버가 수행한다.
//

import Foundation

// MARK: - 업로드

nonisolated struct UploadSleepSampleItem: Encodable, Sendable {
    let clientUuid: String
    let start: Date
    let end: Date
    let hkValue: Int
}

nonisolated struct UploadSleepSamplesRequest: Encodable, Sendable {
    let samples: [UploadSleepSampleItem]
}

nonisolated struct UploadSleepSamplesResponse: Decodable, Sendable {
    let received: Int
    let inserted: Int
}

// MARK: - 서버 요약

nonisolated struct SleepSummaryResponse: Decodable, Sendable {
    let date: String?          // 서버 LocalDate "2026-06-01"
    let hasData: Bool
    let bedtimeStart: Date?
    let records: [SleepRecordItem]
    let totalSleepSeconds: Double
    let timeInBedSeconds: Double
    let sleepEfficiency: Double
    let sleepOnsetLatencySeconds: Double?
    let stageBreakdown: [SleepStageItem]
}

nonisolated struct SleepRecordItem: Decodable, Sendable {
    let start: Date
    let end: Date
    let hkValue: Int
}

nonisolated struct SleepStageItem: Decodable, Sendable {
    let hkValue: Int
    let durationSeconds: Double
}
