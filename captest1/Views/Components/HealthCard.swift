//
//  HealthCard.swift
//  captest1
//

import SwiftUI

struct CategoryIconBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.54, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(tint))
    }
}

struct HealthCard<Content: View>: View {
    let title: String?
    let symbol: String?
    let tint: Color
    let trailing: AnyView?
    @ViewBuilder let content: () -> Content

    init(
        _ title: String? = nil,
        symbol: String? = nil,
        tint: Color = .accentColor,
        trailing: AnyView? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || symbol != nil || trailing != nil {
                HStack(spacing: 10) {
                    if let symbol {
                        CategoryIconBadge(symbol: symbol, tint: tint, size: 28)
                    }
                    if let title {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    Spacer(minLength: 0)
                    if let trailing {
                        trailing
                    }
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct HealthMetric: View {
    let label: String
    let value: String
    let unit: String?
    var valueColor: Color = .primary

    init(label: String, value: String, unit: String? = nil, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.unit = unit
        self.valueColor = valueColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
