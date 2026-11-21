//
//  InsightReportPeriod.swift
//  captest1
//
//  리포트 화면의 조회 기간(서버 계획서 §4: 7·14·30일, 기본 14일). 서버 기간 검증(31일 이하) 안.
//

import Foundation

nonisolated enum InsightReportPeriod: Int, CaseIterable, Identifiable, Sendable {
    case week = 7
    case twoWeeks = 14
    case month = 30

    static let `default`: InsightReportPeriod = .twoWeeks

    var id: Int { rawValue }
    /// 오늘 아침까지 포함한 아침 날짜 수
    var days: Int { rawValue }
    var label: String { "\(rawValue)일" }
}
