//
//  APIEnvelope.swift
//  captest1
//
//  서버 공통 응답 봉투(서버 global/web/ApiResponse). 키 4개는 값이 없어도 항상 존재한다.
//  성공: { success: true,  data: <payload>, error: null, message: null }
//  실패: { success: false, data: null, error: { code, fieldErrors? }, message: "<사용자용 문장>" }
//  바디 없는 성공(로그아웃·삭제)은 200 + data: null.
//

import Foundation

nonisolated struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: APIErrorBody?
    let message: String?
}

extension APIEnvelope: Sendable where T: Sendable {}

/// 봉투의 `error` 객체. `fieldErrors`는 VALIDATION_FAILED에만 있고 없으면 키 자체가 생략된다.
nonisolated struct APIErrorBody: Decodable, Sendable {
    let code: String
    let fieldErrors: [ServerFieldError]?
}

/// `data: null`인 응답(바디 없는 성공·실패 응답)을 봉투로 읽을 때 쓰는 자리표시자.
nonisolated struct EmptyPayload: Decodable, Sendable {}
