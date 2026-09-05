//
//  LastNightCard.swift
//  captest1
//

import SwiftUI

struct LastNightCard: View {
    let summary: SleepSummary

    var body: some View {
        HealthCard(
            "지난밤 수면",
            symbol: "bed.double.fill",
            tint: .indigo,
            trailing: AnyView(
                Text(summary.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(totalMinutes / 60)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("시간")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                    Text(String(format: "%02d", totalMinutes % 60))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("분")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 16) {
                    metricColumn(
                        label: "침대에서",
                        value: SleepSummary.formatDuration(summary.timeInBed)
                    )
                    Divider().frame(height: 36)
                    metricColumn(
                        label: "수면 효율",
                        value: "\(Int(summary.sleepEfficiency * 100))%"
                    )
                }

                if !summary.stageBreakdown.isEmpty {
                    stageColorBar
                }
            }
        }
    }

    private var totalMinutes: Int {
        Int(summary.totalSleepDuration / 60)
    }

    private func metricColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stageColorBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(summary.stageBreakdown, id: \.stage) { item in
                    let ratio = item.duration / summary.timeInBed
                    RoundedRectangle(cornerRadius: 2)
                        .fill(item.stage.color)
                        .frame(width: max(3, geometry.size.width * ratio - 2))
                }
            }
        }
        .frame(height: 4)
    }
}
