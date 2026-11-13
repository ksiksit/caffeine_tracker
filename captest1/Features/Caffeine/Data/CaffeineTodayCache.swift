//
//  CaffeineTodayCache.swift
//  captest1
//
//  마지막으로 받은 오늘 현황(/api/caffeine/today)의 기기 사본. 서버에 닿지 못할 때 "N분 전 기준"으로 보여 준다.
//  나중에 위젯이 네트워크 없이 같은 값을 읽을 수 있게 스냅샷 하나(계정·형식 버전·응답)로 저장한다.
//  위젯 타깃을 붙일 때는 App Group의 UserDefaults(suiteName:)를 주입하면 된다 — 저장 형식은 그대로 쓴다.
//

import Foundation

final class CaffeineTodayCache {
    /// 저장 형식. 필드를 바꾸면 올린다 — 버전이 다른 스냅샷은 버린다.
    static let schemaVersion = 1

    nonisolated struct Snapshot: Codable, Sendable {
        let schemaVersion: Int
        /// 이 응답을 받은 계정. 다른 계정으로 로그인하면 쓰지 않는다.
        let accountId: Int64
        let today: CaffeineTodayResponse
    }

    private static let key = "caffeine.todaySnapshot"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ today: CaffeineTodayResponse, accountId: Int64) {
        let snapshot = Snapshot(schemaVersion: Self.schemaVersion, accountId: accountId, today: today)
        defaults.set(try? JSONEncoder().encode(snapshot), forKey: Self.key)
    }

    /// 이 계정의 스냅샷. 없거나 형식이 다르거나 다른 계정 것이면 nil.
    func load(accountId: Int64) -> CaffeineTodayResponse? {
        guard let data = defaults.data(forKey: Self.key),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.schemaVersion == Self.schemaVersion,
              snapshot.accountId == accountId else { return nil }
        return snapshot.today
    }

    /// 로그아웃 — 이전 계정의 값을 지운다.
    func clear() {
        defaults.removeObject(forKey: Self.key)
    }

    // MARK: - 유효 기간

    /// 서버의 하루 경계(새벽 5시) 기준으로 `date`가 속한 날의 시작.
    static func dayStart(of date: Date, calendar: Calendar = .current) -> Date {
        let boundary = AppConstants.Pharmacokinetics.chartStartHour
        let shifted = calendar.date(byAdding: .hour, value: -boundary, to: date) ?? date
        let start = calendar.startOfDay(for: shifted)
        return calendar.date(byAdding: .hour, value: boundary, to: start) ?? start
    }

    /// 캐시한 응답을 지금 보여 줄 수 있는가. 기록 목록·합계·마감이 그날 것이라 하루 경계를 넘으면 쓰지 않는다.
    /// `today.now`는 앱이 요청에 보낸 기기 시각을 서버가 돌려준 값이라 기기 시계와 바로 비교할 수 있다.
    static func isUsable(_ today: CaffeineTodayResponse, at now: Date, calendar: Calendar = .current) -> Bool {
        dayStart(of: today.now, calendar: calendar) == dayStart(of: now, calendar: calendar)
    }
}
