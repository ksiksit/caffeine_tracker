//
//  captest1App.swift
//  captest1
//
//  Created by 김종범 on 3/24/26.
//

import SwiftUI
import SwiftData

@main
struct captest1App: App {
    @State private var settings: SettingsManager
    @State private var healthKitManager: HealthKitManager
    @State private var auth: AuthManager
    @State private var caffeineStore: CaffeineStore
    private let tokenStore: TokenStore
    private let apiClient: APIClient

    init() {
        let settings = SettingsManager()
        let healthKit = HealthKitManager(settings: settings)
        _settings = State(wrappedValue: settings)
        _healthKitManager = State(wrappedValue: healthKit)

        let keychain = KeychainHelper(service: "app1.captest1.auth")
        let store = TokenStore(keychain: keychain)
        let client = APIClient(baseURL: AppEnvironment.baseURL, tokenStore: store)
        tokenStore = store
        apiClient = client
        settings.attach(api: client)
        healthKit.attach(api: client)
        _auth = State(wrappedValue: AuthManager(api: client, tokenStore: store))
        _caffeineStore = State(wrappedValue: CaffeineStore(api: client))
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
