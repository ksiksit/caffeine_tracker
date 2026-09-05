//
//  SettingsRepository.swift
//  captest1
//
//  설정 도메인 포트(서버 domain/settings). 서버가 권위 값이며 SettingsManager는 로컬 미러.
//

import Foundation

nonisolated protocol SettingsRepository: Sendable {
    func settings() async throws -> SettingsResponse
    func updateSettings(_ req: UpdateSettingsRequest) async throws -> SettingsResponse
}
