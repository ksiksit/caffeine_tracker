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
        let primaryColor: Color
        let primarySize: CGFloat
        let caption: String?
        let symbol: String
        let symbolTint: Color
    }

    private var heroStyle: HeroStyle {
        switch cutoffResult {
        case .safeAnytime:
            return HeroStyle(
                primary: "지금 OK",
                primaryColor: .green,
                primarySize: 44,
                caption: "취침까지 \(referenceDoseMg) mg 한 잔 OK",
                symbol: "checkmark.circle.fill",
                symbolTint: .green
            )

        case .cutoff(let time) where time > now:
            return HeroStyle(
                primary: Self.timeFormatter.string(from: time),
                primaryColor: Color("EspressoBrown"),
                primarySize: 56,
                caption: "이 시각까지 \(referenceDoseMg) mg 한 잔 OK",
                symbol: "clock.badge.checkmark",
                symbolTint: Color("EspressoBrown")
            )

        case .cutoff:
            return HeroStyle(
                primary: "지금은 패스",
                primaryColor: .orange,
                primarySize: 44,
                caption: "카페인 마감 시각이 지났어요",
                symbol: "clock.badge.xmark",
                symbolTint: .orange
            )

        case .alreadyExceeded(let predicted):
            return HeroStyle(
                primary: "오늘은 NO",
                primaryColor: .red,
                primarySize: 44,
                caption: "취침 시 예상 \(Int(predicted.rounded())) mg",
                symbol: "exclamationmark.triangle.fill",
                symbolTint: .red
            )
        }
    }

    var body: some View {
        let style = heroStyle
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                CategoryIconBadge(symbol: style.symbol, tint: style.symbolTint, size: 28)
                Text("오늘의 카페인")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(style.primary)
                    .font(.system(size: style.primarySize, weight: .bold, design: .rounded))
                    .foregroundStyle(style.primaryColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                if let caption = style.caption {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 12) {
                HealthMetric(
                    label: "현재 잔류량",
                    value: "\(Int(currentResidual.rounded()))",
                    unit: "mg"
                )
                HealthMetric(
                    label: "취침 시 예상",
                    value: "\(Int(predictedAtBedtime.rounded()))",
                    unit: "mg"
                )
            }

            HStack {
                Text("오늘 총 섭취")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(todayTotalMg) mg")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("/ \(AppConstants.Caffeine.dailyRecommendedLimitMg) mg")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
