import Foundation

final class URLProtocolStub: URLProtocol {
    private static var _lastRequest: URLRequest?
    private static let lock = NSLock()

    static var lastRequest: URLRequest? {
        get { lock.withLock { _lastRequest } }
        set { lock.withLock { _lastRequest = newValue } }
    }

    static func reset() {
        lock.withLock { _lastRequest = nil }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("[]".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
