//
//  PreviewAuthRepository.swift
//  captest1
//
//  #Preview용 인증 페이크. 네트워크·Keychain 없이 고정 응답.
//

#if DEBUG
import Foundation

nonisolated struct PreviewAuthRepository: AuthRepository {
    func login(_ req: LoginRequest) async throws -> TokenResponse { Self.tokens }
    func signup(_ req: SignupRequest) async throws -> SignupResponse {
        SignupResponse(userId: 1, email: req.email, nickname: req.nickname)
    }
    func refresh(refreshToken: String) async throws -> TokenResponse { Self.tokens }
    func logout(refreshToken: String) async throws {}
    func me() async throws -> MeResponse { MeResponse(userId: 1, email: "preview@example.com") }

    private static let tokens = TokenResponse(
        accessToken: "preview-access", refreshToken: "preview-refresh",
        tokenType: "Bearer", expiresIn: 3600, refreshExpiresIn: 1_209_600
    )
}

nonisolated struct PreviewAuthSession: AuthSession {
    func setAccessToken(_ token: String?) async {}
    func setRefreshToken(_ token: String?) async {}
    func setSessionExpiredHandler(_ handler: (@Sendable () async -> Void)?) async {}
    func cancelRefresh() async {}
}
#endif
