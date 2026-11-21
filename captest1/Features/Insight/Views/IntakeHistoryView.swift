//
//  IntakeHistoryView.swift
//  captest1
//
//  주간 섭취 히스토리 화면(로드맵 §2 (11)). 홈 "오늘 기록" 아래 줄에서 들어온다(탭 없음).
//  서버 요약 문장 → 지표 줄(평균·최대·초과 일수) → 날짜별 막대 → 날짜별 표. 모든 수치·문장·초과 판정은 서버 값 그대로다.
//

import SwiftUI
import Charts

struct IntakeHistoryView: View {
    @Environment(IntakeHistoryStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                switch store.phase {
                case .loading:
                    ProgressView("섭취 기록을 불러오는 중...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                case .failed(let message):
                    // 오류를 "기록이 없어요"로 보여 주면 마신 게 없다고 오해한다.
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
                    .accessibilityIdentifier("intakeHistoryError")
                case .empty(let stats):
                    ContentUnavailableView {
                        Label("지난 \(stats.dayCount)일 기록이 없어요", systemImage: "cup.and.saucer")
                    } description: {
                        Text(stats.summarySentence)
                    }
                    .padding(.vertical, 40)
                    .accessibilityIdentifier("intakeHistoryEmpty")
                case .loaded(let stats):
                    content(stats)
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.vertical, 16)
        }
        .background(Theme.Colors.canvas.ignoresSafeArea())
        .navigationTitle("섭취 히스토리")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
        .task { await store.refresh() }
        // 화면을 띄워 둔 채 날이 바뀌어도 어제까지의 기간이 남지 않게 다시 받는다.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await store.refresh() }
        }
    }

    @ViewBuilder
    private func content(_ stats: IntakeStatsResponse) -> some View {
        if store.isStale, let asOf = store.loadedAt {
            InsightStaleNotice(asOf: asOf)
        }
        if !stats.summarySentence.isEmpty {
            summary(stats.summarySentence)
        }
        metricStrip(stats)
        HealthCard("하루 섭취량", showsDivider: false) {
            chart(stats.days)
        }
        HealthCard("날짜별 기록", showsDivider: false) {
            VStack(spacing: 0) {
                ForEach(Array(store.daysNewestFirst.enumerated()), id: \.element.date) { index, day in
                    if index > 0 {
                        HairlineDivider()
                    }
                    dayRow(day)
                }
            }
        }
        .accessibilityIdentifier("intakeHistoryDays")
        Text("하루는 새벽 5시에 바뀌어요. 평균과 최대는 끝난 날만으로 계산해요.")
            .font(.footnote)
            .foregroundStyle(Theme.Colors.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func summary(_ sentence: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("요약")
            Text(sentence)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("intakeHistorySummary")
    }

    private func metricStrip(_ stats: IntakeStatsResponse) -> some View {
        let limit = AppConstants.Caffeine.dailyRecommendedLimitMg
        return MetricStrip([
            .init(label: "하루 평균", value: stats.averageDailyMg.map(InsightFormat.mg) ?? "–",
                  unit: stats.averageDailyMg == nil ? nil : "mg"),
            .init(label: "가장 많은 날", value: stats.maxDailyMg.map(InsightFormat.mg) ?? "–",
                  unit: stats.maxDailyMg == nil ? nil : "mg"),
            .init(label: "\(limit)mg 넘긴 날", value: "\(stats.overLimitDayCount)", unit: "일",
                  valueColor: stats.overLimitDayCount > 0 ? Theme.Colors.signalStop : Theme.Colors.ink),
        ])
    }

    // MARK: - 막대

    private static func day(_ key: String) -> Date? { ServerDateCoding.localDate.date(from: key) }

    private func chart(_ days: [IntakeStatsDayDTO]) -> some View {
        let rows = days.compactMap { day -> (date: Date, day: IntakeStatsDayDTO)? in
            Self.day(day.date).map { ($0, day) }
        }
        let limit = Double(AppConstants.Caffeine.dailyRecommendedLimitMg)
        return Chart {
            ForEach(rows, id: \.day.date) { row in
                BarMark(
                    x: .value("날짜", row.date, unit: .day),
                    y: .value("섭취량", row.day.totalMg)
                )
                .foregroundStyle(row.day.overLimit ? Theme.Colors.signalStop : Theme.Colors.ink.opacity(0.35))
                .cornerRadius(3)
            }
            RuleMark(y: .value("권장", limit))
                .foregroundStyle(Theme.Colors.inkSecondary.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .annotation(position: .top, alignment: .trailing, spacing: 2) {
                    Text("권장 \(InsightFormat.mg(limit)) mg")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
        }
        .chartXScale(domain: (rows.first?.date ?? Date())...(rows.last.map { $0.date.addingTimeInterval(86_400) } ?? Date()))
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .chartYAxis(.hidden)
        .frame(height: 140)
        .accessibilityLabel("지난 \(days.count)일 하루 카페인 섭취량 막대 그래프")
    }

    // MARK: - 날짜별 행

    private func dayRow(_ day: IntakeStatsDayDTO) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if let date = Self.day(day.date) {
                        Text(date, format: .dateTime.month(.defaultDigits).day().weekday(.abbreviated))
                    } else {
                        Text(day.date)
                    }
                }
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.Colors.ink)
                Text(Self.detailText(day))
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }

            Spacer()

            Text("\(InsightFormat.mg(day.totalMg)) mg")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Self.totalColor(day))
                .monospacedDigit()
        }
        .padding(.vertical, Theme.Spacing.row)
        .accessibilityElement(children: .combine)
    }

    /// 기록 수와 마지막 섭취 시각(서버 값의 표시 형식만 정한다).
    static func detailText(_ day: IntakeStatsDayDTO) -> String {
        guard day.recordCount > 0 else { return "기록 없음" }
        guard let last = day.lastIntakeAt else { return "\(day.recordCount)회" }
        return "\(day.recordCount)회 · 마지막 \(timeFormatter.string(from: last))"
    }

    private static func totalColor(_ day: IntakeStatsDayDTO) -> Color {
        if day.overLimit { return Theme.Colors.signalStop }
        return day.recordCount > 0 ? Theme.Colors.ink : Theme.Colors.inkSecondary
    }
}

/// 홈 "오늘 기록" 아래에서 히스토리 화면으로 들어가는 줄. 홈(Caffeine)이 슬롯으로 받고 조립은 ContentView가 한다.
struct IntakeHistoryLink: View {
    var body: some View {
        NavigationLink {
            IntakeHistoryView()
        } label: {
            HStack(spacing: 10) {
                Text("지난 \(IntakeHistoryStore.dayCount)일 섭취 보기")
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.outline)
        .accessibilityIdentifier("intakeHistoryLink")
    }
}

#Preview("기록 있음") {
    NavigationStack {
        IntakeHistoryView()
    }
    .environment(IntakeHistoryStore(repository: PreviewIntakeStatsRepository()))
}

#Preview("기록 없음") {
    NavigationStack {
        IntakeHistoryView()
    }
    .environment(IntakeHistoryStore(repository: PreviewIntakeStatsRepository(empty: true)))
}
