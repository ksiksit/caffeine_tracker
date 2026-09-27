//
//  AppEnvironment.swift
//  captest1
//

import Foundation

enum AppEnvironment {
    /// 서버 주소. 우선순위: 번들의 `Secrets.plist`(gitignore) → Info.plist `BASE_URL`(저장소 기본 localhost) → 폴백.
    /// 배포 서버 주소는 공개 저장소에 올리지 않는다 — `Config/Secrets.example.plist`를 `captest1/Resources/Secrets.plist`로
    /// 복사해 값을 넣으면 그 빌드만 배포 서버를 바라본다.
    static var baseURL: URL {
        if let url = url(from: secrets?["BASE_URL"]) { return url }
        if let url = url(from: Bundle.main.object(forInfoDictionaryKey: "BASE_URL")) { return url }
        // INFOPLIST_KEY_BASE_URL이 자동 Info.plist에 반영되지 않은 경우 폴백
        #if DEBUG
        return URL(string: "http://localhost:8080")!
        #else
        return URL(string: "https://api.production.example.com")!
        #endif
    }

    private static var secrets: [String: Any]? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    private static func url(from value: Any?) -> URL? {
        guard let str = value as? String, !str.isEmpty else { return nil }
        return URL(string: str)
    }
}
