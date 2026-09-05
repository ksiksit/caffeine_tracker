//
//  APIError.swift
//  captest1
//
//  서버 응답 봉투의 error.code를 앱 에러로 매핑한다. 사용자 문구는 Features/Auth/AuthDTO.swift의 toUserMessage().
//

import Foundation

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
