//
//  Controls.swift
//  captest1
//
//  화면마다 따로 그리던 버튼·입력 칸·구분선을 한 곳에 모은 공통 컨트롤. 값은 Theme 토큰만 쓴다.
//

import SwiftUI

// MARK: - 버튼

/// 화면의 주 동작 하나(카페인 기록·로그인·가입하기). 꽉 찬 너비, 잉크색 면. 비활성이면 옅은 면.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(configuration: configuration)
    }

    private struct PrimaryButton: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.body.weight(.semibold))
                .foregroundStyle(isEnabled ? Theme.Colors.onAccent : Theme.Colors.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButton)
                .background(
                    isEnabled ? Theme.Colors.accent : Theme.Colors.surfaceMuted,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                )
                .opacity(configuration.isPressed ? 0.75 : 1)
                .contentShape(Rectangle())
        }
    }
}

/// 보조 동작(다시 시도·상세 보기). 구분선 테두리만 있는 버튼.
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.Colors.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: Theme.Size.minTouch)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .stroke(Theme.Colors.hairline, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static var outline: OutlineButtonStyle { OutlineButtonStyle() }
}

// MARK: - 입력 칸

extension View {
    /// 옅은 면 위의 입력 칸(로그인·가입·직접 입력 공통).
    func themedField() -> some View {
        padding(Theme.Spacing.field)
            .background(
                Theme.Colors.surfaceMuted,
                in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
            )
    }
}

// MARK: - 구분선

/// 1pt 구분선. 시스템 Divider 대신 써서 라이트/다크 모두 Hairline 색을 따른다.
struct HairlineDivider: View {
    var vertical = false

    var body: some View {
        Rectangle()
            .fill(Theme.Colors.hairline)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}
