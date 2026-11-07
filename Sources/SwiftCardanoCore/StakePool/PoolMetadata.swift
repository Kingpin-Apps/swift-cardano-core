import Foundation
import CBORCodable
import OrderedCollections
import SwiftNaCl
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A stake pool's metadata: the off-chain fields of its CIP-6 JSON file and the on-chain URL and hash that point to it.
///
/// On chain, only ``url`` and ``poolMetadataHash`` are written: `pool_metadata = [url, pool_metadata_hash]`.
public struct PoolMetadata: Serializable {
    /// The pool's name, at most 50 characters.
    public let name: String?
    /// The pool's description, at most 255 characters.
    public let desc: String?
    /// The pool's ticker: 3 to 5 uppercase letters or digits.
    public let ticker: String?
    /// The pool's homepage.
    public let homepage: Url?
    
    /// The URL the metadata file is published at.
    public let url: Url?
    /// The Blake2b-256 hash of the metadata file.
    public let poolMetadataHash: PoolMetadataHash?

    /// The file this was read from, byte for byte. A pool's metadata hash
    /// (CIP-6) is taken over the file as published, so ``hash()`` hashes
    /// these bytes when it has them; reformatting the JSON would change it.
    public private(set) var originalJSON: Data? = nil

    public static func == (lhs: PoolMetadata, rhs: PoolMetadata) -> Bool {
        lhs.name == rhs.name && lhs.desc == rhs.desc && lhs.ticker == rhs.ticker
            && lhs.homepage == rhs.homepage && lhs.url == rhs.url
            && lhs.poolMetadataHash == rhs.poolMetadataHash
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(ticker)
        hasher.combine(poolMetadataHash)
    }

    /// Reads metadata from the bytes of its file, keeping them for ``hash()``.
    public static func fromJSON(data: Data) throws -> PoolMetadata {
        guard String(data: data, encoding: .utf8) != nil else {
            throw CardanoCoreError.deserializeError("Pool metadata is not valid UTF-8.")
        }
        let parsed = try PoolMetadata.fromDict(try Primitive.from(json: JSONSerialization.jsonObject(with: data)))
        var metadata = try PoolMetadata(
            name: parsed.name, description: parsed.desc, ticker: parsed.ticker,
            homepage: parsed.homepage, url: parsed.url, poolMetadataHash: parsed.poolMetadataHash)
        metadata.originalJSON = data
        return metadata
    }

    /// Reads metadata from its file's text, keeping it for ``hash()``.
    public static func fromJSON(_ json: String) throws -> PoolMetadata {
        try fromJSON(data: Data(json.utf8))
    }
    
    /// Creates pool metadata, checking the lengths of its text fields.
    /// - Parameters:
    ///   - name: The pool's name, at most 50 characters.
    ///   - description: The pool's description, at most 255 characters.
    ///   - ticker: The pool's ticker: 3 to 5 uppercase letters or digits.
    ///   - homepage: The pool's homepage.
    ///   - url: The URL the metadata file is published at.
    ///   - poolMetadataHash: The hash of the metadata file.
    /// - Throws: `CardanoCoreError.valueError` when `name`, `description` or `ticker` breaks those limits.
    public init(
        name: String? = nil,
        description: String? = nil,
        ticker: String? = nil,
        homepage: Url? = nil,
        url: Url? = nil,
        poolMetadataHash: PoolMetadataHash? = nil
    ) throws {
        
        if let name = name {
            guard name.count <= 50 else {
                throw CardanoCoreError.valueError("Name must have at most 50 characters, but it has \(name.count) characters.")
            }
        }
        
        if let description = description {
            guard description.count <= 255 else {
                throw CardanoCoreError.valueError("Description  must have at most 255 characters, but it has \(description.count) characters.")
            }
        }
        
        if let ticker = ticker {
            guard ticker.count >= 3 && ticker.count <= 5, ticker.allSatisfy({ $0.isUppercase || $0.isNumber }) else {
                throw CardanoCoreError.valueError("Ticker must be 3-5 characters long and contain only uppercase letters (A-Z) and numbers (0-9).")
            }
        }
        
        self.name = name
        self.desc = description
        self.ticker = ticker
        self.homepage = homepage
        self.url = url
        self.poolMetadataHash = poolMetadataHash
    }
    
    /// The metadata hash: Blake2b-256 of the file as read, or of
    /// ``toJSON()`` for metadata built in code.
    public func hash() throws -> String {
        guard let jsonData = try originalJSON ?? toJSON().map({ Data($0.utf8) }) else {
            throw CardanoCoreError.serializeError("Pool metadata could not be written as JSON.")
        }

        guard jsonData.count <= 512 else {
            throw CardanoCoreError.valueError("Metadata must be less than or equal to 512 bytes.")
        }
        
        let hash =  try SwiftNaCl.Hash().blake2b(
            data: jsonData,
            digestSize: POOL_METADATA_HASH_SIZE,
            encoder: RawEncoder.self
        )
        
        return hash.toHex
    }
    
