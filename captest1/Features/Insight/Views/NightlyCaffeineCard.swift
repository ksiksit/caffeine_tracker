//
//  NightlyCaffeineCard.swift
//  captest1
//
//  최근 7밤의 카페인과 수면을 나란히(로드맵 §2 (6)). 막대는 취침 잔량, 가로선은 서버 기준(50mg).
//  아래 표는 밤마다 그날 섭취·취침 잔량·잠들기까지·수면 효율. 모든 값은 서버 리포트 nights 그대로다.
//

import SwiftUI
import Charts

struct NightlyCaffeineCard: View {
    @Environment(InsightStore.self) private var store

    var body: some View {
        HealthCard("최근 7일 밤별 카페인", showsDivider: false) {
            if let threshold = store.residualThresholdMg, !store.recentNights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    if store.isStale, let asOf = store.loadedAt {
                        InsightStaleNotice(asOf: asOf)
                    }
                    chart(threshold: threshold)
                    table(threshold: threshold)
                }
            } else {
                InsightStatusText(isLoading: store.isLoading, errorMessage: store.errorMessage,
                                  loaded: store.report != nil, emptyText: "최근 수면 기록이 없어요.")
            }
        }
        .task { await store.refreshIfNeeded() }
        .accessibilityIdentifier("nightlyCaffeine")
    }

    private static func day(_ key: String) -> Date? { ServerDateCoding.localDate.date(from: key) }

    private func chart(threshold: Double) -> some View {
        let rows = store.recentNights.compactMap { row -> (date: Date, night: InsightNightDTO)? in
            guard let night = row.night, let date = Self.day(row.key) else { return nil }
            return (date, night)
        }
        let days = store.recentNights.compactMap { Self.day($0.key) }
        return Chart {
            ForEach(rows, id: \.night.date) { row in
                BarMark(
                    x: .value("밤", row.date, unit: .day),
                    y: .value("취침 잔량", row.night.residualAtBedtimeMg)
                )
                .foregroundStyle(InsightFormat.isHigh(row.night.residualAtBedtimeMg, threshold: threshold)
                                 ? Theme.Colors.signalStop : Theme.Colors.ink.opacity(0.35))
                .cornerRadius(3)
            }
            RuleMark(y: .value("기준", threshold))
                .foregroundStyle(Theme.Colors.inkSecondary.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .annotation(position: .top, alignment: .trailing, spacing: 2) {
                    Text("기준 \(InsightFormat.mg(threshold)) mg")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
        }
        .chartXScale(domain: (days.first ?? Date())...(days.last.map { $0.addingTimeInterval(86_400) } ?? Date()))
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .chartYAxis(.hidden)
        .frame(height: 120)
        .accessibilityLabel("최근 7밤 취침 때 카페인 잔량 막대 그래프")
    }

    private func table(threshold: Double) -> some View {
        VStack(spacing: 0) {
            header
            ForEach(store.recentNights.reversed(), id: \.key) { row in
                HairlineDivider()
                nightRow(key: row.key, night: row.night, threshold: threshold)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("밤").frame(maxWidth: .infinity, alignment: .leading)
            Text("그날 섭취").frame(width: 62, alignment: .trailing)
            Text("취침 잔량").frame(width: 62, alignment: .trailing)
            Text("잠들기").frame(width: 46, alignment: .trailing)
            Text("효율").frame(width: 40, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Theme.Colors.inkSecondary)
        .padding(.bottom, 6)
    }

    private func nightRow(key: String, night: InsightNightDTO?, threshold: Double) -> some View {
        HStack {
            Group {
                if let date = Self.day(key) {
                    Text(date, format: .dateTime.month(.defaultDigits).day().weekday(.abbreviated))
                } else {
                    Text(key)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let night {
                Text("\(InsightFormat.mg(night.dayTotalMg))mg").frame(width: 62, alignment: .trailing)
                Text("\(InsightFormat.mg(night.residualAtBedtimeMg))mg")
                    .foregroundStyle(InsightFormat.isHigh(night.residualAtBedtimeMg, threshold: threshold)
                                     ? Theme.Colors.signalStop : Theme.Colors.ink)
                    .frame(width: 62, alignment: .trailing)
                Text(night.solMinutes.map { "\(InsightFormat.minutes($0))분" } ?? "–").frame(width: 46, alignment: .trailing)
                Text("\(InsightFormat.percent(night.sleepEfficiency))%").frame(width: 40, alignment: .trailing)
            } else {
                Text("데이터 없음")
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .frame(width: 62 + 62 + 46 + 40 + 24, alignment: .trailing)
            }
        }
        .font(.footnote)
        .monospacedDigit()
        .foregroundStyle(Theme.Colors.ink)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScrollView {
        NightlyCaffeineCard()
            .padding(Theme.Spacing.screen)
    }
    .environment(InsightStore(repository: PreviewInsightRepository()))
}
