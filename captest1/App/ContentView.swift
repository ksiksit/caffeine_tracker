//
//  ContentView.swift
//  captest1
//
//  Created by 김종범 on 3/24/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(SleepStore.self) private var sleepStore
    @Environment(SettingsManager.self) private var settings
    @Environment(CaffeineStore.self) private var caffeineStore
    @Environment(NotificationStore.self) private var notifications
    @Environment(\.scenePhase) private var scenePhase
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
                    SettingsView {
                        NotificationPermissionRow()
                    }
                }
            }
        }
        .task {
            // 서버 설정을 로컬 미러로 로드(server-authoritative)
            await settings.loadFromServer()
            // 권한은 Core(HealthKitManager), 데이터는 Feature(SleepStore)
            if await healthKit.refreshAccessState() == .requestCompleted {
                await sleepStore.loadDataIfNeeded()
            }
            // 서버 알림 계획을 로컬 알림으로 예약하려면 권한이 필요하다(처음 한 번만 물어봄).
            await notifications.requestPermissionIfNeeded()
            notifications.scheduleRefresh()
        }
        // 알림 계획 재조회 시점(api.md 알림 절): 기록 변경 후 · 설정 변경 후 · 포그라운드 진입 시.
        // 기록 추가·수정·삭제는 CaffeineStore가 today를 다시 받으므로 today 갱신을 신호로 쓴다.
        // 기능끼리 직접 부르지 않도록 조립층에서만 잇는다(CLAUDE.md 의존 규칙 2).
        .onChange(of: caffeineStore.today?.now) { notifications.scheduleRefresh() }
        .onChange(of: settings.serverRevision) { notifications.scheduleRefresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { notifications.scheduleRefresh() }
        }
        // 로그아웃하면 RootView가 이 화면을 내린다 — 이전 계정 기준 예약을 지운다.
        .onDisappear {
            Task { await notifications.clear() }
        }
    }
}
