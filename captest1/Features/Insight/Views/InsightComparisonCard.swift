//
//  InsightComparisonCard.swift
//  captest1
//
//  리포트 화면의 비교 카드(비교 A 취침 잔량 · 비교 B 마감 시각 공용). 서버 문장과 두 그룹의 평균을 나란히 보여 준다.
//  그룹 평균·차이·문장은 모두 서버 값이다. 여기서는 반올림과 "값 없음" 표시만 정한다.
//

import SwiftUI

/// 비교 하나를 화면에 놓을 글자들. 계산이 아니라 서버 값의 표시 형식만 정한다(단위 테스트 대상).
struct InsightComparisonDisplay {
    enum Kind {
        /// 비교 A. 경계는 서버 `residualThresholdMg`
        case residual(thresholdMg: Double)
        /// 비교 B
        case cutoff
    }

    struct Row: Identifiable {
        let label: String
        let high: String
        let low: String
        var id: String { label }
    }

    static let missing = "–"

    let title: String
    let highLabel: String
    let lowLabel: String
    let rows: [Row]
    /// 서버 문장. 비어 있으면 그리지 않는다.
    let sentence: String
    /// 표본이 모자랄 때만(서버 `sufficient == false`). 밤 수는 서버 `moreNightsNeeded`.
    let shortageText: String?

    init(kind: Kind, comparison: InsightComparisonDTO) {
        switch kind {
        case .residual(let thresholdMg):
            title = "취침 때 남은 카페인으로 비교"
            highLabel = "\(InsightFormat.mg(thresholdMg))mg 이상"
            lowLabel = "\(InsightFormat.mg(thresholdMg))mg 미만"
        case .cutoff:
            title = "마감 시각을 지켰는지로 비교"
            highLabel = "마감 넘김"
            lowLabel = "마감 지킴"
        }
        let high = comparison.high, low = comparison.low
        rows = [
            Row(label: "밤 수", high: "\(high.nightCount)밤", low: "\(low.nightCount)밤"),
            Row(label: "잠들기까지", high: Self.minutes(high.avgSolMinutes), low: Self.minutes(low.avgSolMinutes)),
            Row(label: "수면 효율", high: Self.percent(high.avgSleepEfficiency), low: Self.percent(low.avgSleepEfficiency)),
            Row(label: "총 수면", high: Self.duration(high.avgTotalSleepMinutes), low: Self.duration(low.avgTotalSleepMinutes)),
            Row(label: "깊은 수면", high: Self.percent(high.avgDeepSleepRatio), low: Self.percent(low.avgDeepSleepRatio)),
        ]
        sentence = comparison.sentence
        if comparison.sufficient {
            shortageText = nil
        } else if let needed = comparison.moreNightsNeeded, needed > 0 {
            shortageText = "비교하려면 \(needed)밤이 더 필요해요"
        } else {
            shortageText = "아직 비교할 만큼 밤이 모이지 않았어요"
        }
    }

    private static func minutes(_ value: Double?) -> String {
        value.map { "\(InsightFormat.minutes($0))분" } ?? missing
    }

    private static func percent(_ ratio: Double?) -> String {
        ratio.map { "\(InsightFormat.percent($0))%" } ?? missing
    }

    private static func duration(_ minutes: Double?) -> String {
        minutes.map(InsightFormat.duration(minutes:)) ?? missing
    }
}

struct InsightComparisonCard: View {
    let display: InsightComparisonDisplay

    var body: some View {
        HealthCard(display.title, showsDivider: false) {
            VStack(alignment: .leading, spacing: 12) {
                if let shortage = display.shortageText {
                    Label(shortage, systemImage: "moon.zzz")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.Colors.signalWarn)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("insightComparisonShortage")
                }
                if !display.sentence.isEmpty {
                    // 같은 문장이 화면 맨 위 요약(headlines)에도 올 수 있어 여기서는 본문 크기로 둔다.
                    Text(display.sentence)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.Colors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                table
            }
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack {
                Text("평균").frame(maxWidth: .infinity, alignment: .leading)
                Text(display.highLabel).frame(width: Self.columnWidth, alignment: .trailing)
                Text(display.lowLabel).frame(width: Self.columnWidth, alignment: .trailing)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.Colors.inkSecondary)
            .padding(.bottom, 6)

            ForEach(display.rows) { row in
                HairlineDivider()
                HStack {
                    Text(row.label)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.high).frame(width: Self.columnWidth, alignment: .trailing)
                    Text(row.low).frame(width: Self.columnWidth, alignment: .trailing)
                }
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.ink)
                .padding(.vertical, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(row.label), \(display.highLabel) \(row.high), \(display.lowLabel) \(row.low)")
            }
        }
    }

    private static let columnWidth: CGFloat = 92
}

#Preview {
    let high = InsightGroupDTO(nightCount: 5, solNightCount: 5, avgSolMinutes: 27, avgSleepEfficiency: 0.86,
                               avgTotalSleepMinutes: 402, avgDeepSleepRatio: 0.14)
    let low = InsightGroupDTO(nightCount: 2, solNightCount: 0, avgSolMinutes: nil, avgSleepEfficiency: 0.9,
                              avgTotalSleepMinutes: 431, avgDeepSleepRatio: nil)
    let comparison = InsightComparisonDTO(high: high, low: low, sufficient: false, moreNightsNeeded: 1,
                                          solDiffMinutes: nil, efficiencyDiff: nil,
                                          sentence: "비교하려면 잔량이 낮았던 밤이 1밤 더 필요해요")
    return InsightComparisonCard(display: .init(kind: .residual(thresholdMg: 50), comparison: comparison))
        .padding(Theme.Spacing.screen)
}
