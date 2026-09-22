//
//  CutoffHeroCard.swift
//  captest1
//

import SwiftUI

struct CutoffHeroCard: View {
    let cutoffResult: CaffeineCutoffResult
    let now: Date
    let currentResidual: Double
    let predictedAtBedtime: Double
    let referenceDoseMg: Int
    let todayTotalMg: Int

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()

    private struct HeroStyle {
        let primary: String
        let primarySize: CGFloat
        let caption: String?
        let signalColor: Color
        let signalSymbol: String
    }

    private var heroStyle: HeroStyle {
        switch cutoffResult {
        case .safeAnytime:
            return HeroStyle(
                primary: "지금 OK",
                primarySize: 44,
                caption: "취침까지 \(referenceDoseMg) mg 한 잔 OK",
                signalColor: Theme.Colors.signalOK,
                signalSymbol: "checkmark"
            )

        case .cutoff(let time) where time > now:
            let imminent = time.timeIntervalSince(now) <= 90 * 60
            return HeroStyle(
                primary: Self.timeFormatter.string(from: time),
                primarySize: 56,
                caption: imminent
                    ? "곧 마감 — 지금이 마지막 \(referenceDoseMg) mg 한 잔"
                    : "이 시각까지 \(referenceDoseMg) mg 한 잔 OK",
                signalColor: imminent ? Theme.Colors.signalWarn : Theme.Colors.signalOK,
                signalSymbol: imminent ? "exclamationmark" : "checkmark"
            )

        case .cutoff:
            return HeroStyle(
                primary: "지금은 패스",
                primarySize: 44,
                caption: "카페인 마감 시각이 지났어요",
                signalColor: Theme.Colors.signalStop,
                signalSymbol: "xmark"
            )

        case .alreadyExceeded(let predicted):
            return HeroStyle(
                primary: "오늘은 NO",
                primarySize: 44,
                caption: "취침 시 예상 \(Int(predicted.rounded())) mg",
                signalColor: Theme.Colors.signalStop,
                signalSymbol: "xmark"
            )
        }
    }

    var body: some View {
        let style = heroStyle
        VStack(spacing: 12) {
            Text("오늘의 카페인")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            CaffeineSignalDisc(
                color: style.signalColor,
                symbol: style.signalSymbol,
                primary: style.primary,
                primarySize: style.primarySize >= 50 ? 40 : 34,
                residualMg: Int(currentResidual.rounded()),
                predictedMg: Int(predictedAtBedtime.rounded()),
                todayTotalMg: todayTotalMg,
                dailyLimitMg: AppConstants.Caffeine.dailyRecommendedLimitMg
            )
            .padding(.vertical, 4)

            if let caption = style.caption {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("탭하여 상세 정보")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - 카페인 신호등 원 (탭하면 플립)

private struct CaffeineSignalDisc: View {
    let color: Color
    let symbol: String
    let primary: String
    let primarySize: CGFloat
    let residualMg: Int
    let predictedMg: Int
    let todayTotalMg: Int
    let dailyLimitMg: Int

    @State private var flipped = false

    private let diameter: CGFloat = 240

    var body: some View {
        ZStack {
            Circle()
                .fill(color.gradient)
                .overlay(Circle().fill(.black.opacity(flipped ? 0.16 : 0)))
                .shadow(color: color.opacity(0.5), radius: 18)

            front
                .opacity(flipped ? 0 : 1)

            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .frame(width: diameter, height: diameter)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .contentShape(Circle())
        .onTapGesture {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                flipped.toggle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("오늘의 카페인, \(primary)")
        .accessibilityHint(flipped ? "두 번 탭하여 닫기" : "두 번 탭하여 상세 정보")
        .accessibilityIdentifier("caffeineSignalDisc")
    }

    private var front: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            Text(primary)
                .font(.system(size: primarySize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 36)
    }

    private var back: some View {
        VStack(spacing: 14) {
            metric("잔류량", "\(residualMg) mg")
            metric("취침 예상", "\(predictedMg) mg")
            metric("총 섭취", "\(todayTotalMg) / \(dailyLimitMg) mg")
        }
        .padding(.horizontal, 40)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}
