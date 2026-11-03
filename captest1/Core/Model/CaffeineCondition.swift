//
//  CaffeineCondition.swift
//  captest1
//

import Foundation

enum CaffeineCondition: Int, CaseIterable, Identifiable {
    case none = 0
    case smoker = 1
    case oralContraceptive = 2
    case pregnant = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none:              return "해당 없음"
        case .smoker:            return "흡연자"
        case .oralContraceptive: return "경구 피임약 복용"
        case .pregnant:          return "임신 중"
        }
    }

    var multiplier: Double {
        switch self {
        case .none:              return 1.0
        case .smoker:            return 0.5
        case .oralContraceptive: return 2.0
        case .pregnant:          return 2.5
        }
    }

    /// 건강 상태 보정 반감기 = base × multiplier. 서버 calc.Pharmacokinetics와 같은 규칙(즉시 미리보기용 로컬 미러).
    func effectiveHalfLife(base: Double) -> Double {
        base * multiplier
    }

    var description: String {
        switch self {
        case .none:              return ""
        case .smoker:            return "흡연은 카페인 대사를 촉진합니다 (반감기 ×0.5)"
        case .oralContraceptive: return "경구 피임약은 카페인 대사를 늦춥니다 (반감기 ×2)"
        case .pregnant:          return "임신 중 카페인 대사가 크게 느려집니다 (반감기 ×2.5)"
        }
    }
}