    /// Writes the metadata file's JSON with `name`, `description`, `ticker` and `homepage`.
    /// - Returns: The JSON text.
    public func toJSON() throws -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        // Each value written as a JSON string, so quotes and control
        // characters in it are escaped.
        func quoted(_ value: String?) throws -> String {
            String(decoding: try encoder.encode(value ?? ""), as: UTF8.self)
        }
        let jsonString = """
        {
            "name": \(try quoted(name)),
            "description": \(try quoted(desc)),
            "ticker": \(try quoted(ticker)),
            "homepage": \(try quoted(homepage?.absoluteString))
        }

        """
        return jsonString
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid PoolMetadata primitive")
        }
        
        guard elements.count == 2 else {
            throw CardanoCoreError.deserializeError("PoolMetadata requires exactly 2 elements: url and hash")
        }
        
        guard case let .string(urlString) = elements[0] else {
            throw CardanoCoreError.deserializeError("Invalid URL in PoolMetadata")
        }
        
        guard case let .bytes(hashData) = elements[1] else {
            throw CardanoCoreError.deserializeError("Invalid hash in PoolMetadata")
        }
        
        try self.init(
            name: nil,
            description: nil,
            ticker: nil,
            homepage: nil,
            url: Url(urlString),
            poolMetadataHash: PoolMetadataHash(payload: hashData)
        )
    }
    
    public func toPrimitive() throws -> Primitive {
        guard let url = self.url,
              let poolMetadataHash = self.poolMetadataHash else {
            throw CardanoCoreError.serializeError("PoolMetadata requires url and poolMetadataHash for CBOR serialization")
        }
        
        return .list([
            .string(url.absoluteString),
            .bytes(poolMetadataHash.payload)
        ])
        
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> PoolMetadata {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.deserializeError("Invalid PoolMetadata dict")
        }
        let name = dictValue[.string("name")]
        let description = dictValue[.string("description")]
        let ticker = dictValue[.string("ticker")]
        let homepage: Url? = {
            if case let .string(homepageString) = dictValue[.string("homepage")] {
                return try? Url(homepageString)
            }
            return nil
        }()
        
        // Where the metadata of a registered pool is published, and its
        // hash: what a pool registration carries.
        var url: Url? = nil
        if case let .string(urlString) = dictValue[.string("url")] {
            url = try Url(urlString)
        }
        let poolMetadataHash = try dictValue[.string("poolMetadataHash")].map {
            try PoolMetadataHash(payload: $0.jsonBytes("PoolMetadata poolMetadataHash", count: PoolMetadataHash.maxSize))
        }

        return try PoolMetadata(
            name: name?.stringValue,
            description: description?.stringValue,
            ticker: ticker?.stringValue,
            homepage: homepage,
            url: url,
            poolMetadataHash: poolMetadataHash
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict: OrderedDictionary<Primitive, Primitive> = [:]

        if let name = name {
            dict[.string("name")] = .string(name)
        }

        if let desc = desc {
            dict[.string("description")] = .string(desc)
        }

        if let ticker = ticker {
            dict[.string("ticker")] = .string(ticker)
        }

        if let homepage = homepage {
            dict[.string("homepage")] = .string(homepage.absoluteString)
        }

        if let url = url {
            dict[.string("url")] = .string(url.absoluteString)
        }

        if let poolMetadataHash = poolMetadataHash {
            dict[.string("poolMetadataHash")] = .string(poolMetadataHash.payload.toHex)
        }

        return .orderedDict(dict)
    }

    // MARK: - Remote Metadata

    /// Returns `true` if the blake2b-256 hash of `data` equals the expected `hash` payload.
    public static func matches(data: Data, hash: PoolMetadataHash) throws -> Bool {
        let computed = try SwiftNaCl.Hash().blake2b(
            data: data,
            digestSize: POOL_METADATA_HASH_SIZE,
            encoder: RawEncoder.self
        )
        return computed == hash.payload
    }

    #if !os(WASI)
    /// The most bytes ``fetch(url:poolMetadataHash:session:maximumBytes:)``
    /// can be asked to accept: 64 KiB, far above the 512 bytes CIP-6 allows.
    public static let maximumFetchBytes = 65_536

    /// Downloads the pool metadata JSON from `url`, verifies it against `poolMetadataHash`,
    /// parses the content, and returns a fully-populated `PoolMetadata`.
    ///
    /// A pool operator chooses the URL and runs the server behind it, so the
    /// download is guarded: only `http` and `https` URLs are fetched, and
    /// redirects only to those; a status outside 200–299 is refused; and the
    /// body is refused as soon as its declared length or the bytes received
    /// pass `maximumBytes`, before any more is buffered, hashed or parsed.
    ///
    /// The download runs in a session with `session`'s configuration (so its
    /// protocol classes, headers and timeouts apply) but not its delegate.
    ///
    /// Not available on WASI — that platform has no networking primitives.
    ///
    /// - Parameters:
    ///   - url: The URL the metadata file is published at.
    ///   - poolMetadataHash: The expected hash of the file, or `nil` to skip the check.
    ///   - session: The URL session whose configuration to download with.
    ///   - maximumBytes: The largest body accepted, 512 by default (the CIP-6
    ///     limit). From 1 to ``maximumFetchBytes``.
    /// - Returns: The metadata, keeping the downloaded bytes for ``hash()``.
    /// - Throws: `CardanoCoreError.valueError` if the URL is not `http` or
    ///   `https`, `maximumBytes` is out of range, the response is not a 2xx
    ///   HTTP response, the body is too large, or the content does not match
    ///   the hash.
    public static func fetch(
        url: Url,
        poolMetadataHash: PoolMetadataHash? = nil,
        session: URLSession = .shared,
        maximumBytes: Int = 512
    ) async throws -> PoolMetadata {
        guard let location = url.value else {
            throw CardanoCoreError.valueError("Pool metadata URL is not one Foundation can fetch: \(url.text)")
        }
        guard LimitedDownload.isAllowed(location) else {
            throw CardanoCoreError.valueError(
                "Pool metadata URL has to be http or https: \(url.text)")
        }
        guard (1...maximumFetchBytes).contains(maximumBytes) else {
            throw CardanoCoreError.valueError(
                "maximumBytes has to be from 1 to \(maximumFetchBytes), got \(maximumBytes)")
        }

        let data = try await LimitedDownload.data(
            from: location, configuration: session.configuration, limit: maximumBytes)

        if let poolMetadataHash = poolMetadataHash {
            guard try matches(data: data, hash: poolMetadataHash) else {
                throw CardanoCoreError.valueError("Downloaded pool metadata does not match the expected hash.")
            }
        }
        
        let parsed = try PoolMetadata.fromJSON(data: data)
        var metadata = try PoolMetadata(
            name: parsed.name,
            description: parsed.desc,
            ticker: parsed.ticker,
            homepage: parsed.homepage,
            url: url,
            poolMetadataHash: poolMetadataHash
        )
        metadata.originalJSON = data
        return metadata
    }
    #endif

}


