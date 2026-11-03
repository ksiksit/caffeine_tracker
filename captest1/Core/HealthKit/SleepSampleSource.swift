//
//  SleepSampleSource.swift
//  captest1
//
//  HealthKit 원시 수면 샘플 읽기 포트. 구현은 SleepFetchService, 미리보기·테스트는 페이크.
//

import Foundation

nonisolated protocol SleepSampleSource: Sendable {
    /// date 기준 수면 윈도우(전날 18시~당일 12시)의 원시 샘플(병합 전). HK 샘플 uuid를 멱등 키로 쓴다.
    func fetchRawSamples(for date: Date) async throws -> [RawSleepSample]
}

extension SleepFetchService: SleepSampleSource {}
