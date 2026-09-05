//
//  AuthRepository.swift
//  captest1
//
//  인증 도메인 포트(서버 domain/auth · domain/user). 구현은 같은 폴더의 전송층 확장, 미리보기는 PreviewAuthRepository.
//

import Foundation

nonisolated protocol AuthRepository: Sendable {
    func login(_ req: LoginRequest) async throws -> TokenResponse
    func signup(_ req: SignupRequest) async throws -> SignupResponse
    /// 새 토큰 쌍을 받아 세션에 반영까지 한다(회전: 기존 refresh는 서버에서 폐기됨).
    func refresh(refreshToken: String) async throws -> TokenResponse
    func logout(refreshToken: String) async throws
    func me() async throws -> MeResponse
}
