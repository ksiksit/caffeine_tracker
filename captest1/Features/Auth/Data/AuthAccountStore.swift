//
//  AuthAccountStore.swift
//  captest1
//
//  마지막으로 서버가 확인해 준 계정(userId·이메일)의 Keychain 사본.
//  저장된 세션(refresh 토큰)이 있는데 앱 시작 때 서버에 닿지 못하면 이 계정으로 오프라인 진입해 기기 캐시를 보여 준다.
//  서버 판정(토큰 무효·401)은 바꾸지 않는다 — 온라인이 되면 기존 refresh·세션 만료 흐름이 그대로 판정한다.
//

import Foundation

nonisolated struct AuthAccountStore: Sendable {
    private static let account = "lastVerifiedAccount"
    private let keychain: KeychainHelper

    init(keychain: KeychainHelper) {
        self.keychain = keychain
    }

    func save(_ me: MeResponse) {
        guard let data = try? JSONEncoder().encode(me) else { return }
        try? keychain.save(data, account: Self.account)
    }

    func load() -> MeResponse? {
        guard let data = (try? keychain.read(account: Self.account)) ?? nil else { return nil }
        return try? JSONDecoder().decode(MeResponse.self, from: data)
    }

    func clear() {
        try? keychain.delete(account: Self.account)
    }
}
