//
//  TokenStore.swift
//  captest1
//

import Foundation

actor TokenStore {
    private let keychain: KeychainHelper
    private let accessAccount = "accessToken"
    private let refreshAccount = "refreshToken"

    private(set) var accessToken: String?
    private(set) var refreshToken: String?

    init(keychain: KeychainHelper) {
        self.keychain = keychain
    }

    /// 앱 시작 시 Keychain에서 메모리 캐시로 로드
    func bootstrap() {
        accessToken = (try? keychain.readString(account: accessAccount)) ?? nil
        refreshToken = (try? keychain.readString(account: refreshAccount)) ?? nil
    }

    func save(access: String, refresh: String) {
        accessToken = access
        refreshToken = refresh
        try? keychain.saveString(access, account: accessAccount)
        try? keychain.saveString(refresh, account: refreshAccount)
    }

    func saveAccess(_ token: String) {
        accessToken = token
        try? keychain.saveString(token, account: accessAccount)
    }

    func saveRefresh(_ token: String) {
        refreshToken = token
        try? keychain.saveString(token, account: refreshAccount)
    }

    func clear() {
        accessToken = nil
        refreshToken = nil
        try? keychain.delete(account: accessAccount)
        try? keychain.delete(account: refreshAccount)
    }
}
