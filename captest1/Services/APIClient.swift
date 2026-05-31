//
//  APIClient.swift
//  captest1
//

import Foundation

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: TokenStore

    private var accessToken: String?
    private var refreshToken: String?
    private var refreshTask: Task<TokenResponse, Error>?
    private var onSessionExpired: (@Sendable () async -> Void)?

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = ServerDateCoding.encoding
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = ServerDateCoding.decoding
        return d
    }()

    init(baseURL: URL, tokenStore: TokenStore, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session
    }

    // MARK: - Configuration

    func setAccessToken(_ token: String?) {
        accessToken = token
    }

    func setRefreshToken(_ token: String?) {
        refreshToken = token
    }

    func setSessionExpiredHandler(_ handler: (@Sendable () async -> Void)?) {
        onSessionExpired = handler
    }

    func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Public endpoints

    func login(_ req: LoginRequest) async throws -> TokenResponse {
        let request = try makeRequest(path: "/api/auth/login", method: "POST", body: req)
        return try await send(request, authenticated: false, decoding: TokenResponse.self)
    }

    func signup(_ req: SignupRequest) async throws -> SignupResponse {
        let request = try makeRequest(path: "/api/auth/signup", method: "POST", body: req)
        return try await send(request, authenticated: false, decoding: SignupResponse.self)
    }

    func refresh(refreshToken token: String) async throws -> TokenResponse {
        let request = try makeRequest(
            path: "/api/auth/refresh",
            method: "POST",
            body: RefreshTokenRequest(refreshToken: token)
        )
        let tokens = try await send(request, authenticated: false, decoding: TokenResponse.self)
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
        await tokenStore.save(access: tokens.accessToken, refresh: tokens.refreshToken)
        return tokens
    }

    func getMe() async throws -> MeResponse {
        let request = try makeRequest(path: "/api/me", method: "GET", body: Optional<Empty>.none)
        return try await send(request, authenticated: true, decoding: MeResponse.self)
    }

    func logout(refreshToken token: String) async throws {
        let request = try makeRequest(
            path: "/api/auth/logout",
            method: "POST",
            body: LogoutRequest(refreshToken: token)
        )
        try await sendNoContent(request, authenticated: true)
    }

    // MARK: - Caffeine endpoints

    func createCaffeineRecord(_ req: CreateCaffeineRecordRequest) async throws -> CaffeineRecordDTO {
        let request = try makeRequest(path: "/api/caffeine-records", method: "POST", body: req)
        return try await send(request, authenticated: true, decoding: CaffeineRecordDTO.self)
    }

    func updateCaffeineRecord(id: Int64, _ req: UpdateCaffeineRecordRequest) async throws -> CaffeineRecordDTO {
        let request = try makeRequest(path: "/api/caffeine-records/\(id)", method: "PUT", body: req)
        return try await send(request, authenticated: true, decoding: CaffeineRecordDTO.self)
    }

    func deleteCaffeineRecord(id: Int64) async throws {
        let request = try makeRequest(path: "/api/caffeine-records/\(id)", method: "DELETE", body: Optional<Empty>.none)
        try await sendNoContent(request, authenticated: true)
    }

    /// 오늘 현황(차트·잔량·마감시각)을 서버가 settings를 읽어 계산해 반환.
    func caffeineToday(now: Date = Date(), timeZone: TimeZone = .current) async throws -> CaffeineTodayResponse {
        let request = try makeRequest(
            path: "/api/caffeine/today",
            method: "GET",
            query: ["now": isoOffset(now), "tz": timeZone.identifier],
            body: Optional<Empty>.none
        )
        return try await send(request, authenticated: true, decoding: CaffeineTodayResponse.self)
    }

    // MARK: - Sleep endpoints

    func uploadSleepSamples(_ req: UploadSleepSamplesRequest) async throws -> UploadSleepSamplesResponse {
        let request = try makeRequest(path: "/api/sleep/samples", method: "POST", body: req)
        return try await send(request, authenticated: true, decoding: UploadSleepSamplesResponse.self)
    }

    /// date: "yyyy-MM-dd"(로컬 아침 기준). 서버가 전날 18시~당일 12시 윈도우를 병합·계산.
    func sleepSummary(date: String, timeZone: TimeZone = .current) async throws -> SleepSummaryResponse {
        let request = try makeRequest(
            path: "/api/sleep/summary",
            method: "GET",
            query: ["date": date, "tz": timeZone.identifier],
            body: Optional<Empty>.none
        )
        return try await send(request, authenticated: true, decoding: SleepSummaryResponse.self)
    }

    // MARK: - Settings endpoints

    func getSettings() async throws -> SettingsResponse {
        let request = try makeRequest(path: "/api/settings", method: "GET", body: Optional<Empty>.none)
        return try await send(request, authenticated: true, decoding: SettingsResponse.self)
    }

    func updateSettings(_ req: UpdateSettingsRequest) async throws -> SettingsResponse {
        let request = try makeRequest(path: "/api/settings", method: "PUT", body: req)
        return try await send(request, authenticated: true, decoding: SettingsResponse.self)
    }

    // MARK: - Internals

    private struct Empty: Encodable {}

    /// ISO-8601 + 오프셋 문자열. 쿼리 파라미터의 '+' 가 공백으로 해석되지 않도록 호출부에서 퍼센트 인코딩한다.
    private func isoOffset(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }

    private func makeRequest<Body: Encodable>(
        path: String,
        method: String,
        query: [String: String] = [:],
        body: Body?
    ) throws -> URLRequest {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            // '+'(오프셋)가 서버에서 공백으로 디코딩되는 것을 막기 위해 %2B로 명시 인코딩.
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove("+")
            components?.percentEncodedQuery = query
                .map { key, value in
                    let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                    let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                    return "\(k)=\(v)"
                }
                .joined(separator: "&")
            if let composed = components?.url { url = composed }
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = body {
            req.httpBody = try encoder.encode(body)
        }
        return req
    }

    private func send<T: Decodable>(
        _ request: URLRequest,
        authenticated: Bool,
        decoding: T.Type
    ) async throws -> T {
        let (data, response) = try await performRequest(request, authenticated: authenticated)
        return try decode(data: data, response: response, type: T.self)
    }

    private func sendNoContent(_ request: URLRequest, authenticated: Bool) async throws {
        let (data, response) = try await performRequest(request, authenticated: authenticated)
        try ensureSuccess(data: data, response: response)
    }

    private func performRequest(
        _ request: URLRequest,
        authenticated: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        var req = request
        if authenticated, let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await dataCall(req)

        guard authenticated, response.statusCode == 401 else {
            return (data, response)
        }

        // 401 → refresh 후 1회 재시도
        let task: Task<TokenResponse, Error>
        if let existing = refreshTask {
            task = existing
        } else {
            let new = Task<TokenResponse, Error> { [weak self] in
                guard let self else { throw APIError.sessionExpired }
                return try await self.performRefresh()
            }
            refreshTask = new
            task = new
        }

        do {
            let newTokens = try await task.value
            if refreshTask == task { refreshTask = nil }

            var retried = request
            if authenticated {
                retried.setValue("Bearer \(newTokens.accessToken)", forHTTPHeaderField: "Authorization")
            }
            return try await dataCall(retried)
        } catch {
            if refreshTask == task { refreshTask = nil }
            await onSessionExpired?()
            throw APIError.sessionExpired
        }
    }

    private func performRefresh() async throws -> TokenResponse {
        guard let refresh = refreshToken else { throw APIError.invalidRefreshToken }
        return try await self.refresh(refreshToken: refresh)
    }

    private func dataCall(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.network
            }
            return (data, http)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.network
        }
    }

    private func ensureSuccess(data: Data, response: HTTPURLResponse) throws {
        if (200..<300).contains(response.statusCode) { return }
        throw parseError(data: data, statusCode: response.statusCode)
    }

    private func decode<T: Decodable>(data: Data, response: HTTPURLResponse, type: T.Type) throws -> T {
        try ensureSuccess(data: data, response: response)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func parseError(data: Data, statusCode: Int) -> APIError {
        if let server = try? decoder.decode(ServerErrorResponse.self, from: data) {
            return APIError(
                serverCode: server.code,
                message: server.message,
                fieldErrors: server.fieldErrors,
                statusCode: statusCode
            )
        }
        return .unknown(statusCode: statusCode, message: nil)
    }
}
