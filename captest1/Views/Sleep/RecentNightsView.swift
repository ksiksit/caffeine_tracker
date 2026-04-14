//
//  RecentNightsView.swift
//  captest1
//

import SwiftUI

struct RecentNightsView: View {
    let summaries: [SleepSummary]

    var body: some View {
        HealthCard("최근 기록", symbol: "calendar", tint: .indigo) {
            if summaries.isEmpty {
                Text("최근 수면 기록이 없습니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                        if index > 0 {
                            Divider()
                        }
                        HStack {
                            Text(summary.date, format: .dateTime.month().day().weekday())
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(SleepSummary.formatDuration(summary.totalSleepDuration))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }
}
