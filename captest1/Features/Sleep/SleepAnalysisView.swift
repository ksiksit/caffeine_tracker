//
//  SleepAnalysisView.swift
//  captest1
//

import SwiftUI

struct SleepAnalysisView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(SleepStore.self) private var store
    @State private var showingError: Bool = false

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
        .navigationTitle("수면 분석")
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
                Text("HealthKit 연동하기")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
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
            LazyVStack(spacing: 16) {
                LastNightCard(summary: summary)
                StageBreakdownView(summary: summary)
                RecentNightsView(summaries: store.recentSummaries)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .refreshable {
            await store.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        SleepAnalysisView()
            .environment(HealthKitManager())
            .environment(SleepStore(samples: PreviewSleepSampleSource(), repository: PreviewSleepRepository()))
    }
}
