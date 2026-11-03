//
//  AppDelegate.swift
//  captest1
//
//  앱 실행마다(위치 이벤트로 백그라운드에서 다시 실행될 때 포함) 화면이 만들어지기 전에 할 일:
//  - 알림 센터 델리게이트 설정(앱이 앞에 있을 때도 배너 표시)
//  - 카페 근처 알림 감시 재개. 백그라운드 재실행 때는 화면이 만들어지지 않을 수 있어 여기서 한다(spikes/GeofenceSpike에서 검증한 경로).
//  조립은 captest1App.init 한 곳이 원칙이지만(CLAUDE.md 의존 규칙 4), 카페 근처 알림 스토어만은 이 이유로 여기서 만들고
//  captest1App이 environment로 넘긴다.
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    let cafeNearby = CafeNearbyStore(
        catalog: BundledCafeZoneCatalog(),
        monitor: GeofenceMonitor(),
        scheduler: LocalNotificationScheduler(),
        localStore: CafeNearbyLocalStore())
    private let notificationPresenter = LocalNotificationPresenter()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationPresenter
        cafeNearby.start()
        return true
    }
}