#if !os(WASI)
/// One download whose body is counted as it arrives and cut off at a limit.
///
/// `URLSession.data(from:)` buffers the whole body, and `bytes(from:)` is not
/// in FoundationNetworking, so this is a data-task delegate, which both have.
private final class LimitedDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let limit: Int
    /// Guards everything below: the delegate is called on the session's queue.
    private let lock = NSLock()
    private var received = Data()
    private var failure: Error?
    private var continuation: CheckedContinuation<Data, Error>?

    private init(limit: Int) {
        self.limit = limit
    }

    /// Whether a URL's scheme is one pool metadata may be fetched from.
    static func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// Downloads `url`'s body, refusing more than `limit` bytes.
    static func data(from url: URL, configuration: URLSessionConfiguration, limit: Int) async throws -> Data {
        let download = LimitedDownload(limit: limit)
        let session = URLSession(configuration: configuration, delegate: download, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let task = session.dataTask(with: url)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                download.lock.withLock { download.continuation = continuation }
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    /// Records the first reason to stop, and cancels the transfer.
    private func fail(_ message: String, _ task: URLSessionTask) {
        lock.withLock {
            if failure == nil { failure = CardanoCoreError.valueError(message) }
        }
        task.cancel()
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            fail("Pool metadata response is not an HTTP response.", dataTask)
            completionHandler(.cancel)
            return
        }
        guard (200..<300).contains(http.statusCode) else {
            fail("Pool metadata request failed with HTTP status \(http.statusCode).", dataTask)
            completionHandler(.cancel)
            return
        }
        guard response.expectedContentLength <= Int64(limit) else {
            fail("Pool metadata declares \(response.expectedContentLength) bytes, "
                + "more than the \(limit) allowed.", dataTask)
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let tooLarge: Bool = lock.withLock {
            guard failure == nil else { return false }
            if data.count > limit - received.count { return true }
            received.append(data)
            return false
        }
        if tooLarge {
            fail("Pool metadata is more than the \(limit) bytes allowed.", dataTask)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        // A redirect may not leave http and https either.
        if let target = request.url, Self.isAllowed(target) {
            completionHandler(request)
        } else {
            fail("Pool metadata redirects to a URL that is not http or https.", task)
            completionHandler(nil)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let (continuation, result): (CheckedContinuation<Data, Error>?, Result<Data, Error>) = lock.withLock {
            let continuation = self.continuation
            self.continuation = nil
            if let failure { return (continuation, .failure(failure)) }
            if let error { return (continuation, .failure(error)) }
            return (continuation, .success(received))
        }
        continuation?.resume(with: result)
    }
}
#endif
