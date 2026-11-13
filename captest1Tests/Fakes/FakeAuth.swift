//
//  FakeAuth.swift
//  captest1Tests
//
//  AuthManager 테스트용 인증 포트·세션 페이크.
//

import Foundation
@testable import captest1

final class FakeAuthRepository: AuthRepository, @unchecked Sendable {
    @Locked var refreshError: Error? = nil
    @Locked var meResult: Result<MeResponse, Error> = .success(MeResponse(userId: 7, email: "me@example.com"))
    @Locked var loginError: Error? = nil
    /// 호출 순서: "login" / "signup" / "refresh" / "logout" / "me"
    @Locked private(set) var calls: [String] = []

    private static let tokens = TokenResponse(accessToken: "a2", refreshToken: "r2", tokenType: "Bearer",
                                              expiresIn: 900, refreshExpiresIn: 86_400)

    func login(_ req: LoginRequest) async throws -> TokenResponse {
        $calls.mutate { $0.append("login") }
        if let loginError { throw loginError }
        return Self.tokens
    }

    func signup(_ req: SignupRequest) async throws -> SignupResponse {
        $calls.mutate { $0.append("signup") }
        return SignupResponse(userId: 7, email: req.email, nickname: req.nickname)
    }

    func refresh(refreshToken: String) async throws -> TokenResponse {
        $calls.mutate { $0.append("refresh") }
        if let refreshError { throw refreshError }
        return Self.tokens
    }

    func logout(refreshToken: String) async throws {
        $calls.mutate { $0.append("logout") }
    }

    func me() async throws -> MeResponse {
        $calls.mutate { $0.append("me") }
        return try meResult.get()
    }
}

/// 전송층 세션 페이크. 세션 만료 핸들러를 잡아 두었다가 테스트가 직접 부른다(APIClient가 refresh 실패를 감지한 상황).
final class FakeAuthSession: AuthSession, @unchecked Sendable {
    @Locked private(set) var accessToken: String? = nil
    @Locked private(set) var refreshToken: String? = nil
    @Locked private(set) var expiredHandler: (@Sendable () async -> Void)? = nil

    func setAccessToken(_ token: String?) async { accessToken = token }
    func setRefreshToken(_ token: String?) async { refreshToken = token }
    func setSessionExpiredHandler(_ handler: (@Sendable () async -> Void)?) async { expiredHandler = handler }
    func cancelRefresh() async {}

    func fireSessionExpired() async {
        await expiredHandler?()
    }
}
