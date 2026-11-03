//
//  ConfidenceBar.swift
//  captest1
//
//  학습 신뢰도(0~1)를 가로 막대 + % 라벨로 시각화.
//  LastNightCard의 GeometryReader+RoundedRectangle 패턴 답습.
//

import SwiftUI

struct ConfidenceBar: View {
    /// 0...1 범위. 외부에서 clamp 보장.
    let score: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("학습 신뢰도")
                    .font(.caption.weight(.medium))
                Spacer()
                Text("\(Int((score * 100).rounded()))%")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.Colors.accent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Theme.Radius.bar)
                        .fill(Theme.Colors.hairline)
                    RoundedRectangle(cornerRadius: Theme.Radius.bar)
                        .fill(Theme.Colors.accent)
                        .frame(width: max(4, geo.size.width * CGFloat(min(max(score, 0), 1))))
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ConfidenceBar(score: 0.0)
        ConfidenceBar(score: 0.25)
        ConfidenceBar(score: 0.67)
        ConfidenceBar(score: 0.97)
        ConfidenceBar(score: 1.0)
    }
    .padding()
}
