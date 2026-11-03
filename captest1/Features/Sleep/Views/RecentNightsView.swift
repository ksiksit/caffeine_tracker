//
//  RecentNightsView.swift
//  captest1
//
//  최근 7일 총 수면 시간 막대. 가장 최근 밤만 진하게 표시한다.
//

import SwiftUI
import Charts

struct RecentNightsView: View {
    let summaries: [SleepSummary]

    /// 날짜 오름차순 최근 7개
    private var recent: [SleepSummary] {
        Array(summaries.sorted { $0.date < $1.date }.suffix(7))
    }

    private var averageText: String? {
        guard !recent.isEmpty else { return nil }
        let avg = recent.map(\.totalSleepDuration).reduce(0, +) / Double(recent.count)
        return "\(recent.count)일 평균 \(SleepSummary.formatDuration(avg))"
    }

    var body: some View {
        HealthCard("최근 7일", showsDivider: false) {
            if recent.isEmpty {
                Text("최근 수면 기록이 없습니다")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Chart(recent) { summary in
                        BarMark(
                            x: .value("날짜", summary.date, unit: .day),
                            y: .value("수면 시간", summary.totalSleepDuration / 3600)
                        )
                        .foregroundStyle(summary.id == recent.last?.id ? Theme.Colors.ink : Theme.Colors.hairline)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                                .foregroundStyle(Theme.Colors.inkSecondary)
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 120)
                    .accessibilityLabel("최근 \(recent.count)일 수면 시간 막대 그래프")

                    if let averageText {
                        Text(averageText)
                            .font(.footnote)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                }
            }
        }
    }
}
