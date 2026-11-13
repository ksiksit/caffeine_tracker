//
//  StaleText.swift
//  captest1
//
//  서버 조회에 실패해 마지막으로 받은 값을 보여 줄 때 쓰는 공용 문구("서버 연결 안 됨 · N분 전 기준").
//  홈(카페인)과 수면 탭(인사이트)이 같은 문구를 쓴다.
//

import Foundation

enum StaleText {
    /// "서버 연결 안 됨 · 12분 전 기준". `asOf`·`now` 모두 기기 시계 기준. 시계가 뒤로 가도 음수가 되지 않는다.
    static func make(asOf: Date, now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(asOf) / 60))
        let ago: String
        if minutes < 1 {
            ago = String(localized: "방금 전")
        } else if minutes < 60 {
            ago = String(localized: "\(minutes)분 전")
        } else {
            ago = String(localized: "\(minutes / 60)시간 전")
        }
        return String(localized: "서버 연결 안 됨 · \(ago) 기준")
    }
}
