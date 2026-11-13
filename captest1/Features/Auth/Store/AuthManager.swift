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
    /// 서버에 닿지 못해 저장된 계정으로 들어온 상태. 서버 확인이 아니라 기기 사본 기준이다.
    private(set) var isOfflineSession = false

    private let repository: any AuthRepository
    private let session: any AuthSession
    private let tokenStore: TokenStore
    /// nil이면 계정을 기기에 저장하지 않는다(미리보기). 그때 오프라인 진입도 없다.
    private let accountStore: AuthAccountStore?
    private var isLoggingOut: Bool = false

    init(repository: any AuthRepository, session: any AuthSession, tokenStore: TokenStore,
         accountStore: AuthAccountStore? = nil) {
        self.repository = repository
        self.session = session
        self.tokenStore = tokenStore
        self.accountStore = accountStore
    }

    #if DEBUG
    /// 디버그 빌드 전용: 서버 없이 로그인 화면을 넘어가 나머지 화면을 본다.
    /// 토큰이 없으므로 서버를 부르는 화면은 오류를 보여준다.
    func skipLoginForDebug() {
        lastError = nil
        state = .authenticated(MeResponse(userId: 0, email: "debug@local"))
    }
    #endif

    /// 앱 시작 시 자동 로그인 시도
    func bootstrap() async {
        await installSessionExpiredHandler()
        let refresh = await tokenStore.refreshToken
        guard let refresh else {
            state = .unauthenticated
            return
        }

        do {
            _ = try await repository.refresh(refreshToken: refresh)
            let me = try await repository.me()
            if finishBootstrap(.authenticated(me)) {
                accountStore?.save(me)
            }
        } catch APIError.invalidRefreshToken, APIError.sessionExpired {
            await tokenStore.clear()
            await session.setAccessToken(nil)
            await session.setRefreshToken(nil)
            accountStore?.clear()
            finishBootstrap(.unauthenticated)
        } catch APIError.network {
            // 오프라인 부팅: 토큰 보존. 서버가 확인해 준 계정이 기기에 있으면 그 계정으로 들어가 캐시를 보여 준다.
            // 토큰이 실제로 무효인지는 온라인이 되어 첫 요청이 401 → refresh 실패하면 세션 만료로 판정된다.
            if let saved = accountStore?.load() {
                if finishBootstrap(.authenticated(saved)) {
                    isOfflineSession = true
                }
            } else {
                finishBootstrap(.unauthenticated, error: .offlineBootstrap)
            }
        } catch {
            finishBootstrap(.unauthenticated)
        }
    }

    /// 자동 로그인 결과는 아직 확인 중일 때만 반영한다 — 그사이 사용자가 로그인했거나(디버그) 건너뛰었으면 덮어쓰지 않는다.
    /// 반영했으면 true.
    @discardableResult
    private func finishBootstrap(_ newState: AuthState, error: AuthErrorMessage? = nil) -> Bool {
        guard state == .checking else { return false }
        state = newState
        if let error { lastError = error }
        return true
    }

    /// 로그인·가입 후 서버가 확인한 계정으로 들어간다.
    private func enter(_ me: MeResponse) {
        accountStore?.save(me)
        isOfflineSession = false
        state = .authenticated(me)
    }

    func login(email: String, password: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let tokens = try await repository.login(LoginRequest(email: email, password: password))
            await tokenStore.save(access: tokens.accessToken, refresh: tokens.refreshToken)
            await session.setAccessToken(tokens.accessToken)
            await session.setRefreshToken(tokens.refreshToken)
            await installSessionExpiredHandler()
            isLoggingOut = false
            enter(try await repository.me())
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
            _ = try await repository.signup(SignupRequest(email: email, password: password, nickname: nickname))
        } catch let error as APIError {
            lastError = error.toUserMessage()
            return
        } catch {
            lastError = APIError.network.toUserMessage()
            return
        }

        // signup 성공 → 자동 로그인 (isProcessing 가드를 우회하기 위해 내부 직접 호출)
        do {
            let tokens = try await repository.login(LoginRequest(email: email, password: password))
            await tokenStore.save(access: tokens.accessToken, refresh: tokens.refreshToken)
            await session.setAccessToken(tokens.accessToken)
            await session.setRefreshToken(tokens.refreshToken)
            await installSessionExpiredHandler()
            isLoggingOut = false
            enter(try await repository.me())
        } catch let error as APIError {
            lastError = error.toUserMessage()
        } catch {
            lastError = APIError.network.toUserMessage()
        }
    }

    func logout() async {
        isLoggingOut = true
        await session.setSessionExpiredHandler(nil)
        await session.cancelRefresh()

        if let refresh = await tokenStore.refreshToken {
            // best-effort. 실패해도 로컬 정리는 진행
            _ = try? await repository.logout(refreshToken: refresh)
        }

        await tokenStore.clear()
        await session.setAccessToken(nil)
        await session.setRefreshToken(nil)
        accountStore?.clear()
        isOfflineSession = false
        state = .unauthenticated
        lastError = nil
        isLoggingOut = false
    }

    /// 전송층(AuthSession)이 refresh 실패를 감지하면 호출
    func handleSessionExpired() {
        guard !isLoggingOut else { return }
        Task {
            await tokenStore.clear()
            await session.setAccessToken(nil)
            await session.setRefreshToken(nil)
            accountStore?.clear()
            isOfflineSession = false
            state = .unauthenticated
            lastError = APIError.sessionExpired.toUserMessage()
        }
    }

    func clearError() {
        lastError = nil
    }

    private func installSessionExpiredHandler() async {
        await session.setSessionExpiredHandler { [weak self] in
            await self?.handleSessionExpired()
        }
    }
}
