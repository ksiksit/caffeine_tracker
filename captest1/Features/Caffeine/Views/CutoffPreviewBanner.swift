//
//  CutoffPreviewBanner.swift
//  captest1
//

import SwiftUI

struct CutoffPreviewBanner: View {
    let current: CaffeineCutoffResult
    let projected: CaffeineCutoffResult
    let predictedAtBedtime: Double
    /// 기록 수정 화면인가. 문구의 "추가하면"이 "수정하면"으로 바뀐다.
    var isEditing: Bool = false
    /// 저장하면 하루 권장량을 넘을 때의 오늘 총량(mg). 넘지 않으면 nil.
    var overLimitTotalMg: Int? = nil

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()

    private static let minimumChangeSeconds: TimeInterval = 5 * 60

    /// 배너 한 줄. 경고면 빨간색으로 그린다.
    struct Line: Equatable {
        let isWarning: Bool
        let symbol: String
        let message: String
    }

    /// 마감 시각 변화 한 줄. 알릴 변화가 없으면 nil.
    /// 수정 모드에서는 양을 줄이거나 시각을 당겨 마감이 풀리는 방향도 나올 수 있다.
    static func cutoffLine(
        current: CaffeineCutoffResult,
        projected: CaffeineCutoffResult,
        isEditing: Bool,
        now: Date = Date()
    ) -> Line? {
        let verb = isEditing ? "수정하면" : "추가하면"
        func time(_ date: Date) -> String { timeFormatter.string(from: date) }
        func info(_ message: String) -> Line {
            Line(isWarning: false, symbol: "clock.badge.checkmark", message: message)
        }

        switch (current, projected) {
        case (.safeAnytime, .safeAnytime):
            return nil

        case (.cutoff(let t1), .cutoff(let t2)) where t1 > now && t2 > now:
            if abs(t1.timeIntervalSince(t2)) < minimumChangeSeconds {
                return nil
            }
            return info("마감 \(time(t1)) → \(time(t2))")

        case (_, .alreadyExceeded(let predicted)):
            let mg = Int(predicted.rounded())
            return Line(
                isWarning: true, symbol: "exclamationmark.triangle.fill",
                message: "\(verb) 취침 시 \(mg) mg — 수면에 영향"
            )

        case (_, .cutoff(let t)) where t <= now:
            return Line(
                isWarning: true, symbol: "clock.badge.exclamationmark",
                message: "\(verb) 마감이 이미 지난 시각이 됩니다"
            )

        case (.safeAnytime, .cutoff(let t)):
            return info("마감 자유 → \(time(t))까지 OK")

        case (_, .cutoff(let t)):
            // 취침 시 초과였거나 마감이 지나 있던 상태에서 풀리는 경우(수정 모드).
            return info("\(verb) \(time(t))까지 OK")

        case (.cutoff(let t), .safeAnytime) where t > now:
            return info("마감 \(time(t)) → 마감 자유")

        case (_, .safeAnytime):
            return info("\(verb) 마감 자유")
        }
    }

    /// 하루 권장량 초과 한 줄.
    static func dailyTotalLine(overLimitTotalMg: Int?, isEditing: Bool) -> Line? {
        guard let total = overLimitTotalMg else { return nil }
        let verb = isEditing ? "수정하면" : "추가하면"
        return Line(
            isWarning: true, symbol: "exclamationmark.triangle.fill",
            message: "\(verb) 오늘 총 \(total) mg — 하루 권장 \(AppConstants.Caffeine.dailyRecommendedLimitMg) mg 초과"
        )
    }

    private var lines: [Line] {
        [
            Self.cutoffLine(current: current, projected: projected, isEditing: isEditing),
            Self.dailyTotalLine(overLimitTotalMg: overLimitTotalMg, isEditing: isEditing),
        ].compactMap { $0 }
    }

    var body: some View {
        let lines = lines
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines, id: \.message) { line in
                    HStack(spacing: 10) {
                        Image(systemName: line.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(line.isWarning ? Theme.Colors.signalStop : Theme.Colors.accent)
                        Text(line.message)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(line.isWarning ? Theme.Colors.signalStop : Theme.Colors.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surfaceMuted)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
