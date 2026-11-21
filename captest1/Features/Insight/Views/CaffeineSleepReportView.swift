//
//  CaffeineSleepReportView.swift
//  captest1
//
//  카페인·수면 상관 리포트 화면(로드맵 §3.1). 수면 탭의 밤별 카페인 카드에서 들어온다.
//  기간 선택 → 서버 요약 문장(headlines) → 비교 A(취침 잔량) → 비교 B(마감 시각). 모든 수치·문장은 서버 값 그대로다.
//

import SwiftUI

struct CaffeineSleepReportView: View {
    @Environment(InsightReportStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                periodPicker
                switch store.phase {
                case .loading:
                    ProgressView("리포트를 불러오는 중...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                case .failed(let message):
                    // 오류를 "밤이 모자라요"로 보여 주면 기록이 부족하다고 오해한다.
                    ContentUnavailableView {
                        Label("불러오지 못했어요", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("다시 시도") {
                            Task { await store.refresh() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 40)
                    .accessibilityIdentifier("insightReportError")
                case .empty(let report):
                    ContentUnavailableView {
                        Label("아직 비교할 밤이 없어요", systemImage: "bed.double.fill")
                    } description: {
                        Text(report.headlines.first ?? "이 기간에는 취침 시각이 기록된 밤이 없어요.")
                    }
                    .padding(.vertical, 40)
                    .accessibilityIdentifier("insightReportEmpty")
                case .loaded(let report):
                    content(report)
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.vertical, 16)
        }
        .background(Theme.Colors.canvas.ignoresSafeArea())
        .navigationTitle("카페인과 수면")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
        .task { await store.refreshIfNeeded() }
    }

    private var periodPicker: some View {
        Picker("기간", selection: Binding(
            get: { store.period },
            set: { period in Task { await store.select(period) } }
        )) {
            ForEach(InsightReportPeriod.allCases) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("insightReportPeriod")
    }

    @ViewBuilder
    private func content(_ report: CaffeineSleepReportResponse) -> some View {
        if store.isStale, let asOf = store.loadedAt {
            InsightStaleNotice(asOf: asOf)
        }
        if !report.headlines.isEmpty {
            headlines(report.headlines)
        }
        InsightComparisonCard(display: .init(kind: .residual(thresholdMg: report.residualThresholdMg),
                                             comparison: report.residualComparison))
            .accessibilityIdentifier("insightResidualComparison")
        InsightComparisonCard(display: .init(kind: .cutoff, comparison: report.cutoffComparison))
            .accessibilityIdentifier("insightCutoffComparison")
        Text(Self.basisText(report))
            .font(.footnote)
            .foregroundStyle(Theme.Colors.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func headlines(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("요약")
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("insightHeadlines")
    }

    /// 무엇으로 계산한 리포트인지(기간·밤 수·반감기). 서버 응답 값을 그대로 적는다.
    static func basisText(_ report: CaffeineSleepReportResponse) -> String {
        let halfLife = String(format: "%.1f", report.halfLifeHoursUsed)
        return "\(report.from) ~ \(report.to) · 수면 기록이 있는 \(report.nightCount)밤 · 지금 반감기 \(halfLife)시간으로 계산"
    }
}

/// 밤별 카페인 카드 아래에서 리포트 화면으로 들어가는 줄.
struct InsightReportLink: View {
    var body: some View {
        NavigationLink {
            CaffeineSleepReportView()
        } label: {
            HStack(spacing: 10) {
                Text("카페인과 수면 비교 보기")
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.outline)
        .accessibilityIdentifier("insightReportLink")
    }
}

#Preview {
    NavigationStack {
        CaffeineSleepReportView()
    }
    .environment(InsightReportStore(repository: PreviewInsightRepository()))
}
