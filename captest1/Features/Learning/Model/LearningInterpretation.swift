//
//  LearningInterpretation.swift
//  captest1
//
//  학습 대시보드의 표시용 문장. 통계와 건너뜀 사유는 서버가 계산한 값을 그대로 쓰고,
//  여기서는 "어젯밤이 학습됐는가"의 분류와 수치를 풀어 쓰는 문장만 만든다(순수 함수).
//

import Foundation

/// 어젯밤(오늘 아침에 끝난 밤)의 학습 결과 한 줄.
nonisolated enum LastNightLearning: Equatable, Sendable {
    case learned
    /// 사유는 서버 `skipMessage` 그대로. 서버가 사유를 주지 않은 실행이면 nil.
    case skipped(reason: String?)

    /// - Parameters:
    ///   - latestObservationDate: 대시보드의 가장 최근 관측 날짜(서버 LocalDate). 관측 날짜는 그 밤이 끝난 아침의 날짜다.
    ///   - today: 오늘의 로컬 날짜(서버 LocalDate 형식).
    ///   - updatedCount: 이번 학습 실행에서 학습된 밤 수. 실행이 실패했으면 nil.
    ///   - skipMessage: 서버가 준 건너뜀 사유 문장.
    /// - Returns: 판단할 근거가 없으면 nil(줄을 보이지 않는다).
    static func resolve(
        latestObservationDate: String?,
        today: String,
        updatedCount: Int?,
        skipMessage: String?
    ) -> LastNightLearning? {
        // 오늘 날짜의 관측이 있으면 어젯밤은 학습된 것이다(이번 실행이든 앞선 실행이든).
        if latestObservationDate == today { return .learned }
        // 학습 실행 결과를 모르면 건너뛰었다고 단정하지 않는다.
        guard let updatedCount else { return nil }
        // 더 오래된 밤만 학습된 실행은 서버가 사유를 주지 않는다.
        return .skipped(reason: updatedCount == 0 ? skipMessage : nil)
    }

    var isLearned: Bool { self == .learned }

    var text: String {
        switch self {
        case .learned:
            return "어젯밤: 학습됨"
        case .skipped(let reason):
            guard let reason, !reason.isEmpty else { return "어젯밤: 건너뜀" }
            return "어젯밤: 건너뜀 · \(reason)"
        }
    }
}

/// 모델 정확도 카드의 R²·RMSE를 풀어 쓴 문장. 값은 서버가 계산한 그대로 받는다.
nonisolated enum CalibrationInterpretation {
    /// 설명력(R²). 서버는 관측이 적거나 실제 값이 모두 같으면 null을 준다.
    static func rSquared(_ value: Double?) -> String {
        guard let value else {
            return "설명력(R²)은 밤마다 달라지는 잠드는 시간을 예측이 얼마나 따라가는지예요. 기록이 더 쌓이면 계산돼요."
        }
        if value <= 0 {
            return "설명력(R²)은 밤마다 달라지는 잠드는 시간을 예측이 얼마나 따라가는지예요. 지금은 0 이하라, 평소 평균으로 어림하는 것보다 아직 덜 맞아요."
        }
        let percent = Int((min(value, 1) * 100).rounded())
        return "설명력(R²)은 밤마다 달라지는 잠드는 시간을 예측이 얼마나 따라가는지예요. 지금은 그 차이의 약 \(percent)%를 설명해요. 1에 가까울수록 좋아요."
    }

    /// 평균 오차(RMSE, 분).
    static func rmse(_ minutes: Double) -> String {
        String(format: "평균 오차(RMSE)는 예측과 실제가 벌어진 정도예요. 지금은 잠드는 데 걸린 시간을 평균 약 %.0f분 차이로 맞혀요. 작을수록 좋아요.", minutes)
    }
}
