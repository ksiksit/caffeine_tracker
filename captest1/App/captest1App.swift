//
//  captest1App.swift
//  captest1
//
//  Created by 김종범 on 3/24/26.
//

import SwiftUI
import HealthKit

@main
struct captest1App: App {
    // 위치 이벤트로 백그라운드에서 다시 실행될 때 화면 없이 카페 근처 알림을 판정하려고 앱 델리게이트를 둔다.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings: SettingsManager
    @State private var healthKitManager: HealthKitManager
    @State private var auth: AuthManager
    @State private var caffeineStore: CaffeineStore
    @State private var learningStore: LearningStore
    @State private var sleepStore: SleepStore
    @State private var notificationStore: NotificationStore
    @State private var locationPermission = LocationPermissionManager()
    private let tokenStore: TokenStore
    private let apiClient: APIClient

    init() {
        let settings = SettingsManager()
        let healthStore = HKHealthStore()
        let healthKit = HealthKitManager(healthStore: healthStore)
        _settings = State(wrappedValue: settings)
        _healthKitManager = State(wrappedValue: healthKit)

        let keychain = KeychainHelper(service: "app1.captest1.auth")
        let store = TokenStore(keychain: keychain)
        // 기본 URLSession은 응답이 없으면 60초를 기다려 시작 화면('로그인 정보 확인 중')이 그만큼 멈춘다 — 10초로 줄인다.
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        let client = APIClient(baseURL: AppEnvironment.baseURL, tokenStore: store,
                               session: URLSession(configuration: configuration))
        tokenStore = store
        apiClient = client

        // APIClient 하나를 각 도메인 포트(Repository)와 세션 제어(AuthSession)로 주입한다.
        settings.attach(repository: client)
        _auth = State(wrappedValue: AuthManager(repository: client, session: client, tokenStore: store,
                                                   accountStore: AuthAccountStore(keychain: keychain)))
        _caffeineStore = State(wrappedValue: CaffeineStore(repository: client, cache: CaffeineTodayCache()))
        _learningStore = State(wrappedValue: LearningStore(repository: client))
        _sleepStore = State(wrappedValue: SleepStore(samples: SleepFetchService(healthStore: healthStore), repository: client))
        _notificationStore = State(wrappedValue: NotificationStore(repository: client, scheduler: LocalNotificationScheduler()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(healthKitManager)
                .environment(settings)
                .environment(auth)
                .environment(caffeineStore)
                .environment(learningStore)
                .environment(sleepStore)
                .environment(notificationStore)
                .environment(appDelegate.cafeNearby)
                .environment(locationPermission)
                .task {
                    await tokenStore.bootstrap()
                    await apiClient.setAccessToken(tokenStore.accessToken)
                    await apiClient.setRefreshToken(tokenStore.refreshToken)
                    await auth.bootstrap()
                }
        }
    }
}
