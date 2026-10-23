//
//  StubURLProtocol.swift
//  captest1Tests
//
//  네트워크 없이 APIClient를 검증하기 위한 URLProtocol 스텁.
//  요청을 순서대로 기록하고, install()로 등록한 핸들러가 정한 (상태 코드, JSON)을 돌려준다.
//

import Foundation

final class StubURLProtocol: URLProtocol {
    struct Response {
        let status: Int
        let json: String

        /// 응답 대신 연결 실패(타임아웃)를 낸다.
        static let networkFailure = Response(status: -1, json: "")
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> Response)?
    private nonisolated(unsafe) static var recorded: [URLRequest] = []

    static func install(_ handler: @escaping @Sendable (URLRequest) -> Response) {
        lock.withLock {
            Self.handler = handler
            Self.recorded = []
        }
    }

    static func reset() {
        lock.withLock {
            handler = nil
            recorded = []
        }
    }

    /// 지금까지 받은 요청(순서 보존).
    static var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handler = Self.lock.withLock { () -> (@Sendable (URLRequest) -> Response)? in
            Self.recorded.append(request)
            return Self.handler
        }
        guard let handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = handler(request)
        if response.status < 0 {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        let http = HTTPURLResponse(
            url: url, statusCode: response.status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
