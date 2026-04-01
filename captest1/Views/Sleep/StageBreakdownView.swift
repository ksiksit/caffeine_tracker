//
//  StageBreakdownView.swift
//  captest1
//

import SwiftUI

struct StageBreakdownView: View {
    let summary: SleepSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("수면 단계")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(summary.stageBreakdown, id: \.stage) { item in
                HStack {
                    Circle()
                        .fill(item.stage.color)
                        .frame(width: 10, height: 10)
                    Text(item.stage.displayName)
                        .font(.subheadline)
                    Spacer()
                    Text(SleepSummary.formatDuration(item.duration))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
