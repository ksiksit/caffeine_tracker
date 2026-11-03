//
//  APIClient+Notification.swift
//  captest1
//

import Foundation

extension APIClient: NotificationRepository {
    func plan(now: Date, timeZone: TimeZone) async throws -> NotificationPlanResponse {
        try await get(
            path: "/api/notifications/plan",
            query: ["now": ServerDateCoding.isoOffset(now), "tz": timeZone.identifier]
        )
    }
}
