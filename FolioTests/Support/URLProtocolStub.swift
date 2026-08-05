import Foundation

final class URLProtocolStub: URLProtocol {
    struct StubResponse {
        let statusCode: Int
        let data: Data
        let headers: [String: String]

        init(statusCode: Int, data: Data, headers: [String: String] = ["Content-Type": "application/json"]) {
            self.statusCode = statusCode
            self.data = data
            self.headers = headers
        }
    }

    private static var _lastRequest: URLRequest?
    private static var _responses: [StubResponse] = []
    private static var _errors: [URLError] = []
    private static let lock = NSLock()

    static var lastRequest: URLRequest? {
        get { lock.withLock { _lastRequest } }
        set { lock.withLock { _lastRequest = newValue } }
    }

    static var responses: [StubResponse] {
        get { lock.withLock { _responses } }
        set { lock.withLock { _responses = newValue } }
    }

    static var errors: [URLError] {
        get { lock.withLock { _errors } }
        set { lock.withLock { _errors = newValue } }
    }

    static func reset() {
        lock.withLock {
            _lastRequest = nil
            _responses = []
            _errors = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        let stubError: URLError? = Self.lock.withLock {
            if Self._errors.isEmpty { return nil }
            return Self._errors.removeFirst()
        }
        if let stubError {
            client?.urlProtocol(self, didFailWithError: stubError)
            return
        }
        let stubResponse: StubResponse? = Self.lock.withLock {
            if Self._responses.isEmpty { return nil }
            return Self._responses.removeFirst()
        }
        let responseData = stubResponse?.data ?? Data("{\"status\":\"success\",\"data\":{\"spaces\":[],\"pagination\":{\"page\":1,\"limit\":10,\"totalCount\":0,\"totalPages\":0}}}".utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stubResponse?.statusCode ?? 200,
            httpVersion: nil,
            headerFields: stubResponse?.headers ?? ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
