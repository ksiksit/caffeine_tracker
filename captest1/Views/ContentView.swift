//
//  ContentView.swift
//  captest1
//
//  Created by 김종범 on 3/24/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(SettingsManager.self) private var settings
    @Query private var allCaffeineRecords: [CaffeineRecord]
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(String(localized: "tab.home"), systemImage: "cup.and.saucer.fill", value: 0) {
                NavigationStack {
                    HomeView()
                }
            }

            Tab(String(localized: "tab.sleepAnalysis"), systemImage: "moon.zzz.fill", value: 1) {
                NavigationStack {
                    SleepAnalysisView()
                }
            }

            Tab(String(localized: "tab.learning"), systemImage: "brain.head.profile", value: 2) {
                NavigationStack {
                    LearningDashboardView()
                }
            }

            Tab(String(localized: "tab.settings"), systemImage: "gearshape.fill", value: 3) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .task {
            await healthKit.loadDataIfNeeded()
            runLearningIfPossible()
        }
        .onChange(of: healthKit.lastNightSummary?.id) {
            // 권한 부여 후 데이터가 늦게 도착하는 경우 커버
            runLearningIfPossible()
        }
    }

    private func runLearningIfPossible() {
        let learner = BayesianHalfLifeLearner(settings: settings, context: modelContext)
        let summaries = healthKit.recentSummaries.isEmpty
            ? healthKit.lastNightSummary.map { [$0] } ?? []
            : healthKit.recentSummaries
        let result = learner.updateMissingObservations(
            summaries: summaries,
            allCaffeineRecords: allCaffeineRecords
        )
        settings.lastLearningSkipReason = result.displayReason
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CaffeineRecord.self, HalfLifeObservation.self], inMemory: true)
        .environment(SettingsManager())
        .environment(HealthKitManager(settings: SettingsManager()))
}
