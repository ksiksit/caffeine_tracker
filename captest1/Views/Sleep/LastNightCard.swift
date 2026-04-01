//
//  LastNightCard.swift
//  captest1
//

import SwiftUI

struct LastNightCard: View {
    let summary: SleepSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.indigo)
                Text("지난밤 수면")
                    .font(.headline)
                Spacer()
                Text(summary.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(SleepSummary.formatDuration(summary.totalSleepDuration))
                .font(.system(size: 36, weight: .bold))

            HStack(spacing: 16) {
                Label(
                    "침대 \(SleepSummary.formatDuration(summary.timeInBed))",
                    systemImage: "bed.double"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Label(
                    "효율 \(Int(summary.sleepEfficiency * 100))%",
                    systemImage: "chart.bar"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if !summary.stageBreakdown.isEmpty {
                stageColorBar
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var stageColorBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(summary.stageBreakdown, id: \.stage) { item in
                    let ratio = item.duration / summary.timeInBed
                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.stage.color)
                        .frame(width: max(4, geometry.size.width * ratio - 2))
                }
            }
        }
        .frame(height: 12)
    }
}
