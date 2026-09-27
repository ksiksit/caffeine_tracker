//
//  APIClientEnvelopeTests.swift
//  captest1Tests
//
//  서버 공통 응답 봉투({success,data,error,message}) 처리 검증. 예시 JSON은 서버 docs/api.md의 것을 그대로 썼다.
//

import Foundation
import Testing
@testable import captest1

@Suite(.serialized)
struct APIClientEnvelopeTests {

    private func makeClient() -> APIClient {
        let keychain = KeychainHelper(service: "test.captest1.envelope")
        let tokenStore = TokenStore(keychain: keychain)
        return APIClient(
            baseURL: URL(string: "http://stub.local")!,
            tokenStore: tokenStore,
            session: StubURLProtocol.makeSession()
        )
    }

    private static let settingsJSON = """
    { "success": true, "data": { "halfLife": 5.0, "condition": 0, "bedtimeHour": 23, "bedtimeMinute": 0, "referenceDoseMg": 75, "isLearningEnabled": true, "learnedMean": 5.0, "learnedVariance": 2.25, "lastLearnedDate": null, "inferredBaseHalfLife": 5.0, "effectiveHalfLifeHours": 5.0, "notifications": { "cutoff": true, "bedtimeResidual": true, "recordReminder": true } }, "error": null, "message": null }
    """

    private static let planJSON = """
    { "success": true, "data": { "now": "2026-06-01T05:00:00Z", "items": [
      { "type": "CUTOFF", "fireAt": "2026-06-01T10:34:30.675Z", "title": "섭취 마감 30분 전", "body": "23:00 취침 기준, 75mg를 마실 수 있는 마지막 시각은 20:04이에요." }
    ] }, "error": null, "message": null }
    """

    private static let unauthorizedJSON = #"{ "success": false, "data": null, "error": { "code": "UNAUTHORIZED" }, "message": "인증이 필요합니다." }"#

    @Test func successEnvelope_returnsPayload() async throws {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { _ in
            .init(status: 200, json: #"{ "success": true, "data": { "userId": 1, "email": "user@example.com" }, "error": null, "message": null }"#)
        }
        let me = try await makeClient().me()
        #expect(me == MeResponse(userId: 1, email: "user@example.com"))
    }

    @Test func failureEnvelope_mapsErrorCode() async {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { _ in
            .init(status: 401, json: #"{ "success": false, "data": null, "error": { "code": "INVALID_CREDENTIALS" }, "message": "이메일 또는 비밀번호가 올바르지 않습니다." }"#)
        }
        await #expect(throws: APIError.invalidCredentials) {
            try await makeClient().login(LoginRequest(email: "a@b.com", password: "12345678"))
        }
    }

    @Test func validationFailure_carriesFieldErrors() async {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { _ in
            .init(status: 400, json: #"{ "success": false, "data": null, "error": { "code": "VALIDATION_FAILED", "fieldErrors": [ { "field": "email", "message": "must not be blank" } ] }, "message": "입력값이 올바르지 않습니다." }"#)
        }
        let expected = APIError.validationFailed(fields: [ServerFieldError(field: "email", message: "must not be blank")])
        await #expect(throws: expected) {
            try await makeClient().signup(SignupRequest(email: "", password: "12345678", nickname: "nick"))
        }
    }

    @Test func unmappedCode_keepsServerMessage() async {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { _ in
            .init(status: 405, json: #"{ "success": false, "data": null, "error": { "code": "METHOD_NOT_ALLOWED" }, "message": "허용되지 않은 HTTP 메서드입니다." }"#)
        }
        await #expect(throws: APIError.unknown(statusCode: 405, message: "허용되지 않은 HTTP 메서드입니다.")) {
            try await makeClient().me()
        }
    }

    @Test func noContentSuccess_withNullData_isAccepted() async throws {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { _ in
            .init(status: 200, json: #"{ "success": true, "data": null, "error": null, "message": null }"#)
        }
        try await makeClient().logout(refreshToken: "r1")
    }

    @Test func successEnvelope_withMissingPayload_isDecodingError() async {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { _ in
            .init(status: 200, json: #"{ "success": true, "data": null, "error": null, "message": null }"#)
        }
        await #expect(throws: APIError.decoding) {
            try await makeClient().me()
        }
    }

    @Test func notificationPlan_decodesItemsAndSendsNowAndTz() async throws {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { _ in .init(status: 200, json: Self.planJSON) }
        let now = Date(timeIntervalSince1970: 1_780_290_000)

        let plan = try await makeClient().plan(now: now, timeZone: TimeZone(identifier: "Asia/Seoul")!)

        #expect(plan.items.count == 1)
        #expect(plan.items.first?.type == "CUTOFF")
        #expect(plan.items.first?.title == "섭취 마감 30분 전")
        let query = StubURLProtocol.requests.first?.url?.query ?? ""
        #expect(StubURLProtocol.requests.first?.url?.path == "/api/notifications/plan")
        #expect(query.contains("tz=Asia/Seoul"))
        #expect(query.contains("now="))
    }

    @Test func settings_decodesNotificationToggles() async throws {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { _ in .init(status: 200, json: Self.settingsJSON) }
        let settings = try await makeClient().settings()
        #expect(settings.notifications == NotificationSettingsDTO(cutoff: true, bedtimeResidual: true, recordReminder: true))
    }

    @Test func unauthorized_refreshesOnceThenRetriesWithNewToken() async throws {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { request in
            let path = request.url?.path ?? ""
            let auth = request.value(forHTTPHeaderField: "Authorization")
            switch path {
            case "/api/auth/refresh":
                return .init(status: 200, json: #"{ "success": true, "data": { "accessToken": "new-access", "refreshToken": "new-refresh", "tokenType": "Bearer", "expiresIn": 3600, "refreshExpiresIn": 1209600 }, "error": null, "message": null }"#)
            case "/api/settings" where auth == "Bearer new-access":
                return .init(status: 200, json: Self.settingsJSON)
            default:
                return .init(status: 401, json: Self.unauthorizedJSON)
            }
        }
        let client = makeClient()
        await client.setAccessToken("old-access")
        await client.setRefreshToken("r1")

        let settings = try await client.settings()

        #expect(settings.halfLife == 5.0)
        let paths = StubURLProtocol.requests.map { $0.url?.path ?? "" }
        #expect(paths == ["/api/settings", "/api/auth/refresh", "/api/settings"])
        #expect(StubURLProtocol.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer new-access")
    }

    @Test func unauthorized_afterFailedRefresh_becomesSessionExpired() async {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { request in
            if request.url?.path == "/api/auth/refresh" {
                return .init(status: 401, json: #"{ "success": false, "data": null, "error": { "code": "INVALID_REFRESH_TOKEN" }, "message": "RefreshToken 이 유효하지 않습니다." }"#)
            }
            return .init(status: 401, json: Self.unauthorizedJSON)
        }
        let client = makeClient()
        await client.setAccessToken("old-access")
        await client.setRefreshToken("r1")
        await #expect(throws: APIError.sessionExpired) {
            try await client.me()
        }
    }
}
