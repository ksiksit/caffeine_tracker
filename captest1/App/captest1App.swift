//
//  captest1App.swift
//  captest1
//
//  Created by 김종범 on 3/24/26.
//

import SwiftUI
import SwiftData
import HealthKit

@main
struct captest1App: App {
    @State private var settings: SettingsManager
    @State private var healthKitManager: HealthKitManager
    @State private var auth: AuthManager
    @State private var caffeineStore: CaffeineStore
    @State private var learningStore: LearningStore
    @State private var sleepStore: SleepStore
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
        let client = APIClient(baseURL: AppEnvironment.baseURL, tokenStore: store)
        tokenStore = store
        apiClient = client
        // APIClient 하나를 각 도메인 포트(Repository)와 세션 제어(AuthSession)로 주입한다.
        settings.attach(repository: client)
        _auth = State(wrappedValue: AuthManager(repository: client, session: client, tokenStore: store))
        _caffeineStore = State(wrappedValue: CaffeineStore(repository: client))
        _learningStore = State(wrappedValue: LearningStore(repository: client))
        _sleepStore = State(wrappedValue: SleepStore(samples: SleepFetchService(healthStore: healthStore), repository: client))
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CaffeineRecord.self,
            HalfLifeObservation.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(healthKitManager)
                .environment(settings)
                .environment(auth)
                .environment(caffeineStore)
                .environment(learningStore)
                .environment(sleepStore)
                .task {
                    await tokenStore.bootstrap()
                    await apiClient.setAccessToken(tokenStore.accessToken)
                    await apiClient.setRefreshToken(tokenStore.refreshToken)
                    await auth.bootstrap()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
