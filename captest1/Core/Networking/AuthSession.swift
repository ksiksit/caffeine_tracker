//
//  AuthSession.swift
//  captest1
//
//  전송층의 세션(토큰) 제어 포트. 인증 스토어(Features/Auth)가 APIClient 구체 타입 대신 이 프로토콜에 의존한다.
//

import Foundation

nonisolated protocol AuthSession: Sendable {
    func setAccessToken(_ token: String?) async
    func setRefreshToken(_ token: String?) async
    func setSessionExpiredHandler(_ handler: (@Sendable () async -> Void)?) async
    func cancelRefresh() async
}

extension APIClient: AuthSession {}
