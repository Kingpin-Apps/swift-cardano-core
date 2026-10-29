import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A `URLProtocol` subclass that intercepts URL requests and returns preset responses.
/// Register it via `MockURLProtocol.makeSession()` and pass the session to `fetch(session:)`.
final class MockURLProtocol: URLProtocol {
    /// Keyed by URL string → `Result<Data, Error>`. Tests run in parallel and
    /// URL loading reads from its own threads, so every access takes `lock`:
    /// an unsynchronised dictionary here corrupted memory and crashed the
    /// test process now and then.
    nonisolated(unsafe) private static var responses: [String: Result<Data, Error>] = [:]
    private static let lock = NSLock()

    /// Sets, or with `nil` removes, the response for `url`.
    static func setResponse(_ response: Result<Data, Error>?, for url: String) {
        lock.withLock { responses[url] = response }
    }

    private static func response(for url: String) -> Result<Data, Error>? {
        lock.withLock { responses[url] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let key = request.url?.absoluteString ?? ""
        switch MockURLProtocol.response(for: key) {
        case .success(let data):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
        }
    }

    override func stopLoading() {}

    /// Creates a `URLSession` that routes all requests through `MockURLProtocol`.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
