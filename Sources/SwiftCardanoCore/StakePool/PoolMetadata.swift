import Foundation
import CBORCodable
import OrderedCollections
import SwiftNaCl
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct PoolMetadata: Serializable {
    public let name: String?
    public let desc: String?
    public let ticker: String?
    public let homepage: Url?
    
    public let url: Url?
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
        
        return try PoolMetadata(
            name: name?.stringValue,
            description: description?.stringValue,
            ticker: ticker?.stringValue,
            homepage: homepage
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

    /// Downloads the pool metadata JSON from `url`, verifies it against `poolMetadataHash`,
    /// parses the content, and returns a fully-populated `PoolMetadata`.
    ///
    /// Not available on WASI — that platform has no networking primitives.
    ///
    /// - Throws: `CardanoCoreError.valueError` if the downloaded content does not match the hash.
    #if !os(WASI)
    public static func fetch(
        url: Url,
        poolMetadataHash: PoolMetadataHash? = nil,
        session: URLSession = .shared
    ) async throws -> PoolMetadata {
        let data: Data
        guard let location = url.value else {
            throw CardanoCoreError.valueError("Pool metadata URL is not one Foundation can fetch: \(url.text)")
        }

        (data, _) = try await session.data(from: location)

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

