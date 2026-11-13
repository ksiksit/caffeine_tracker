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

    /// 카페 근처 알림 이후 서버(api.md 알림 절 예시).
    private static let planWithCafeNearbyJSON = """
    { "success": true, "data": { "now": "2026-06-01T05:00:00Z", "items": [], "cafeNearbyWindows": [
      { "reason": "CUTOFF_PASSED", "activeFrom": "2026-06-01T11:04:30.675Z", "activeUntil": "2026-06-01T20:00:00Z", "title": "카페 근처예요", "body": "오늘 마감 20:04이 지났어요. 지금 75mg 한 잔이면 취침 때 기준(50mg)을 넘어요. 들어간다면 디카페인으로!" },
      { "reason": "CUTOFF_PASSED", "activeFrom": "2026-06-02T11:04:30.675Z", "activeUntil": "2026-06-02T20:00:00Z", "title": "카페 근처예요", "body": "b" }
    ] }, "error": null, "message": null }
    """

    private static let settingsWithCafeNearbyJSON = """
    { "success": true, "data": { "halfLife": 5.0, "condition": 0, "bedtimeHour": 23, "bedtimeMinute": 0, "referenceDoseMg": 75, "isLearningEnabled": true, "learnedMean": 5.0, "learnedVariance": 2.25, "lastLearnedDate": null, "inferredBaseHalfLife": 5.0, "effectiveHalfLifeHours": 5.0, "notifications": { "cutoff": true, "bedtimeResidual": true, "recordReminder": true, "cafeNearby": true } }, "error": null, "message": null }
    """

    /// 서버 api.md 인사이트 절 caffeine-sleep 예시(2c89425) 그대로.
    private static let caffeineSleepJSON = """
    { "success": true, "data": {
      "from": "2026-06-01", "to": "2026-06-14", "nightCount": 12, "sufficient": true,
      "residualThresholdMg": 50.0, "halfLifeHoursUsed": 5.0,
      "residualComparison": {
        "high": { "nightCount": 5, "solNightCount": 5, "avgSolMinutes": 27.0, "avgSleepEfficiency": 0.86, "avgTotalSleepMinutes": 402.0, "avgDeepSleepRatio": 0.14 },
        "low": { "nightCount": 7, "solNightCount": 7, "avgSolMinutes": 16.0, "avgSleepEfficiency": 0.9, "avgTotalSleepMinutes": 431.0, "avgDeepSleepRatio": 0.17 },
        "sufficient": true, "moreNightsNeeded": null, "solDiffMinutes": 11.0, "efficiencyDiff": -0.04,
        "sentence": "취침 때 카페인이 50mg 이상 남아 있던 밤은 잠드는 데 평균 11분 더 걸렸고, 수면 효율은 4%p 낮았어요 (5밤 vs 7밤)"
      },
      "cutoffComparison": {
        "high": { "nightCount": 2, "solNightCount": 2, "avgSolMinutes": 30.0, "avgSleepEfficiency": 0.85, "avgTotalSleepMinutes": 395.0, "avgDeepSleepRatio": 0.13 },
        "low": { "nightCount": 8, "solNightCount": 8, "avgSolMinutes": 18.0, "avgSleepEfficiency": 0.89, "avgTotalSleepMinutes": 425.0, "avgDeepSleepRatio": 0.16 },
        "sufficient": false, "moreNightsNeeded": 1, "solDiffMinutes": null, "efficiencyDiff": null,
        "sentence": "지금 기준 용량(75mg)으로 따지면, 마감을 넘긴 밤이 1밤 더 있어야 비교할 수 있어요"
      },
      "headlines": [ "취침 때 카페인이 50mg 이상 남아 있던 밤은 잠드는 데 평균 11분 더 걸렸고, 수면 효율은 4%p 낮았어요 (5밤 vs 7밤)" ],
      "nights": [
        { "date": "2026-06-02", "bedtime": "2026-06-01T14:00:00Z", "residualAtBedtimeMg": 114.87, "dayTotalMg": 200.0, "lastIntakeAt": "2026-06-01T10:00:00Z", "cutoffKept": false, "solMinutes": 30.0, "sleepEfficiency": 0.9375, "totalSleepMinutes": 450.0, "deepSleepRatio": null }
      ]
    }, "error": null, "message": null }
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

    @Test func notificationPlan_withoutCafeNearbyWindows_decodesAsEmpty() async throws {
        // 카페 근처 알림 이전 서버 응답(planJSON에는 cafeNearbyWindows가 없다).
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { _ in .init(status: 200, json: Self.planJSON) }
        let plan = try await makeClient().plan(now: Date(), timeZone: TimeZone(identifier: "Asia/Seoul")!)
        #expect(plan.cafeNearbyWindows.isEmpty)
    }

    @Test func notificationPlan_decodesCafeNearbyWindows() async throws {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { _ in .init(status: 200, json: Self.planWithCafeNearbyJSON) }
        let plan = try await makeClient().plan(now: Date(), timeZone: TimeZone(identifier: "Asia/Seoul")!)
        #expect(plan.cafeNearbyWindows.count == 2)
        let first = try #require(plan.cafeNearbyWindows.first)
        #expect(first.reason == "CUTOFF_PASSED")
        #expect(first.title == "카페 근처예요")
        #expect(first.activeUntil == Date(timeIntervalSince1970: 1_780_344_000))   // 2026-06-01T20:00:00Z
        #expect(first.activeFrom < first.activeUntil)
    }

    @Test func settings_withoutCafeNearby_decodesAsOff() async throws {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { _ in .init(status: 200, json: Self.settingsJSON) }
        let settings = try await makeClient().settings()
        #expect(settings.notifications.cafeNearby == false)
    }

    @Test func settings_decodesCafeNearby() async throws {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { _ in .init(status: 200, json: Self.settingsWithCafeNearbyJSON) }
        let settings = try await makeClient().settings()
        #expect(settings.notifications.cafeNearby == true)
    }

    @Test func notificationSettings_alwaysEncodesCafeNearby() throws {
        // 서버는 cafeNearby를 생략하면 기존 값을 유지한다 — 앱은 끈 것도 전하려고 항상 싣는다.
        let data = try JSONEncoder().encode(NotificationSettingsDTO(cutoff: true, bedtimeResidual: false,
                                                                     recordReminder: true, cafeNearby: false))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Bool])
        #expect(object == ["cutoff": true, "bedtimeResidual": false, "recordReminder": true, "cafeNearby": false])
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

    @Test func retryNetworkFailure_afterRefresh_keepsSession() async {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { request in
            let auth = request.value(forHTTPHeaderField: "Authorization")
            switch request.url?.path {
            case "/api/auth/refresh":
                return .init(status: 200, json: #"{ "success": true, "data": { "accessToken": "new-access", "refreshToken": "new-refresh", "tokenType": "Bearer", "expiresIn": 3600, "refreshExpiresIn": 1209600 }, "error": null, "message": null }"#)
            case "/api/me" where auth == "Bearer new-access":
                return .networkFailure
            default:
                return .init(status: 401, json: Self.unauthorizedJSON)
            }
        }
        let client = makeClient()
        let expired = Locked(wrappedValue: false)
        await client.setSessionExpiredHandler { expired.wrappedValue = true }
        await client.setAccessToken("old-access")
        await client.setRefreshToken("r1")

        await #expect(throws: APIError.network) {
            try await client.me()
        }
        #expect(expired.wrappedValue == false)
    }

    @Test func refreshNetworkFailure_keepsSession() async {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { request in
            if request.url?.path == "/api/auth/refresh" { return .networkFailure }
            return .init(status: 401, json: Self.unauthorizedJSON)
        }
        let client = makeClient()
        let expired = Locked(wrappedValue: false)
        await client.setSessionExpiredHandler { expired.wrappedValue = true }
        await client.setAccessToken("old-access")
        await client.setRefreshToken("r1")

        await #expect(throws: APIError.network) {
            try await client.me()
        }
        #expect(expired.wrappedValue == false)
    }

    // MARK: - 인사이트

    @Test func caffeineSleep_decodesApiDocExample_andSendsPeriod() async throws {
        defer { StubURLProtocol.reset() }
        StubURLProtocol.install { _ in .init(status: 200, json: Self.caffeineSleepJSON) }

        let report = try await makeClient().caffeineSleepReport(
            from: "2026-06-01", to: "2026-06-14", timeZone: TimeZone(identifier: "Asia/Seoul")!)

        #expect(report.residualThresholdMg == 50)
        #expect(report.cutoffComparison.moreNightsNeeded == 1)
        #expect(report.cutoffComparison.solDiffMinutes == nil)
        let night = try #require(report.nights.first)
        #expect(night.date == "2026-06-02")
        #expect(night.residualAtBedtimeMg == 114.87)
        #expect(night.dayTotalMg == 200)
        #expect(night.solMinutes == 30)
        #expect(night.cutoffKept == false)
        #expect(night.deepSleepRatio == nil)
        #expect(night.bedtime == Date(timeIntervalSince1970: 1_780_322_400))
        let request = StubURLProtocol.requests.first?.url
        #expect(request?.path == "/api/insight/caffeine-sleep")
        let query = request?.query ?? ""
        #expect(query.contains("from=2026-06-01"))
        #expect(query.contains("to=2026-06-14"))
        #expect(query.contains("tz=Asia/Seoul"))
    }
}
