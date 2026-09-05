//
//  StageBreakdownView.swift
//  captest1
//

import SwiftUI

struct StageBreakdownView: View {
    let summary: SleepSummary

    var body: some View {
        HealthCard("수면 단계", symbol: "chart.bar.fill", tint: .indigo, collapsible: true) {
            VStack(spacing: 0) {
                ForEach(Array(summary.stageBreakdown.enumerated()), id: \.element.stage) { index, item in
                    if index > 0 {
                        Divider().padding(.leading, 22)
                    }
                    HStack(spacing: 12) {
                        Circle()
                            .fill(item.stage.color)
                            .frame(width: 10, height: 10)
                        Text(item.stage.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(SleepSummary.formatDuration(item.duration))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }
}
