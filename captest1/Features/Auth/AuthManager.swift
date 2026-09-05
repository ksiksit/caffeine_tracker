//
//  AuthManager.swift
//  captest1
//

import Foundation

@MainActor
@Observable
final class AuthManager {
    private(set) var state: AuthState = .checking
    var isProcessing: Bool = false
    var lastError: AuthErrorMessage?

    private let api: APIClient
    private let tokenStore: TokenStore
    private var isLoggingOut: Bool = false

    init(api: APIClient, tokenStore: TokenStore) {
        self.api = api
        self.tokenStore = tokenStore
    }

    /// 앱 시작 시 자동 로그인 시도
    func bootstrap() async {
        await installSessionExpiredHandler()
        let refresh = await tokenStore.refreshToken
        guard let refresh else {
            state = .unauthenticated
            return
        }

        do {
            _ = try await api.refresh(refreshToken: refresh)
            let me = try await api.getMe()
            state = .authenticated(me)
        } catch APIError.invalidRefreshToken, APIError.sessionExpired {
            await tokenStore.clear()
            await api.setAccessToken(nil)
            await api.setRefreshToken(nil)
            state = .unauthenticated
        } catch APIError.network {
            // 오프라인 부팅: 토큰 보존, 다음 시도에 재진입
            state = .unauthenticated
            lastError = .offlineBootstrap
        } catch {
            state = .unauthenticated
        }
    }

    func login(email: String, password: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let tokens = try await api.login(LoginRequest(email: email, password: password))
            await tokenStore.save(access: tokens.accessToken, refresh: tokens.refreshToken)
            await api.setAccessToken(tokens.accessToken)
            await api.setRefreshToken(tokens.refreshToken)
            await installSessionExpiredHandler()
            isLoggingOut = false
            let me = try await api.getMe()
            state = .authenticated(me)
        } catch let error as APIError {
            lastError = error.toUserMessage()
        } catch {
            lastError = APIError.network.toUserMessage()
        }
    }

    func signup(email: String, password: String, nickname: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            _ = try await api.signup(SignupRequest(email: email, password: password, nickname: nickname))
        } catch let error as APIError {
            lastError = error.toUserMessage()
            return
        } catch {
            lastError = APIError.network.toUserMessage()
            return
        }

        // signup 성공 → 자동 로그인 (isProcessing 가드를 우회하기 위해 내부 직접 호출)
        do {
            let tokens = try await api.login(LoginRequest(email: email, password: password))
            await tokenStore.save(access: tokens.accessToken, refresh: tokens.refreshToken)
            await api.setAccessToken(tokens.accessToken)
            await api.setRefreshToken(tokens.refreshToken)
            await installSessionExpiredHandler()
            isLoggingOut = false
            let me = try await api.getMe()
            state = .authenticated(me)
        } catch let error as APIError {
            lastError = error.toUserMessage()
        } catch {
            lastError = APIError.network.toUserMessage()
        }
    }

    func logout() async {
        isLoggingOut = true
        await api.setSessionExpiredHandler(nil)
        await api.cancelRefresh()

        if let refresh = await tokenStore.refreshToken {
            // best-effort. 실패해도 로컬 정리는 진행
            _ = try? await api.logout(refreshToken: refresh)
        }

        await tokenStore.clear()
        await api.setAccessToken(nil)
        await api.setRefreshToken(nil)
        state = .unauthenticated
        lastError = nil
        isLoggingOut = false
    }

    /// APIClient가 refresh 실패를 감지하면 호출
    func handleSessionExpired() {
        guard !isLoggingOut else { return }
        Task {
            await tokenStore.clear()
            await api.setAccessToken(nil)
            await api.setRefreshToken(nil)
            state = .unauthenticated
            lastError = APIError.sessionExpired.toUserMessage()
        }
    }

    func clearError() {
        lastError = nil
    }

    private func installSessionExpiredHandler() async {
        await api.setSessionExpiredHandler { [weak self] in
            await self?.handleSessionExpired()
        }
    }
}
