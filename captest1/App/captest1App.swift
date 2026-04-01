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
    @State private var healthKitManager = HealthKitManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CaffeineRecord.self,
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
        }
        .modelContainer(sharedModelContainer)
    }
}
