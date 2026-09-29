//
//  LastNightCard.swift
//  captest1
//
//  수면 탭 맨 위: 지난밤 총 수면 시간을 크게, 아래에 단계 막대와 지표 줄.
//

import SwiftUI

struct LastNightCard: View {
    let summary: SleepSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 4) {
                Text("지난밤")
                Text("·")
                Text(summary.date, format: .dateTime.month().day().weekday(.wide))
            }
            .font(Theme.Fonts.sectionTitle)
            .foregroundStyle(Theme.Colors.inkSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(totalMinutes / 60)")
                    .font(Theme.Fonts.heroNumber)
                Text("시간")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .padding(.trailing, 6)
                Text("\(totalMinutes % 60)")
                    .font(Theme.Fonts.heroNumber)
                Text("분")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
            .foregroundStyle(Theme.Colors.ink)
            .accessibilityElement(children: .combine)

            if !summary.stageBreakdown.isEmpty {
                stageColorBar
            }

            MetricStrip(metrics)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var totalMinutes: Int {
        Int(summary.totalSleepDuration / 60)
    }

    private var metrics: [MetricStrip.Item] {
        var items: [MetricStrip.Item] = [
            .init(label: "침대에서", value: SleepSummary.formatDuration(summary.timeInBed)),
            .init(label: "수면 효율", value: "\(Int((summary.sleepEfficiency * 100).rounded()))", unit: "%"),
        ]
        if let sol = summary.sleepOnsetLatency {
            items.append(.init(label: "잠들기까지", value: "\(Int((sol / 60).rounded()))", unit: "분"))
        }
        return items
    }

    private var stageColorBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(summary.stageBreakdown, id: \.stage) { item in
                    let ratio = summary.timeInBed > 0 ? item.duration / summary.timeInBed : 0
                    RoundedRectangle(cornerRadius: Theme.Radius.bar)
                        .fill(item.stage.color)
                        .frame(width: max(3, geometry.size.width * ratio - 2))
                }
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}
