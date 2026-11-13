//
//  SleepAnalysisView.swift
//  captest1
//

import SwiftUI

/// 카페인과 함께 보는 줄(지난밤 잔량·밤별 카페인)은 다른 기능(Insight)이라 슬롯으로 받는다. 조립은 ContentView.
struct SleepAnalysisView<LastNightCaffeine: View, NightlyCaffeine: View>: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(SleepStore.self) private var store
    @State private var showingError: Bool = false

    /// 지난밤 카드 아래. 인자는 지난밤 카드의 날짜(밤이 끝나는 아침)
    private let lastNightCaffeine: (Date) -> LastNightCaffeine
    /// 최근 7일 카드 위
    private let nightlyCaffeine: () -> NightlyCaffeine

    init(@ViewBuilder lastNightCaffeine: @escaping (Date) -> LastNightCaffeine,
         @ViewBuilder nightlyCaffeine: @escaping () -> NightlyCaffeine) {
        self.lastNightCaffeine = lastNightCaffeine
        self.nightlyCaffeine = nightlyCaffeine
    }

    var body: some View {
        Group {
            if healthKit.accessState == .unavailable {
                unavailableView
            } else if healthKit.accessState == .needsRequest {
                authorizationView
            } else if store.isLoading {
                ProgressView("수면 데이터를 불러오는 중...")
            } else if let summary = store.lastNightSummary {
                sleepDataView(summary: summary)
            } else {
                emptyStateView
            }
        }
        // 권한·빈 상태·로딩 화면도 데이터 화면과 같은 바탕색(시스템 순검정이 아니라 Canvas)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.canvas.ignoresSafeArea())
        .navigationTitle("수면 분석")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await healthKit.refreshAccessState()
            if healthKit.canAttemptDataLoad {
                await store.loadDataIfNeeded()
            }
        }
        .onChange(of: store.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
        .onChange(of: healthKit.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
        .alert("오류", isPresented: $showingError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(store.errorMessage ?? healthKit.errorMessage ?? "")
        }
    }

    // MARK: - 기기 미지원

    private var unavailableView: some View {
        ContentUnavailableView(
            "건강 데이터 사용 불가",
            systemImage: "exclamationmark.triangle.fill",
            description: Text("이 기기에서는 건강 데이터를 사용할 수 없습니다.")
        )
    }

    // MARK: - 권한 요청

    private var authorizationView: some View {
        ContentUnavailableView {
            Label("수면 분석", systemImage: "moon.zzz.fill")
        } description: {
            Text("HealthKit과 연동하여\n수면 데이터를 확인할 수 있습니다")
        } actions: {
            Button {
                Task {
                    await healthKit.requestAuthorization()
                    if healthKit.canAttemptDataLoad {
                        await store.loadData()
                    }
                }
            } label: {
                // borderedProminent는 글자를 흰색으로 고정한다 — 다크 모드에서 accent(밝은 잉크) 위에 흰 글자가 되어 보이지 않았다.
                Text("HealthKit 연동하기")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.onAccent)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.accent)
        }
    }

    // MARK: - 데이터 없음

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("수면 데이터가 없습니다", systemImage: "bed.double.fill")
        } description: {
            Text("Apple Watch를 착용하고 주무시거나\niPhone의 수면 기능을 사용해 보세요.\n\n데이터가 보이지 않는 경우\n설정 > 건강 > 데이터 접근에서\n권한을 확인해 주세요.")
        } actions: {
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - 수면 데이터 표시

    private func sleepDataView(summary: SleepSummary) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.section) {
                LastNightCard(summary: summary)
                lastNightCaffeine(summary.date)
                StageBreakdownView(summary: summary)
                nightlyCaffeine()
                RecentNightsView(summaries: store.recentSummaries)
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.vertical, 16)
        }
        .refreshable {
            await store.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        SleepAnalysisView { _ in EmptyView() } nightlyCaffeine: { EmptyView() }
            .environment(HealthKitManager())
            .environment(SleepStore(samples: PreviewSleepSampleSource(), repository: PreviewSleepRepository()))
    }
}
