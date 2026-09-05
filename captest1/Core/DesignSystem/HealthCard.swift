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
    let collapsible: Bool
    @State private var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    init(
        _ title: String? = nil,
        symbol: String? = nil,
        tint: Color = .accentColor,
        trailing: AnyView? = nil,
        collapsible: Bool = false,
        initiallyExpanded: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.trailing = trailing
        self.collapsible = collapsible
        self._isExpanded = State(initialValue: initiallyExpanded)
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || symbol != nil || trailing != nil || collapsible {
                header
            }
            if !collapsible || isExpanded {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private var header: some View {
        let row = HStack(spacing: 10) {
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
            if collapsible {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }

        if collapsible {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                row.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            row
        }
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
