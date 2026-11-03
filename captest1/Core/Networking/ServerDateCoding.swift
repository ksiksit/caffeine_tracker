//
//  ServerDateCoding.swift
//  captest1
//
//  서버(Jackson)와의 JSON 날짜 계약.
//  - 시각: ISO-8601 + 오프셋으로 보내고(예: 2026-06-01T14:30:00+09:00), 수신은 UTC "Z"·소수초 유무 모두 허용.
//  - 날짜: "yyyy-MM-dd" 로컬 날짜(서버 LocalDate). 앱 전체에서 `localDate` 하나만 쓴다.
//  ISO8601DateFormatter는 Sendable이 아니지만 Foundation 문서상 스레드 안전하므로 nonisolated(unsafe)로 공유한다.
//

import Foundation

nonisolated enum ServerDateCoding {
    /// 전송용: 현재 타임존 오프셋 포함(예: 2026-06-01T14:30:00+09:00).
    static let encoding: JSONEncoder.DateEncodingStrategy = .custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(withFractional.string(from: date))
    }

    /// 수신용: 서버 Instant("...Z")·소수초 유무 모두 허용.
    static let decoding: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let raw = try decoder.singleValueContainer().decode(String.self)
        if let d = withFractional.date(from: raw) ?? withoutFractional.date(from: raw) {
            return d
        }
        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "ISO-8601 날짜 파싱 실패: \(raw)")
        )
    }

    /// ISO-8601 + 오프셋 문자열(쿼리 파라미터 `now` 등). '+'가 공백으로 해석되지 않도록 호출부에서 %2B로 인코딩할 것.
    static func isoOffset(_ date: Date) -> String {
        withFractional.string(from: date)
    }

    /// 서버 LocalDate("yyyy-MM-dd") ↔ 로컬 날짜. 설정(lastLearnedDate)·학습(observation.date)·수면(summary date)이 공유한다.
    static let localDate: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    nonisolated(unsafe) private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone.current
        return f
    }()

    nonisolated(unsafe) private static let withoutFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone.current
        return f
    }()
}
