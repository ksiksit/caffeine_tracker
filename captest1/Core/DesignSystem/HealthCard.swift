//
//  HealthCard.swift
//  captest1
//
//  미니멀 방향의 공통 섹션 컴포넌트. 카드 배경 대신 "섹션 제목 + 내용 + 아래 구분선"으로 구역을 나눈다.
//  기존 호출부 호환을 위해 이니셜라이저(symbol·tint 포함)는 그대로 둔다.
//

import SwiftUI

/// 작은 원형 아이콘. 미니멀 방향에서는 옅은 면 위에 잉크색 심볼만 쓴다(tint는 심볼 색).
struct CategoryIconBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.Colors.surfaceMuted))
    }
}

struct HealthCard<Content: View>: View {
    let title: String?
    /// 호환용. 미니멀 방향에서는 섹션 제목 옆에 아이콘을 그리지 않는다.
    let symbol: String?
    /// 호환용. 섹션 자체는 색을 갖지 않는다.
    let tint: Color
    let trailing: AnyView?
    let collapsible: Bool
    let showsDivider: Bool
    @State private var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    init(
        _ title: String? = nil,
        symbol: String? = nil,
        tint: Color = Theme.Colors.accent,
        trailing: AnyView? = nil,
        collapsible: Bool = false,
        initiallyExpanded: Bool = false,
        showsDivider: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.trailing = trailing
        self.collapsible = collapsible
        self.showsDivider = showsDivider
        self._isExpanded = State(initialValue: initiallyExpanded)
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || trailing != nil || collapsible {
                header
            }
            if !collapsible || isExpanded {
                content()
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(Theme.Colors.hairline)
                    .frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        let row = HStack(spacing: 8) {
            if let title {
                SectionHeader(title)
                    .fixedSize()
            }
            Spacer(minLength: 0)
            if let trailing {
                trailing
            }
            if collapsible {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
        .frame(minHeight: collapsible ? 44 : nil)

        if collapsible {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                row.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(title ?? ""))
            .accessibilityValue(Text(isExpanded ? "펼쳐짐" : "접힘"))
        } else {
            row
        }
    }
}

struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(Theme.Fonts.sectionTitle)
            .foregroundStyle(Theme.Colors.inkSecondary)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
