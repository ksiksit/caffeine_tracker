//
//  SleepRepository.swift
//  captest1
//
//  수면 도메인 포트(서버 domain/sleep). 원시 샘플을 올리고, 병합·SOL·요약은 서버가 계산한 것을 받는다.
//

import Foundation

nonisolated protocol SleepRepository: Sendable {
    func uploadSamples(_ req: UploadSleepSamplesRequest) async throws -> UploadSleepSamplesResponse
    /// date: "yyyy-MM-dd"(로컬 아침 기준). 서버가 전날 18시~당일 12시 윈도우를 병합·계산.
    func summary(date: String, timeZone: TimeZone) async throws -> SleepSummaryResponse
}
