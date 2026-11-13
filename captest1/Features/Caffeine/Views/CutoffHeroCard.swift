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

    /// 마감 임박(카운트다운)으로 보는 구간.
    static let countdownWindow: TimeInterval = 90 * 60

    /// today 조회 시각 기준 스타일(차트 마감선 색 등 바깥에서 읽는 값).
    var style: Style { style(at: now) }

    /// `at` 시각 기준 스타일. 카드 본문은 분마다 다시 계산해 남은 시간이 줄어든다.
    func style(at now: Date) -> Style {
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
            if time.timeIntervalSince(now) <= Self.countdownWindow {
                return Style(
                    status: Self.remainingText(until: time, from: now),
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

    /// 마감까지 남은 시간. "1시간 20분 남음" · "1시간 남음" · "40분 남음".
    /// 분은 올림한다(30초 남았을 때 "0분 남음"이 되지 않도록).
    static func remainingText(until deadline: Date, from now: Date) -> String {
        let totalMinutes = max(1, Int((deadline.timeIntervalSince(now) / 60).rounded(.up)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return String(localized: "\(minutes)분 남음")
        }
        if minutes == 0 {
            return String(localized: "\(hours)시간 남음")
        }
        return String(localized: "\(hours)시간 \(minutes)분 남음")
    }

    /// 분 경계 외에 상태가 바뀌는 순간: 카운트다운 시작(마감 90분 전)과 마감 시각. 둘 다 초 단위라 분 경계만으로는 최대 59초 늦게 바뀐다.
    var refreshDeadlines: [Date] {
        guard case .cutoff(let time) = cutoffResult else { return [] }
        return [time.addingTimeInterval(-Self.countdownWindow), time]
    }

    /// `at` 시각에 아직 지나지 않은 마감 시각(차트 마감선용).
    func upcomingCutoff(at now: Date) -> Date? {
        if case .cutoff(let time) = cutoffResult, time > now { return time }
        return nil
    }

    var body: some View {
        // 남은 시간이 다음 조회까지 멈춰 있지 않도록 다시 그린다.
        // now는 앱이 today 요청에 보낸 기기 시각을 서버가 그대로 돌려준 값이고, 마감 시각도 같은 기기 시계 기준이라
        // 기기 시계(context.date)로 비교한다. max는 조회 뒤 기기 시계가 뒤로 돌아간 경우만 막는다.
        TimelineView(CutoffRefreshSchedule(deadlines: refreshDeadlines)) { context in
            content(style: style(at: max(now, context.date)))
        }
    }

    private func content(style: Style) -> some View {
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

/// 매 분 경계 + 지정한 시각(마감 등)에 다시 그리는 스케줄.
struct CutoffRefreshSchedule: TimelineSchedule {
    let deadlines: [Date]

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        Entries(start: startDate, deadlines: deadlines)
    }

    struct Entries: Sequence, IteratorProtocol {
        private var nextMinute: Date
        private var pending: [Date]

        init(start: Date, deadlines: [Date]) {
            let floored = (start.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60
            nextMinute = Date(timeIntervalSinceReferenceDate: floored)
            pending = deadlines.filter { $0 > start }.sorted()
        }

        mutating func next() -> Date? {
            if let deadline = pending.first, deadline <= nextMinute {
                pending.removeFirst()
                // 분 경계와 같은 시각이면 한 번만 낸다
                if deadline < nextMinute { return deadline }
            }
            let minute = nextMinute
            nextMinute = minute.addingTimeInterval(60)
            return minute
        }
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
                }
                .buttonStyle(.outline)
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
