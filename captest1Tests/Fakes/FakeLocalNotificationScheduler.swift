//
//  FakeLocalNotificationScheduler.swift
//  captest1Tests
//
//  시스템 알림 센터 대신 예약 내역만 기록한다.
//

import Foundation
@testable import captest1

@MainActor
final class FakeLocalNotificationScheduler: LocalNotificationScheduling {
    var currentPermission: LocalNotificationPermission = .authorized
    /// 권한 창에서 사용자가 고를 결과. nil이면 창을 띄워도 상태가 안 바뀜.
    var permissionAfterRequest: LocalNotificationPermission? = .authorized
    private(set) var requestCount = 0
    /// 현재 예약된 알림(교체·삭제 결과).
    private(set) var pending: [LocalNotification] = []
    private(set) var replaceCount = 0
    /// 즉시 띄운 알림(카페 근처).
    private(set) var posted: [LocalNotification] = []

    func permission() async -> LocalNotificationPermission { currentPermission }

    func requestPermission() async -> Bool {
        requestCount += 1
        if let permissionAfterRequest { currentPermission = permissionAfterRequest }
        return currentPermission == .authorized
    }

    func replaceAll(with notifications: [LocalNotification]) async {
        replaceCount += 1
        pending = notifications
    }

    func removeAll() async {
        pending = []
    }

    func postNow(_ notification: LocalNotification) async {
        posted.append(notification)
    }
}
