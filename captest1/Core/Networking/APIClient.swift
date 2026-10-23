//
//  APIClient.swift
//  captest1
//
//  HTTP 전송층: 요청 조립, JWT 부착, 401 → refresh → 1회 재시도, 응답 봉투 해제.
//  엔드포인트 메서드는 여기 두지 않는다 — 각 Feature의 `APIClient+<도메인>.swift` 확장이 `<도메인>Repository`를 채택한다.
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

    // MARK: - 세션 제어 (AuthSession)

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

    /// refresh로 받은 새 토큰 쌍을 메모리와 Keychain에 반영한다(`APIClient+Auth`의 refresh가 호출).
    func applyTokens(_ tokens: TokenResponse) async {
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
        await tokenStore.save(access: tokens.accessToken, refresh: tokens.refreshToken)
    }

    // MARK: - 전송 헬퍼 (Feature 확장이 사용)

    func get<T: Decodable>(path: String, query: [String: String] = [:], authenticated: Bool = true) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", query: query, body: Optional<NoBody>.none)
        return try await send(request, authenticated: authenticated, decoding: T.self)
    }

    /// 바디 없는 POST(예: 학습 실행).
    func post<T: Decodable>(path: String, query: [String: String] = [:], authenticated: Bool = true) async throws -> T {
        let request = try makeRequest(path: path, method: "POST", query: query, body: Optional<NoBody>.none)
        return try await send(request, authenticated: authenticated, decoding: T.self)
    }

    func post<B: Encodable, T: Decodable>(path: String, body: B, authenticated: Bool = true) async throws -> T {
        let request = try makeRequest(path: path, method: "POST", body: body)
        return try await send(request, authenticated: authenticated, decoding: T.self)
    }

    func put<B: Encodable, T: Decodable>(path: String, body: B, authenticated: Bool = true) async throws -> T {
        let request = try makeRequest(path: path, method: "PUT", body: body)
        return try await send(request, authenticated: authenticated, decoding: T.self)
    }

    /// 200 + `data: null`을 기대하는 POST(로그아웃 등).
    func postNoContent<B: Encodable>(path: String, body: B, authenticated: Bool = true) async throws {
        let request = try makeRequest(path: path, method: "POST", body: body)
        try await sendNoContent(request, authenticated: authenticated)
    }

    func delete(path: String, authenticated: Bool = true) async throws {
        let request = try makeRequest(path: path, method: "DELETE", body: Optional<NoBody>.none)
        try await sendNoContent(request, authenticated: authenticated)
    }

    // MARK: - Internals

    private struct NoBody: Encodable {}

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

    /// 바디 없는 성공(200 + `data: null`). 봉투가 있으면 `success`까지 확인한다.
    private func sendNoContent(_ request: URLRequest, authenticated: Bool) async throws {
        let (data, response) = try await performRequest(request, authenticated: authenticated)
        try ensureSuccess(data: data, response: response)
        if !data.isEmpty,
           let envelope = try? decoder.decode(APIEnvelope<EmptyPayload>.self, from: data),
           !envelope.success {
            throw Self.mapError(envelope, statusCode: response.statusCode)
        }
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

        let newTokens: TokenResponse
        do {
            newTokens = try await task.value
        } catch {
            if refreshTask == task { refreshTask = nil }
            // 서버가 refresh를 거부했을 때만 세션 만료. 네트워크·취소 같은 일시 오류는 그대로 던져 로그인을 유지한다.
            guard Self.isSessionRejection(error) else { throw error }
            await onSessionExpired?()
            throw APIError.sessionExpired
        }
        if refreshTask == task { refreshTask = nil }

        // 재시도 실패(네트워크 등)는 refresh 성공과 무관하므로 세션 만료로 바꾸지 않는다.
        var retried = request
        retried.setValue("Bearer \(newTokens.accessToken)", forHTTPHeaderField: "Authorization")
        return try await dataCall(retried)
    }

    /// refresh 실패 중 다시 로그인해야 하는 경우(토큰 거부·없음).
    private static func isSessionRejection(_ error: Error) -> Bool {
        switch error as? APIError {
        case .invalidRefreshToken, .unauthorized, .sessionExpired:
            return true
        case .unknown(let statusCode, _):
            return statusCode == 401
        default:
            return false
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

    /// 봉투를 벗겨 `data`만 돌려준다. `success == false`면 `error.code`·`message`로 APIError를 만든다.
    private func decode<T: Decodable>(data: Data, response: HTTPURLResponse, type: T.Type) throws -> T {
        try ensureSuccess(data: data, response: response)
        let envelope: APIEnvelope<T>
        do {
            envelope = try decoder.decode(APIEnvelope<T>.self, from: data)
        } catch {
            throw APIError.decoding
        }
        guard envelope.success else {
            throw Self.mapError(envelope, statusCode: response.statusCode)
        }
        guard let payload = envelope.data else {
            // 계약 위반: 성공인데 페이로드가 없음(이 타입은 data가 필요)
            throw APIError.decoding
        }
        return payload
    }

    /// HTTP 실패 응답의 봉투(`data: null`)에서 에러를 읽는다. 봉투가 아니면 상태 코드만 담는다.
    private func parseError(data: Data, statusCode: Int) -> APIError {
        if let envelope = try? decoder.decode(APIEnvelope<EmptyPayload>.self, from: data) {
            return Self.mapError(envelope, statusCode: statusCode)
        }
        return .unknown(statusCode: statusCode, message: nil)
    }

    private static func mapError<T>(_ envelope: APIEnvelope<T>, statusCode: Int) -> APIError {
        guard let body = envelope.error else {
            return .unknown(statusCode: statusCode, message: envelope.message)
        }
        return APIError(
            serverCode: body.code,
            message: envelope.message,
            fieldErrors: body.fieldErrors,
            statusCode: statusCode
        )
    }
}
