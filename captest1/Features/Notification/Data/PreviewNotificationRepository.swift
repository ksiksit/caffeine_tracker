//
//  PreviewNotificationRepository.swift
//  captest1
//
//  #Preview 전용 페이크. 네트워크·시스템 알림 없이 화면만 그린다.
//

import Foundation

nonisolated struct PreviewNotificationRepository: NotificationRepository {
    func plan(now: Date, timeZone: TimeZone) async throws -> NotificationPlanResponse {
        NotificationPlanResponse(now: now, items: [
            NotificationItemDTO(type: "CUTOFF", fireAt: now.addingTimeInterval(3600),
                                title: "섭취 마감 30분 전",
                                body: "23:00 취침 기준, 75mg를 마실 수 있는 마지막 시각은 15:34이에요."),
        ])
    }
}

final class PreviewLocalNotificationScheduler: LocalNotificationScheduling {
    var current: LocalNotificationPermission = .authorized
    func permission() async -> LocalNotificationPermission { current }
    func requestPermission() async -> Bool { current == .authorized }
    func replaceAll(with notifications: [LocalNotification]) async {}
    func removeAll() async {}
    func postNow(_ notification: LocalNotification) async {}
}
