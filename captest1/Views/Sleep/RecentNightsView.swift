//
//  RecentNightsView.swift
//  captest1
//

import SwiftUI

struct RecentNightsView: View {
    let summaries: [SleepSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("최근 기록")
                .font(.headline)
                .padding(.bottom, 4)

            if summaries.isEmpty {
                Text("최근 수면 기록이 없습니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(summaries) { summary in
                    HStack {
                        Text(summary.date, format: .dateTime.month().day().weekday())
                            .font(.subheadline)
                        Spacer()
                        Text(SleepSummary.formatDuration(summary.totalSleepDuration))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
