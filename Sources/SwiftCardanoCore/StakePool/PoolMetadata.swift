import Foundation
import CryptoKit
import PotentCBOR
import OrderedCollections
import SwiftNcal

struct PoolMetadata: JSONSerializable {
    let name: String?
    let description: String?
    let ticker: String?
    let homepage: Url?
    
    let url: Url?
    let poolMetadataHash: PoolMetadataHash?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case ticker
        case homepage
    }
    
    init(
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
        self.description = description
        self.ticker = ticker
        self.homepage = homepage
        self.url = url
        self.poolMetadataHash = poolMetadataHash
    }
    
    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            let name = try container.decodeIfPresent(String.self, forKey: .name)
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            let ticker = try container.decodeIfPresent(String.self, forKey: .ticker)
            let homepage: Url? = try {
                if let homepageString = try container.decodeIfPresent(String.self, forKey: .homepage) {
                    return try? Url(homepageString)
                }
                return nil
            }()
            
            try self.init(name: name, description: description, ticker: ticker, homepage: homepage)
        } else {
            var container = try decoder.unkeyedContainer()
            
            let url = try container.decode(String.self)
            let poolMetadataHash = try container.decode(PoolMetadataHash.self)
            
            try self.init(
                name: nil,
                description: nil,
                ticker: nil,
                homepage: nil,
                url: Url(url),
                poolMetadataHash: poolMetadataHash
            )
        }
    }
    
    func encode(to encoder: Swift.Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(name, forKey: .name)
            try container.encode(description, forKey: .description)
            try container.encode(ticker, forKey: .ticker)
            try container.encode(homepage!.absoluteString, forKey: .homepage)
        } else  {
            var container = encoder.unkeyedContainer()
            
            try container.encode(url!.absoluteString)
            try container.encode(poolMetadataHash)
        }
    }
    
    func hash() throws -> String {
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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(ticker)
        hasher.combine(homepage)
    }
    
    func toJSON() throws -> String? {        
        let jsonString = """
        {
            "name": "\(name ?? "")",
            "description": "\(description ?? "")",
            "ticker": "\(ticker ?? "")",
            "homepage": "\(homepage?.absoluteString ?? "")"
        }
        
        """
        
        return jsonString
    }

    static func fromDict(_ dict: Dictionary<AnyHashable, Any>) throws -> PoolMetadata {
        let name = dict["name"] as? String
        let description = dict["description"] as? String
        let ticker = dict["ticker"] as? String
        let homepage: Url? = {
            if let homepageString = dict["homepage"] as? String {
                return try? Url(homepageString)
            }
            return nil
        }()
        
        return try PoolMetadata(name: name, description: description, ticker: ticker, homepage: homepage)
    }

}

