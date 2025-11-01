import Foundation
import PotentCBOR
import OrderedCollections
import SwiftNcal

public struct PoolMetadata: Serializable {
    public let name: String?
    public let desc: String?
    public let ticker: String?
    public let homepage: Url?
    
    public let url: Url?
    public let poolMetadataHash: PoolMetadataHash?
    
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
    
    public func hash() throws -> String {
        let json = try toJSON()!
        let jsonData = json.data(using: .utf8)!
        
        guard jsonData.count <= 512 else {
            throw CardanoCoreError.valueError("Metadata must be less than or equal to 512 bytes.")
        }
        
        let hash =  try SwiftNcal.Hash().blake2b(
            data: jsonData,
            digestSize: POOL_METADATA_HASH_SIZE,
            encoder: RawEncoder.self
        )
        
        return hash.toHex
    }
    
    public func toJSON() throws -> String? {
        let jsonString = """
        {
            "name": "\(name ?? "")",
            "description": "\(desc ?? "")",
            "ticker": "\(ticker ?? "")",
            "homepage": "\(homepage?.absoluteString ?? "")"
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

}

