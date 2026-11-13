//
//  ContentView.swift
//  captest1
//
//  Created by 김종범 on 3/24/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(SleepStore.self) private var sleepStore
    @Environment(SettingsManager.self) private var settings
    @Environment(CaffeineStore.self) private var caffeineStore
    @Environment(LearningStore.self) private var learningStore
    @Environment(InsightStore.self) private var insightStore
    @Environment(NotificationStore.self) private var notifications
    @Environment(CafeNearbyStore.self) private var cafeNearby
    @Environment(LocationPermissionManager.self) private var location
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
                    SleepAnalysisView { lastNight in
                        LastNightCaffeineRow(date: lastNight)
                    } nightlyCaffeine: {
                        NightlyCaffeineCard()
                    }
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
                    } cafeNearbyDetail: {
                        CafeNearbyRows()
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
            // 카페 근처 알림 on/off는 서버 설정이 권위 — 로드한 값으로 감시 구역을 맞춘다.
            await cafeNearby.setEnabled(settings.notifyCafeNearby)
        }
        // 알림 계획 재조회 시점(api.md 알림 절): 기록 변경 후 · 설정 변경 후 · 포그라운드 진입 시.
        // 기록 추가·수정·삭제는 CaffeineStore가 today를 다시 받으므로 today 갱신을 신호로 쓴다.
        // 기능끼리 직접 부르지 않도록 조립층에서만 잇는다(CLAUDE.md 의존 규칙 2).
        .onChange(of: caffeineStore.today?.now) {
            notifications.scheduleRefresh()
            // 기록이 바뀌면 밤별 취침 잔량도 바뀐다 — 다음 수면 탭 진입 때 다시 받는다.
            insightStore.invalidate()
        }
        // 설정이 서버에 반영되면 홈의 마감·잔량도 그 설정으로 다시 계산해야 한다.
        .onChange(of: settings.serverRevision) {
            notifications.scheduleRefresh()
            Task { await caffeineStore.refresh() }
        }
        // 수면이 새로 올라가면 학습하고, 학습이 설정을 바꾸면 미러를 다시 받는다.
        // 수면이 새로 올라가면 밤별 카페인 리포트도 그 수면으로 다시 받는다(서버가 업로드된 샘플로 계산).
        .onChange(of: sleepStore.loadRevision) {
            Task { await learningStore.refresh() }
            Task { await insightStore.refresh() }
        }
        .onChange(of: learningStore.learnedRevision) {
            Task { await settings.loadFromServer() }
        }
        // 카페 근처 알림: 토글이 바뀌면 감시 구역을 맞추고, 켤 때는 위치 권한의 다음 단계를 묻는다.
        .onChange(of: settings.notifyCafeNearby) { _, enabled in
            if enabled { location.requestNextStep() }
            Task { await cafeNearby.setEnabled(enabled) }
        }
        // 새 알림 계획의 금지 구간을 기기에 저장한다(앱이 꺼져 있어도 진입 순간 판정할 수 있게). 빈 목록도 저장.
        .onChange(of: notifications.planRevision) { cafeNearby.saveWindows(notifications.cafeNearbyWindows) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            notifications.scheduleRefresh()
            // 앱을 띄워 둔 채 날이 바뀌어도 어제 값이 남지 않게 다시 받는다.
            Task {
                await caffeineStore.refresh()
                if healthKit.canAttemptDataLoad {
                    await sleepStore.loadDataIfNeeded()
                }
            }
        }
        // 로그아웃·세션 만료면 RootView가 이 화면을 내린다 — 이전 계정의 값과 예약을 지운다.
        // iPad에서 창 하나만 닫아도 불리지만 Store는 창끼리 공유하므로, 로그인 상태면 지우지 않는다.
        .onDisappear {
            if case .authenticated = auth.state { return }
            caffeineStore.reset()
            sleepStore.reset()
            learningStore.reset()
            insightStore.reset()
            settings.resetForSignOut()
            Task {
                await notifications.clear()
                await cafeNearby.clear()
            }
        }
    }
}
