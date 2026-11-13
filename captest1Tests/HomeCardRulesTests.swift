//
//  HomeCardRulesTests.swift
//  captest1Tests
//
//  홈 화면 표시 규칙 검증: 마감 카운트다운 문구(CutoffHeroCard), 차트 취침 이후 위험 영역 판정(CaffeineChartView).
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

    @Test func dangerZone_exactlyAtThreshold_isHidden() {
        let data = points([(0, 100), (120, 50), (180, 40)])
        #expect(CaffeineChartView.dangerZoneTop(dataPoints: data, bedtime: now.addingTimeInterval(120 * 60), threshold: 50) == nil)
    }

    @Test func dangerZone_noPointsAfterBedtime_isHidden() {
        let data = points([(0, 100), (60, 80)])
        #expect(CaffeineChartView.dangerZoneTop(dataPoints: data, bedtime: now.addingTimeInterval(120 * 60), threshold: 50) == nil)
    }
}
