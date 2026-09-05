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

nonisolated struct MeResponse: Decodable, Equatable, Sendable {
    let userId: Int64
    let email: String
}

// MARK: - Server Errors

nonisolated struct ServerFieldError: Decodable, Equatable, Sendable {
    let field: String
    let message: String
}

// MARK: - APIError

enum APIError: Error, Equatable, Sendable {
    case emailAlreadyExists
    case invalidCredentials
    case invalidRefreshToken
    /// 서버 UNAUTHORIZED·FORBIDDEN (시큐리티 필터 단계). 인증 요청은 refresh 재시도 후에도 401이면 도달.
    case unauthorized
    case validationFailed(fields: [ServerFieldError])
    case malformedRequest
    /// 서버 INVALID_PARAMETER (쿼리·경로 파라미터 형식 오류)
    case invalidParameter
    /// 서버 NOT_FOUND·CAFFEINE_RECORD_NOT_FOUND
    case notFound
    case serverError
    case sessionExpired
    case network
    case decoding
    /// 매핑되지 않은 코드(METHOD_NOT_ALLOWED·UNSUPPORTED_MEDIA_TYPE·HTTP_{status} 등). 서버 message를 그대로 보관.
    case unknown(statusCode: Int, message: String?)

    /// 서버 `global/error/ErrorCode` 전 항목 매핑 (2026-09-05 기준 13개).
    init(serverCode: String, message: String?, fieldErrors: [ServerFieldError]?, statusCode: Int) {
        switch serverCode {
        case "EMAIL_ALREADY_EXISTS": self = .emailAlreadyExists
        case "INVALID_CREDENTIALS": self = .invalidCredentials
        case "INVALID_REFRESH_TOKEN": self = .invalidRefreshToken
        case "UNAUTHORIZED", "FORBIDDEN": self = .unauthorized
        case "VALIDATION_FAILED": self = .validationFailed(fields: fieldErrors ?? [])
        case "MALFORMED_JSON": self = .malformedRequest
        case "INVALID_PARAMETER": self = .invalidParameter
        case "NOT_FOUND", "CAFFEINE_RECORD_NOT_FOUND": self = .notFound
        case "INTERNAL_ERROR": self = .serverError
        default: self = .unknown(statusCode: statusCode, message: message)
        }
    }
}

// MARK: - User-facing message

struct AuthErrorMessage: Equatable {
    let title: String
    let body: String
    let fieldMessages: [String: String]

    static let offlineBootstrap = AuthErrorMessage(
        title: "연결 확인",
        body: "인터넷 연결을 확인하고 다시 로그인해주세요.",
        fieldMessages: [:]
    )
}

extension APIError {
    func toUserMessage() -> AuthErrorMessage {
        switch self {
        case .emailAlreadyExists:
            return AuthErrorMessage(
                title: "가입 실패",
                body: "이미 사용 중인 이메일이에요.",
                fieldMessages: ["email": "이미 사용 중인 이메일이에요"]
            )
        case .invalidCredentials:
            return AuthErrorMessage(
                title: "로그인 실패",
                body: "이메일 또는 비밀번호가 올바르지 않아요.",
                fieldMessages: [:]
            )
        case .invalidRefreshToken, .sessionExpired, .unauthorized:
            return AuthErrorMessage(
                title: "다시 로그인",
                body: "세션이 만료되었어요. 다시 로그인해주세요.",
                fieldMessages: [:]
            )
        case .validationFailed(let fields):
            var map: [String: String] = [:]
            for f in fields { map[f.field] = f.message }
            return AuthErrorMessage(
                title: "입력값 확인",
                body: "입력 내용을 다시 확인해주세요.",
                fieldMessages: map
            )
        case .malformedRequest, .invalidParameter:
            return AuthErrorMessage(
                title: "요청 오류",
                body: "요청 형식이 잘못되었어요. 앱을 업데이트해주세요.",
                fieldMessages: [:]
            )
        case .notFound:
            return AuthErrorMessage(
                title: "찾을 수 없음",
                body: "요청한 항목을 찾을 수 없어요. 새로고침해주세요.",
                fieldMessages: [:]
            )
        case .serverError:
            return AuthErrorMessage(
                title: "서버 오류",
                body: "서버에 문제가 생겼어요. 잠시 후 다시 시도해주세요.",
                fieldMessages: [:]
            )
        case .network:
            return AuthErrorMessage(
                title: "연결 오류",
                body: "인터넷 연결을 확인해주세요.",
                fieldMessages: [:]
            )
        case .decoding:
            return AuthErrorMessage(
                title: "응답 오류",
                body: "서버 응답을 처리하지 못했어요. 잠시 후 다시 시도해주세요.",
                fieldMessages: [:]
            )
        case .unknown(_, let message):
            return AuthErrorMessage(
                title: "알 수 없는 오류",
                body: message ?? "알 수 없는 오류가 발생했어요.",
                fieldMessages: [:]
            )
        }
    }
}
