//
//  FakeNotificationRepository.swift
//  captest1Tests
//

import Foundation
@testable import captest1

final class FakeNotificationRepository: NotificationRepository, @unchecked Sendable {
    @Locked var planResult: Result<NotificationPlanResponse, Error> = .success(
        NotificationPlanResponse(now: Date(), items: []))
    @Locked private(set) var planCalls = 0

    func plan(now: Date, timeZone: TimeZone) async throws -> NotificationPlanResponse {
        $planCalls.mutate { $0 += 1 }
        return try planResult.get()
    }
}
