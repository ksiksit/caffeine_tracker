//
//  HomeCardRulesTests.swift
//  captest1Tests
//
//  홈 화면 표시 규칙 검증: 마감 카운트다운 문구·다시 그리는 시각(CutoffHeroCard), 차트 취침 이후 위험 영역 판정(CaffeineChartView).
//

import Foundation
import Testing
@testable import captest1

struct HomeCardRulesTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - 마감 카운트다운

    @Test func remaining_hoursAndMinutes() {
        let text = CutoffHeroCard.remainingText(until: now.addingTimeInterval(80 * 60), from: now)
        #expect(text == "1시간 20분 남음")
    }

    @Test func remaining_wholeHour() {
        let text = CutoffHeroCard.remainingText(until: now.addingTimeInterval(60 * 60), from: now)
        #expect(text == "1시간 남음")
    }

    @Test func remaining_minutesOnly() {
        let text = CutoffHeroCard.remainingText(until: now.addingTimeInterval(40 * 60), from: now)
        #expect(text == "40분 남음")
    }

    @Test func remaining_roundsUpPartialMinute() {
        // 30초 남았을 때 "0분 남음"이 아니라 "1분 남음"
        let text = CutoffHeroCard.remainingText(until: now.addingTimeInterval(30), from: now)
        #expect(text == "1분 남음")
    }

    @Test func heroStatus_withinNinetyMinutes_showsCountdown() {
        let card = CutoffHeroCard(cutoffResult: .cutoff(now.addingTimeInterval(80 * 60)), now: now, referenceDoseMg: 150)
        #expect(card.style.status == "1시간 20분 남음")
    }

    @Test func heroStatus_beyondNinetyMinutes_unchanged() {
        let card = CutoffHeroCard(cutoffResult: .cutoff(now.addingTimeInterval(3 * 3600)), now: now, referenceDoseMg: 150)
        #expect(card.style.status == "한 잔 더 가능")
    }

    @Test func heroStatus_laterClock_countsDown() {
        let card = CutoffHeroCard(cutoffResult: .cutoff(now.addingTimeInterval(80 * 60)), now: now, referenceDoseMg: 150)
        #expect(card.style(at: now.addingTimeInterval(30 * 60)).status == "50분 남음")
        #expect(card.style(at: now.addingTimeInterval(81 * 60)).status == "지금은 패스")
    }

    @Test func heroStatus_exactlyNinetyMinutes_showsCountdown() {
        let card = CutoffHeroCard(cutoffResult: .cutoff(now.addingTimeInterval(90 * 60)), now: now, referenceDoseMg: 150)
        #expect(card.style.status == "1시간 30분 남음")
    }

    @Test func heroStatus_justOverNinetyMinutes_unchanged() {
        let card = CutoffHeroCard(cutoffResult: .cutoff(now.addingTimeInterval(90 * 60 + 1)), now: now, referenceDoseMg: 150)
        #expect(card.style.status == "한 잔 더 가능")
    }

    @Test func heroStatus_cutoffEqualsNow_isPass() {
        let card = CutoffHeroCard(cutoffResult: .cutoff(now), now: now, referenceDoseMg: 150)
        #expect(card.style.status == "지금은 패스")
    }

    @Test func heroStatus_atCutoffSecond_isPass_notOneMinuteLeft() {
        // 마감 15:00:20 → 15:00:19는 "1분 남음", 15:00:20은 "지금은 패스"
        let cutoff = now.addingTimeInterval(20 * 60 + 20)
        let card = CutoffHeroCard(cutoffResult: .cutoff(cutoff), now: now, referenceDoseMg: 150)
        #expect(card.style(at: cutoff.addingTimeInterval(-1)).status == "1분 남음")
        #expect(card.style(at: cutoff).status == "지금은 패스")
    }

    // MARK: - 다시 그리는 시각

    private func minute(_ m: Double, second s: Double = 0) -> Date {
        // now(1_800_000_000)는 분 경계가 아니므로 기준 분을 따로 잡는다
        let base = (now.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60
        return Date(timeIntervalSinceReferenceDate: base + m * 60 + s)
    }

    @Test func refreshSchedule_includesCutoffSecond() {
        let start = minute(0, second: 30)
        let cutoff = minute(1, second: 20)
        var entries = CutoffRefreshSchedule.Entries(start: start, deadlines: [cutoff])
        let first = (0..<4).compactMap { _ in entries.next() }
        #expect(first == [minute(0), minute(1), cutoff, minute(2)])
    }

    @Test func refreshSchedule_deadlineOnMinute_notDuplicated_pastIgnored() {
        let start = minute(0, second: 30)
        var entries = CutoffRefreshSchedule.Entries(start: start, deadlines: [minute(2), minute(-5)])
        let first = (0..<4).compactMap { _ in entries.next() }
        #expect(first == [minute(0), minute(1), minute(2), minute(3)])
    }

    @Test func refreshDeadlines_countdownStartAndCutoff() {
        let cutoff = now.addingTimeInterval(3 * 3600 + 17)
        let card = CutoffHeroCard(cutoffResult: .cutoff(cutoff), now: now, referenceDoseMg: 150)
        #expect(card.refreshDeadlines == [cutoff.addingTimeInterval(-90 * 60), cutoff])
        #expect(CutoffHeroCard(cutoffResult: .safeAnytime, now: now, referenceDoseMg: 150).refreshDeadlines.isEmpty)
    }

    // MARK: - 차트 취침 이후 위험 영역

    private func points(_ values: [(minutes: Double, mg: Double)]) -> [CaffeineKineticsCalculator.DataPoint] {
        values.enumerated().map { i, v in
            .init(index: i, time: now.addingTimeInterval(v.minutes * 60), concentrationMg: v.mg)
        }
    }

    @Test func dangerZone_highDaytimeButSafeAtBedtime_isHidden() {
        // 낮 최대 180mg, 취침(120분) 이후 최대 24mg → 그리지 않음
        let data = points([(0, 180), (60, 90), (120, 24), (180, 15)])
        #expect(CaffeineChartView.dangerZoneTop(dataPoints: data, bedtime: now.addingTimeInterval(120 * 60), threshold: 50) == nil)
    }

    @Test func dangerZone_overThresholdAfterBedtime_usesMaxAfterBedtime() {
        let data = points([(0, 180), (60, 120), (120, 80), (180, 60)])
        #expect(CaffeineChartView.dangerZoneTop(dataPoints: data, bedtime: now.addingTimeInterval(120 * 60), threshold: 50) == 80)
    }

    @Test func dangerZone_exactlyAtThreshold_isDrawn() {
        // 서버 신호등은 취침 잔량 50mg "이상"이면 초과(headroom <= 0). 차트도 같은 경계
        let data = points([(0, 100), (120, 50), (180, 40)])
        #expect(CaffeineChartView.dangerZoneTop(dataPoints: data, bedtime: now.addingTimeInterval(120 * 60), threshold: 50) == 50)
    }

    @Test func dangerZone_predictedAtBedtimeExactlyThreshold_isDrawn() {
        let data = points([(0, 100), (120, 40)])
        let top = CaffeineChartView.dangerZoneTop(
            dataPoints: data, bedtime: now.addingTimeInterval(110 * 60), threshold: 50, predictedAtBedtime: 50)
        #expect(top == 50)
    }

    @Test func dangerZone_bedtimeBetweenSamples_usesPredictedAtBedtime() {
        // 취침 23:10(샘플 사이). 23:00 51mg, 23:15 49.8mg, 서버 취침 시 잔량 50.4mg → 신호등은 초과, 차트도 그린다
        let data = points([(0, 51), (15, 49.8), (30, 48.5)])
        let bedtime = now.addingTimeInterval(10 * 60)
        #expect(CaffeineChartView.dangerZoneTop(dataPoints: data, bedtime: bedtime, threshold: 50) == nil)
        #expect(CaffeineChartView.dangerZoneTop(dataPoints: data, bedtime: bedtime, threshold: 50, predictedAtBedtime: 50.4) == 50.4)
    }

    @Test func dangerZone_bedtimeBetweenSamples_safePrediction_isHidden() {
        let data = points([(0, 52), (15, 47), (30, 45)])
        let top = CaffeineChartView.dangerZoneTop(
            dataPoints: data, bedtime: now.addingTimeInterval(10 * 60), threshold: 50, predictedAtBedtime: 49.6)
        #expect(top == nil)
    }

    @Test func dangerZone_noPointsAfterBedtime_isHidden() {
        let data = points([(0, 100), (60, 80)])
        #expect(CaffeineChartView.dangerZoneTop(dataPoints: data, bedtime: now.addingTimeInterval(120 * 60), threshold: 50) == nil)
    }
}
