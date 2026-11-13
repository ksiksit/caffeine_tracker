//
//  AuthManagerTests.swift
//  captest1Tests
//
//  앱 시작 자동 로그인과 오프라인 진입: 저장된 세션 + 네트워크 오류면 서버가 확인했던 계정으로 들어가고,
//  서버 판정(토큰 무효·세션 만료)은 그대로 로그아웃시킨다. Keychain은 테스트마다 별도 service.
//

import Foundation
import Testing
@testable import captest1

@MainActor
@Suite(.serialized)
struct AuthManagerTests {
    private let saved = MeResponse(userId: 7, email: "me@example.com")

    private struct Harness {
        let auth: AuthManager
        let repo: FakeAuthRepository
        let session: FakeAuthSession
        let tokens: TokenStore
        let accounts: AuthAccountStore
    }

    /// - Parameters:
    ///   - hasSession: Keychain에 refresh 토큰이 있는가
    ///   - savedAccount: Keychain에 마지막 확인 계정이 있는가
    private func make(hasSession: Bool = true, savedAccount: MeResponse? = nil) async -> Harness {
        let keychain = KeychainHelper(service: "test.captest1.auth.\(UUID().uuidString)")
        let tokens = TokenStore(keychain: keychain)
        if hasSession { await tokens.save(access: "a1", refresh: "r1") }
        let accounts = AuthAccountStore(keychain: keychain)
        if let savedAccount { accounts.save(savedAccount) }
        let repo = FakeAuthRepository()
        let session = FakeAuthSession()
        let auth = AuthManager(repository: repo, session: session, tokenStore: tokens, accountStore: accounts)
        return Harness(auth: auth, repo: repo, session: session, tokens: tokens, accounts: accounts)
    }

    private func cleanup(_ h: Harness) async {
        h.accounts.clear()
        await h.tokens.clear()
    }

    // MARK: - 부팅

    @Test func bootstrap_success_entersAndSavesAccount() async {
        let h = await make()
        await h.auth.bootstrap()
        #expect(h.auth.state == .authenticated(saved))
        #expect(h.auth.isOfflineSession == false)
        #expect(h.accounts.load() == saved)
        await cleanup(h)
    }

    @Test func bootstrap_networkError_withSavedAccount_entersOffline_keepsTokens() async {
        let h = await make(savedAccount: saved)
        h.repo.refreshError = APIError.network
        await h.auth.bootstrap()
        #expect(h.auth.state == .authenticated(saved))
        #expect(h.auth.isOfflineSession == true)
        #expect(h.auth.lastError == nil)
        // 온라인이 되면 APIClient가 이 토큰으로 refresh를 시도해야 한다 — 지우지 않는다
        #expect(await h.tokens.refreshToken == "r1")
        await cleanup(h)
    }

    @Test func bootstrap_networkErrorOnMe_withSavedAccount_entersOffline() async {
        let h = await make(savedAccount: saved)
        h.repo.meResult = .failure(APIError.network)
        await h.auth.bootstrap()
        #expect(h.auth.state == .authenticated(saved))
        #expect(h.auth.isOfflineSession == true)
        await cleanup(h)
    }

    @Test func bootstrap_networkError_withoutSavedAccount_showsLogin() async {
        let h = await make(savedAccount: nil)
        h.repo.refreshError = APIError.network
        await h.auth.bootstrap()
        #expect(h.auth.state == .unauthenticated)
        #expect(h.auth.lastError == .offlineBootstrap)
        #expect(await h.tokens.refreshToken == "r1")
        await cleanup(h)
    }

    @Test func bootstrap_noSession_ignoresSavedAccount() async {
        let h = await make(hasSession: false, savedAccount: saved)
        await h.auth.bootstrap()
        #expect(h.auth.state == .unauthenticated)
        #expect(h.repo.calls.isEmpty)
        await cleanup(h)
    }

    @Test func bootstrap_invalidRefreshToken_logsOutAndClearsAccount() async {
        // 서버 판정(토큰 무효)은 오프라인 진입보다 우선 — 저장 계정이 있어도 들어가지 않는다
        let h = await make(savedAccount: saved)
        h.repo.refreshError = APIError.invalidRefreshToken
        await h.auth.bootstrap()
        #expect(h.auth.state == .unauthenticated)
        #expect(h.accounts.load() == nil)
        #expect(await h.tokens.refreshToken == nil)
        await cleanup(h)
    }

    @Test func bootstrap_serverError_doesNotEnterOffline() async {
        // 네트워크 오류만 오프라인 진입. 서버가 응답했는데 실패한 경우는 기존대로 로그인 화면
        let h = await make(savedAccount: saved)
        h.repo.refreshError = APIError.serverError
        await h.auth.bootstrap()
        #expect(h.auth.state == .unauthenticated)
        #expect(h.auth.isOfflineSession == false)
        await cleanup(h)
    }

    // MARK: - 오프라인 진입 뒤 온라인 복귀

    @Test func offline_thenServerRejectsSession_logsOutAndClearsAccount() async throws {
        // 온라인이 되어 첫 요청이 401 → APIClient refresh 실패 → 세션 만료 핸들러(기존 흐름)
        let h = await make(savedAccount: saved)
        h.repo.refreshError = APIError.network
        await h.auth.bootstrap()
        #expect(h.auth.isOfflineSession == true)

        await h.session.fireSessionExpired()
        try await waitUntil { h.auth.state == .unauthenticated }
        #expect(h.auth.isOfflineSession == false)
        #expect(h.auth.lastError == APIError.sessionExpired.toUserMessage())
        #expect(h.accounts.load() == nil)
        #expect(await h.tokens.refreshToken == nil)
        await cleanup(h)
    }

    @Test func offline_thenNextLaunchOnline_verifiesAndClearsOfflineFlag() async {
        let h = await make(savedAccount: saved)
        h.repo.refreshError = APIError.network
        await h.auth.bootstrap()
        #expect(h.auth.isOfflineSession == true)

        // 서버가 돌아온 다음 실행: 같은 Keychain으로 새 AuthManager가 정상 확인한다
        let online = AuthManager(repository: FakeAuthRepository(), session: FakeAuthSession(),
                                 tokenStore: h.tokens, accountStore: h.accounts)
        await online.bootstrap()
        #expect(online.state == .authenticated(saved))
        #expect(online.isOfflineSession == false)
        await cleanup(h)
    }

    // MARK: - 로그인·로그아웃

    @Test func login_savesAccount_logoutClearsIt() async {
        let h = await make(hasSession: false)
        await h.auth.login(email: "me@example.com", password: "pw")
        #expect(h.auth.state == .authenticated(saved))
        #expect(h.accounts.load() == saved)

        await h.auth.logout()
        #expect(h.auth.state == .unauthenticated)
        #expect(h.accounts.load() == nil)
        #expect(await h.tokens.refreshToken == nil)
        await cleanup(h)
    }

    @Test func logout_fromOfflineSession_clearsAccount() async {
        let h = await make(savedAccount: saved)
        h.repo.refreshError = APIError.network
        await h.auth.bootstrap()
        await h.auth.logout()
        #expect(h.auth.state == .unauthenticated)
        #expect(h.auth.isOfflineSession == false)
        #expect(h.accounts.load() == nil)
        await cleanup(h)
    }

    /// handleSessionExpired는 Task로 정리하므로 상태가 바뀔 때까지 잠깐 기다린다.
    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("조건을 기다리다 시간 초과")
    }
}
