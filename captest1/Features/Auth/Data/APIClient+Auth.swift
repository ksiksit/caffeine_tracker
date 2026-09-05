//
//  APIClient+Auth.swift
//  captest1
//

import Foundation

extension APIClient: AuthRepository {
    func login(_ req: LoginRequest) async throws -> TokenResponse {
        try await post(path: "/api/auth/login", body: req, authenticated: false)
    }

    func signup(_ req: SignupRequest) async throws -> SignupResponse {
        try await post(path: "/api/auth/signup", body: req, authenticated: false)
    }

    /// 401 재시도 경로(APIClient 본체 performRefresh)도 이 메서드를 쓴다.
    func refresh(refreshToken token: String) async throws -> TokenResponse {
        let tokens: TokenResponse = try await post(
            path: "/api/auth/refresh",
            body: RefreshTokenRequest(refreshToken: token),
            authenticated: false
        )
        await applyTokens(tokens)
        return tokens
    }

    func logout(refreshToken token: String) async throws {
        try await postNoContent(path: "/api/auth/logout", body: LogoutRequest(refreshToken: token))
    }

    func me() async throws -> MeResponse {
        try await get(path: "/api/me")
    }
}
