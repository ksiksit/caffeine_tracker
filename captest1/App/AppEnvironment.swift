//
//  AppEnvironment.swift
//  captest1
//

import Foundation

enum AppEnvironment {
    static var baseURL: URL {
        if let str = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String,
           !str.isEmpty,
           let url = URL(string: str) {
            return url
        }
        // INFOPLIST_KEY_BASE_URL이 자동 Info.plist에 반영되지 않은 경우 폴백
        #if DEBUG
        return URL(string: "http://localhost:8080")!
        #else
        return URL(string: "https://api.production.example.com")!
        #endif
    }
}
