//
//  LastNightCaffeineRow.swift
//  captest1
//
//  수면 탭 지난밤 카드 아래: 그 밤 취침 때 남아 있던 카페인과 그날 섭취량(로드맵 §2 (1)).
//  잠들기까지(SOL)는 바로 위 지난밤 카드가 이미 보여 주므로 여기서는 다시 표시하지 않는다.
//  값·경계는 서버 리포트 그대로다. 수면 탭(Sleep)이 날짜를 넘기고, 조립은 ContentView가 한다.
//

import SwiftUI

struct LastNightCaffeineRow: View {
    @Environment(InsightStore.self) private var store
    /// 지난밤 카드의 날짜(밤이 끝나는 아침)
    let date: Date

    var body: some View {
        HealthCard("지난밤 카페인", showsDivider: false) {
            content
        }
        .task { await store.refreshIfNeeded() }
        .accessibilityIdentifier("lastNightCaffeine")
    }

    @ViewBuilder
    private var content: some View {
        if let night = store.night(endingOn: date), let threshold = store.residualThresholdMg {
            VStack(alignment: .leading, spacing: 8) {
                MetricStrip([
                    .init(label: "취침 때 카페인", value: InsightFormat.mg(night.residualAtBedtimeMg), unit: "mg",
                          valueColor: InsightFormat.isHigh(night.residualAtBedtimeMg, threshold: threshold)
                              ? Theme.Colors.signalStop : Theme.Colors.ink),
                    .init(label: "그날 섭취", value: InsightFormat.mg(night.dayTotalMg), unit: "mg"),
                ])
                Text("기준 \(InsightFormat.mg(threshold)) mg")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
        } else {
            InsightStatusText(isLoading: store.isLoading, errorMessage: store.errorMessage, loaded: store.report != nil,
                              emptyText: "이 밤은 취침 시각이 기록되지 않아 카페인 잔량을 계산하지 못했어요.")
        }
    }
}

/// 리포트가 없거나 그 밤이 없을 때의 한 줄. 실패를 "데이터 없음"처럼 보이게 하지 않는다.
struct InsightStatusText: View {
    let isLoading: Bool
    let errorMessage: String?
    let loaded: Bool
    let emptyText: String

    var body: some View {
        Group {
            if isLoading && !loaded {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("불러오는 중…")
                }
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.Colors.signalWarn)
            } else {
                Text(emptyText)
            }
        }
        .font(.subheadline)
        .foregroundStyle(Theme.Colors.inkSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 서버 값의 표시 형식. 계산이 아니라 반올림과 강조 여부만 정한다.
enum InsightFormat {
    static func mg(_ value: Double) -> String { "\(Int(value.rounded()))" }
    static func minutes(_ value: Double) -> String { "\(Int(value.rounded()))" }
    static func percent(_ ratio: Double) -> String { "\(Int((ratio * 100).rounded()))" }

    /// 서버 비교 A와 같은 경계(high = 잔량 ≥ residualThresholdMg). 기준값은 서버가 준 값을 받는다.
    static func isHigh(_ residual: Double, threshold: Double) -> Bool { residual >= threshold }

}

#Preview {
    LastNightCaffeineRow(date: Date())
        .environment(InsightStore(repository: PreviewInsightRepository()))
        .padding(Theme.Spacing.screen)
}
