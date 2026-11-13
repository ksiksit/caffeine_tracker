//
//  StaleTextTests.swift
//  captest1Tests
//
//  홈·수면 탭이 함께 쓰는 연결 끊김 문구: 분·시간 경계, 시계 역행.
//

import Foundation
import Testing
@testable import captest1

struct StaleTextTests {
    @Test func minutesAndHours() {
        let asOf = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(StaleText.make(asOf: asOf, now: asOf.addingTimeInterval(30)) == "서버 연결 안 됨 · 방금 전 기준")
        // 12분 59초는 내림해 12분
        #expect(StaleText.make(asOf: asOf, now: asOf.addingTimeInterval(12 * 60 + 59)) == "서버 연결 안 됨 · 12분 전 기준")
        #expect(StaleText.make(asOf: asOf, now: asOf.addingTimeInterval(125 * 60)) == "서버 연결 안 됨 · 2시간 전 기준")
        // 기기 시계가 뒤로 돌아가도 음수가 되지 않는다
        #expect(StaleText.make(asOf: asOf, now: asOf.addingTimeInterval(-60)) == "서버 연결 안 됨 · 방금 전 기준")
    }
}
