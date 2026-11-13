//
//  APIError+UserMessage.swift
//  captest1
//
//  APIError의 사용자용 제목·본문. 여러 기능이 같은 문구를 쓰도록 Core에 둔다(로그인 화면은 Auth의 toUserMessage가 이 값을 쓴다).
//  내부 오류명(localizedDescription의 "captest1.APIError 오류 11.")을 화면에 내보내지 않기 위해서다.
//

import Foundation

extension APIError {
    var userTitle: String {
        switch self {
        case .emailAlreadyExists: "가입 실패"
        case .invalidCredentials: "로그인 실패"
        case .invalidRefreshToken, .sessionExpired, .unauthorized: "다시 로그인"
        case .validationFailed: "입력값 확인"
        case .malformedRequest, .invalidParameter: "요청 오류"
        case .notFound: "찾을 수 없음"
        case .serverError: "서버 오류"
        case .network: "서버에 연결할 수 없어요"
        case .decoding: "응답 오류"
        case .unknown: "알 수 없는 오류"
        }
    }

    var userBody: String {
        switch self {
        case .emailAlreadyExists: "이미 사용 중인 이메일이에요."
        case .invalidCredentials: "이메일 또는 비밀번호가 올바르지 않아요."
        case .invalidRefreshToken, .sessionExpired, .unauthorized: "세션이 만료되었어요. 다시 로그인해주세요."
        case .validationFailed: "입력 내용을 다시 확인해주세요."
        case .malformedRequest, .invalidParameter: "요청 형식이 잘못되었어요. 앱을 업데이트해주세요."
        case .notFound: "요청한 항목을 찾을 수 없어요. 새로고침해주세요."
        case .serverError: "서버에 문제가 생겼어요. 잠시 후 다시 시도해주세요."
        case .network: "인터넷 연결을 확인하거나 잠시 후 다시 시도해주세요."
        case .decoding: "서버 응답을 처리하지 못했어요. 잠시 후 다시 시도해주세요."
        case .unknown(_, let message): message ?? "알 수 없는 오류가 발생했어요."
        }
    }
}
