//
//  CutoffHeroCard.swift
//  captest1
//
//  홈 맨 위 핵심 문장. "오후 3:20까지 150 mg 한 잔은 괜찮아요"처럼 답을 먼저 보여준다.
//  상태 판정(4가지)은 서버 cutoff 결과 그대로이고, 여기선 문구·신호색만 정한다.
//

import SwiftUI

struct CutoffHeroCard: View {
    let cutoffResult: CaffeineCutoffResult
    let now: Date
    let referenceDoseMg: Int

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()

    struct Style {
        let status: String
        let symbol: String
        let color: Color
        let headline: String
    }

    var style: Style {
        switch cutoffResult {
        case .safeAnytime:
            return Style(
                status: "지금 OK",
                symbol: "checkmark",
                color: Theme.Colors.signalOK,
                headline: "취침 전까지\n\(referenceDoseMg) mg 한 잔은 괜찮아요"
            )

        case .cutoff(let time) where time > now:
            let timeText = Self.timeFormatter.string(from: time)
            if time.timeIntervalSince(now) <= 90 * 60 {
                return Style(
                    status: "곧 마감",
                    symbol: "exclamationmark",
                    color: Theme.Colors.signalWarn,
                    headline: "\(timeText) 마감\n지금이 마지막 \(referenceDoseMg) mg 한 잔이에요"
                )
            }
            return Style(
                status: "한 잔 더 가능",
                symbol: "checkmark",
                color: Theme.Colors.signalOK,
                headline: "\(timeText)까지\n\(referenceDoseMg) mg 한 잔은 괜찮아요"
            )

        case .cutoff:
            return Style(
                status: "지금은 패스",
                symbol: "xmark",
                color: Theme.Colors.signalStop,
                headline: "오늘 카페인 마감 시각이\n지났어요"
            )

        case .alreadyExceeded(let predicted):
            return Style(
                status: "오늘은 NO",
                symbol: "xmark",
                color: Theme.Colors.signalStop,
                headline: "취침 시 예상 \(Int(predicted.rounded())) mg\n오늘은 여기까지만 마셔요"
            )
        }
    }

    var body: some View {
        let style = style
        VStack(alignment: .leading, spacing: 10) {
            Text("오늘의 카페인")
                .font(Theme.Fonts.sectionTitle)
                .foregroundStyle(Theme.Colors.inkSecondary)

            Label {
                Text(style.status)
            } icon: {
                Image(systemName: style.symbol)
                    .fontWeight(.bold)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(style.color)

            Text(style.headline)
                .font(Theme.Fonts.heroTitle)
                .foregroundStyle(Theme.Colors.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("caffeineCutoffHero")
    }
}

/// 서버 today를 아직 받지 못했을 때의 hero. 판단 근거가 없으므로 "괜찮아요"라고 말하지 않고 중립 상태를 보여준다.
struct CutoffUnavailableHero: View {
    /// 불러오기에 실패했는가(false면 첫 로드 중)
    let failed: Bool
    /// 다시 불러오는 중
    let isRetrying: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("오늘의 카페인")
                .font(Theme.Fonts.sectionTitle)
                .foregroundStyle(Theme.Colors.inkSecondary)

            if failed {
                Label {
                    Text("확인 불가")
                } icon: {
                    Image(systemName: "exclamationmark")
                        .fontWeight(.bold)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.signalWarn)

                Text("서버에 연결하지 못해\n지금은 판단할 수 없어요")
                    .font(Theme.Fonts.heroTitle)
                    .foregroundStyle(Theme.Colors.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onRetry) {
                    HStack(spacing: 8) {
                        if isRetrying {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("다시 시도")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Spacing.cornerRadius, style: .continuous)
                            .stroke(Theme.Colors.hairline, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isRetrying)
                .padding(.top, 4)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("불러오는 중")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.inkSecondary)

                Text("오늘 마감 시각을\n계산하고 있어요")
                    .font(Theme.Fonts.heroTitle)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("caffeineCutoffHero")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 32) {
        CutoffHeroCard(cutoffResult: .cutoff(Date().addingTimeInterval(3 * 3600)), now: Date(), referenceDoseMg: 150)
        CutoffHeroCard(cutoffResult: .cutoff(Date().addingTimeInterval(40 * 60)), now: Date(), referenceDoseMg: 150)
        CutoffHeroCard(cutoffResult: .alreadyExceeded(82), now: Date(), referenceDoseMg: 150)
        CutoffUnavailableHero(failed: true, isRetrying: false) {}
    }
    .padding(Theme.Spacing.screen)
}
