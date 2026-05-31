//
//  ContentView.swift
//  captest1
//
//  Created by 김종범 on 3/24/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(SettingsManager.self) private var settings
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
            // 서버 설정을 로컬 미러로 로드(server-authoritative)
            await settings.loadFromServer()
            await healthKit.loadDataIfNeeded()
            // 베이지안 학습은 단계 3에서 서버(sleep·learning 도메인)로 이관 — 현재 클라 로컬 학습 비활성.
        }
    }
}
