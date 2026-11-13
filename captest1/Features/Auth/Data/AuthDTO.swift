//
//  AuthDTO.swift
//  captest1
//

import Foundation

// MARK: - Requests

nonisolated struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
}

nonisolated struct SignupRequest: Encodable, Sendable {
    let email: String
    let password: String
    let nickname: String
}

nonisolated struct RefreshTokenRequest: Encodable, Sendable {
    let refreshToken: String
}

nonisolated struct LogoutRequest: Encodable, Sendable {
    let refreshToken: String
}

// MARK: - Responses

nonisolated struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int64
    let refreshExpiresIn: Int64
}

nonisolated struct SignupResponse: Decodable, Sendable {
    let userId: Int64
    let email: String
    let nickname: String
}

/// Encodable은 마지막 확인 계정을 Keychain에 저장하려고 둔다(AuthAccountStore). 서버로 보내지 않는다.
nonisolated struct MeResponse: Codable, Equatable, Sendable {
    let userId: Int64
    let email: String
}

// MARK: - User-facing message

struct AuthErrorMessage: Equatable {
    let title: String
    let body: String
    let fieldMessages: [String: String]

    static let offlineBootstrap = AuthErrorMessage(
        title: "서버에 연결할 수 없어요",
        body: "인터넷 연결을 확인하거나 잠시 후 다시 로그인해주세요.",
        fieldMessages: [:]
    )
}

extension APIError {
    /// 제목·본문은 Core(APIError+UserMessage)의 공용 문구. 로그인 화면만 쓰는 필드별 문구를 덧붙인다.
    func toUserMessage() -> AuthErrorMessage {
        let fields: [String: String]
        switch self {
        case .emailAlreadyExists:
            fields = ["email": "이미 사용 중인 이메일이에요"]
        case .validationFailed(let list):
            var map: [String: String] = [:]
            for f in list { map[f.field] = f.message }
            fields = map
        default:
            fields = [:]
        }
        return AuthErrorMessage(title: userTitle, body: userBody, fieldMessages: fields)
    }
}
