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

    init() {
        let settings = SettingsManager()
        _settings = State(wrappedValue: settings)
        _healthKitManager = State(wrappedValue: HealthKitManager(settings: settings))
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
            ContentView()
                .environment(healthKitManager)
                .environment(settings)
        }
        .modelContainer(sharedModelContainer)
    }
}
