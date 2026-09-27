//
//  LocalNotificationScheduler.swift
//  captest1
//
//  로컬 알림 예약 래퍼(UserNotifications). 서버는 푸시를 보내지 않고 알림 계획만 계산하므로, 실제 예약은 기기가 한다.
//  Core는 Features를 모르므로 서버 DTO 대신 이 파일의 `LocalNotification` 값만 받는다.
//

import Foundation
import UserNotifications

/// 예약할 로컬 알림 한 건.
nonisolated struct LocalNotification: Equatable, Sendable {
    let id: String
    let fireAt: Date
    let title: String
    let body: String
}

/// 알림 권한 상태. 임시·일시 허용은 예약이 가능하므로 허용으로 본다.
nonisolated enum LocalNotificationPermission: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

/// 로컬 알림 포트. 테스트는 페이크로 바꿔 끼운다.
protocol LocalNotificationScheduling: AnyObject {
    func permission() async -> LocalNotificationPermission
    /// 시스템 권한 창을 띄운다. 이미 정해진 상태면 창 없이 현재 결과만 돌려준다.
    func requestPermission() async -> Bool
    /// 이 예약기로 넣은 알림을 모두 지우고 목록대로 다시 예약한다.
    func replaceAll(with notifications: [LocalNotification]) async
    /// 이 예약기로 넣은 알림만 지운다(다른 경로의 알림은 건드리지 않는다).
    func removeAll() async
}

final class LocalNotificationScheduler: LocalNotificationScheduling {
    /// 서버 알림 계획으로 넣은 알림의 식별자 접두어. 나중에 생길 다른 알림(카페 근처 알림 등)과 섞이지 않게 한다.
    static let identifierPrefix = "plan."

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func permission() async -> LocalNotificationPermission {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        @unknown default: return .denied
        }
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func replaceAll(with notifications: [LocalNotification]) async {
        await removeAll()
        for item in notifications {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            // 시각 기준 트리거 — 시간 간격 트리거와 달리 기기 시계가 바뀌어도 그 시각에 울린다.
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: item.fireAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.identifierPrefix + item.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func removeAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
