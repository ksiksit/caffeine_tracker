//
//  CutoffPreviewBanner.swift
//  captest1
//

import SwiftUI

struct CutoffPreviewBanner: View {
    let current: CaffeineCutoffResult
    let projected: CaffeineCutoffResult
    let predictedAtBedtime: Double

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()

    private static let minimumChangeSeconds: TimeInterval = 5 * 60

    private enum Style {
        case info(String, String)       // symbol, message
        case warning(String, String)
    }

    private var style: Style? {
        switch (current, projected) {
        case (.safeAnytime, .safeAnytime):
            return nil

        case (.safeAnytime, .cutoff(let t)) where t > Date():
            let timeString = Self.timeFormatter.string(from: t)
            return .info("clock.badge.checkmark", "마감 자유 → \(timeString)까지 OK")

        case (.cutoff(let t1), .cutoff(let t2)) where t1 > Date() && t2 > Date():
            if abs(t1.timeIntervalSince(t2)) < Self.minimumChangeSeconds {
                return nil
            }
            let s1 = Self.timeFormatter.string(from: t1)
            let s2 = Self.timeFormatter.string(from: t2)
            return .info("clock.badge.checkmark", "마감 \(s1) → \(s2)")

        case (_, .alreadyExceeded(let predicted)):
            let mg = Int(predicted.rounded())
            return .warning(
                "exclamationmark.triangle.fill",
                "추가하면 취침 시 \(mg) mg — 수면에 영향"
            )

        case (_, .cutoff(let t)) where t <= Date():
            return .warning("clock.badge.exclamationmark", "추가하면 마감이 이미 지난 시각이 됩니다")

        default:
            return nil
        }
    }

    var body: some View {
        if let style {
            HStack(spacing: 10) {
                switch style {
                case .info(let symbol, let message):
                    Image(systemName: symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.accent)
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                case .warning(let symbol, let message):
                    Image(systemName: symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.signalStop)
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.Colors.signalStop)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surfaceMuted)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
