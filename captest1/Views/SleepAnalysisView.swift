//
//  SleepAnalysisView.swift
//  captest1
//

import SwiftUI

struct SleepAnalysisView: View {
    @Environment(HealthKitManager.self) private var manager
    @State private var showingError: Bool = false

    var body: some View {
        Group {
            if !manager.isAvailable {
                unavailableView
            } else if !manager.hasRequestedAuthorization {
                authorizationView
            } else if manager.isLoading {
                ProgressView("수면 데이터를 불러오는 중...")
            } else if let summary = manager.lastNightSummary {
                sleepDataView(summary: summary)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("수면 분석")
        .task {
            if manager.isAvailable && manager.hasRequestedAuthorization {
                await manager.loadDataIfNeeded()
            }
        }
        .onChange(of: manager.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
        .alert("오류", isPresented: $showingError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(manager.errorMessage ?? "")
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
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundStyle(.indigo)

            Text("수면 분석")
                .font(.title2)
                .fontWeight(.semibold)

            Text("HealthKit과 연동하여\n수면 데이터를 확인할 수 있습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await manager.requestAuthorization()
                    await manager.loadData()
                }
            } label: {
                Text("HealthKit 연동하기")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - 데이터 없음

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bed.double.fill")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("수면 데이터가 없습니다")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Apple Watch를 착용하고 주무시거나\niPhone의 수면 기능을 사용해 보세요.\n\n데이터가 보이지 않는 경우\n설정 > 건강 > 데이터 접근에서\n권한을 확인해 주세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }

    // MARK: - 수면 데이터 표시

    private func sleepDataView(summary: SleepSummary) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                LastNightCard(summary: summary)
                StageBreakdownView(summary: summary)
                RecentNightsView(summaries: manager.recentSummaries)
            }
            .padding()
        }
        .refreshable {
            await manager.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        SleepAnalysisView()
            .environment(HealthKitManager())
    }
}
