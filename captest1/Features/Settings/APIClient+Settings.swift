//
//  APIClient+Settings.swift
//  captest1
//

import Foundation

extension APIClient: SettingsRepository {
    func settings() async throws -> SettingsResponse {
        try await get(path: "/api/settings")
    }

    func updateSettings(_ req: UpdateSettingsRequest) async throws -> SettingsResponse {
        try await put(path: "/api/settings", body: req)
    }
}
