//
//  MetricStrip.swift
//  captest1
//
//  위아래 구분선 사이에 지표를 가로로 나란히 놓는 줄(예: 지금 체내 / 취침 시 예상 / 오늘 섭취).
//  기존 HealthMetric(미사용)을 대체한다.
//

import SwiftUI

struct MetricStrip: View {
    struct Item: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        var unit: String? = nil
        var valueColor: Color = Theme.Colors.ink
    }

    let items: [Item]

    init(_ items: [Item]) {
        self.items = items
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    HairlineDivider(vertical: true)
                        .padding(.trailing, 16)
                }
                cell(item)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 16)
        .overlay(alignment: .top) { HairlineDivider() }
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    private func cell(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.label)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.inkSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(item.value)
                    .font(Theme.Fonts.metricValue)
                    .foregroundStyle(item.valueColor)
                if let unit = item.unit {
                    Text(unit)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MetricStrip([
        .init(label: "지금 체내", value: "129", unit: "mg"),
        .init(label: "취침 시 예상", value: "36", unit: "mg"),
        .init(label: "오늘 섭취", value: "225", unit: "mg"),
    ])
    .padding(Theme.Spacing.screen)
}
