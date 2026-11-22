//
//  LearningInterpretationTests.swift
//  captest1Tests
//
//  학습 대시보드 표시 문장(어젯밤 학습 여부·R²/RMSE 해석). 수치는 서버 값 그대로 쓰는지 확인한다.
//

import Testing
@testable import captest1

struct LearningInterpretationTests {

    // MARK: - 어젯밤 학습 여부

    @Test func resolve_learned_whenLatestObservationIsToday() {
        let status = LastNightLearning.resolve(
            latestObservationDate: "2026-06-02", today: "2026-06-02", updatedCount: 0,
            skipReason: "ALREADY_LEARNED", skipMessage: "최근 수면 기록은 이미 학습에 반영됐어요.")
        #expect(status == .learned)
        #expect(status?.text == "어젯밤: 학습됨")
    }

    @Test func resolve_skipped_carriesServerMessage() {
        let status = LastNightLearning.resolve(
            latestObservationDate: "2026-06-01", today: "2026-06-02", updatedCount: 0,
            skipReason: "LEARNING_DISABLED", skipMessage: "자동 학습이 꺼져 있어요.")
        #expect(status == .skipped(reason: "자동 학습이 꺼져 있어요."))
        #expect(status?.text == "어젯밤: 건너뜀 · 자동 학습이 꺼져 있어요.")
    }

    /// 오늘 관측이 없는데 서버가 ALREADY_LEARNED를 주면 어젯밤 데이터가 서버에 없는 것이다. "건너뜀 · 이미 반영됐어요"는 모순이다.
    @Test func resolve_noSleepRecord_whenAlreadyLearnedButNotObservedToday() {
        let status = LastNightLearning.resolve(
            latestObservationDate: "2026-06-01", today: "2026-06-02", updatedCount: 0,
            skipReason: "ALREADY_LEARNED", skipMessage: "최근 수면 기록은 이미 학습에 반영됐어요.")
        #expect(status == .noSleepRecord)
        #expect(status?.text == "어젯밤: 아직 수면 기록 없음")
    }

    @Test func resolve_skipped_withoutReason_whenServerGaveNone() {
        #expect(LastNightLearning.resolve(
            latestObservationDate: "2026-06-01", today: "2026-06-02", updatedCount: 1, skipReason: nil, skipMessage: nil) == .skipped(reason: nil))
        #expect(LastNightLearning.skipped(reason: "").text == "어젯밤: 건너뜀")
    }

    @Test func resolve_nil_whenRunResultUnknown() {
        #expect(LastNightLearning.resolve(
            latestObservationDate: "2026-06-01", today: "2026-06-02", updatedCount: nil, skipReason: nil, skipMessage: nil) == nil)
        #expect(LastNightLearning.resolve(
            latestObservationDate: nil, today: "2026-06-02", updatedCount: nil, skipReason: nil, skipMessage: nil) == nil)
    }

    // MARK: - R² / RMSE 해석

    @Test func rSquared_explainsShareAsPercent() {
        let text = CalibrationInterpretation.rSquared(0.624)
        #expect(text.contains("설명력(R²)"))
        #expect(text.contains("약 62%"))
    }

    @Test func rSquared_nil_saysNotYetComputed() {
        let text = CalibrationInterpretation.rSquared(nil)
        #expect(text.contains("기록이 더 쌓이면"))
        #expect(!text.contains("%"))
    }

    @Test func rSquared_zeroOrNegative_saysWorseThanAverage() {
        for value in [0.0, -0.4] {
            let text = CalibrationInterpretation.rSquared(value)
            #expect(text.contains("0 이하"))
            #expect(!text.contains("%"))
        }
    }

    @Test func rmse_explainsMinutes() {
        let text = CalibrationInterpretation.rmse(8.4)
        #expect(text.contains("평균 오차(RMSE)"))
        #expect(text.contains("약 8분"))
    }
}
