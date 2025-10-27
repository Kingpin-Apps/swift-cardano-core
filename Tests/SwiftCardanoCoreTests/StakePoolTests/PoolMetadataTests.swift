import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct PoolMetadataTests {
    let name: String = "YourPoolName"
    let description: String = "Your pool description"
    let ticker: String = "YPN"
    let homepage: String = "https://yourpoollink.com"
    
    @Test func testValidInitialization() async throws {
        let metadata = try PoolMetadata(
            name: name,
            description: description,
            ticker: ticker,
            homepage: Url(homepage)
        )
        
        #expect(metadata.name == name)
        #expect(metadata.desc == description)
        #expect(metadata.ticker == ticker)
        #expect(metadata.homepage?.absoluteString == homepage)
    }
    
    @Test func testInvalidTickerInitialization() async throws {
        #expect(throws: CardanoCoreError.self) {
            _ = try PoolMetadata(
                name: "Bad Pool",
                description: "Invalid ticker",
                ticker: "toooooolong",
                homepage: Url("https://badpool.io")
            )
        }
    }
    
    @Test func testInvalidDescriptionInitialization() async throws {
        let longDescription = String(repeating: "a", count: 256)
        #expect(throws: CardanoCoreError.self) {
            _ = try PoolMetadata(
                name: "Bad Pool",
                description: longDescription,
                ticker: "BAD",
                homepage: Url("https://badpool.io")
            )
        }
    }
    
    @Test func testJSONEncodingDecoding() async throws {
        let metadata = try PoolMetadata(
            name: name,
            description: description,
            ticker: ticker,
            homepage: Url(homepage)
        )
        
        let jsonData = try metadata.toJSON()!
        let decodedMetadata = try PoolMetadata.fromJSON(jsonData)
        
        #expect(decodedMetadata == metadata)
    }
    
    @Test func testCBOREncodingDecoding() async throws {
        let url = try Url(homepage)
        let poolMetadataHash = PoolMetadataHash(
            payload: Data(repeating: 1, count: 32)
        )
        let metadata = try PoolMetadata(
            url: url,
            poolMetadataHash: poolMetadataHash
        )
        
        
        let cborData = try CBOREncoder().encode(metadata)
        let decodedMetadata = try CBORDecoder().decode(PoolMetadata.self, from: cborData)
        
        #expect(decodedMetadata.url == url)
        #expect(decodedMetadata.poolMetadataHash == poolMetadataHash)
    }
    
    @Test func testEquality() async throws {
        let metadata1 = try PoolMetadata(
            name: "Same Pool",
            description: "A great stake pool.",
            ticker: "TEST",
            homepage: Url("https://testpool.io")
        )
        
        let metadata2 = try PoolMetadata(
            name: "Same Pool",
            description: "A great stake pool.",
            ticker: "TEST",
            homepage: Url("https://testpool.io")
        )
        
        let metadata3 = try PoolMetadata(
            name: "Different Pool",
            description: "A different stake pool.",
            ticker: "DIFF",
            homepage: Url("https://diffpool.io")
        )
        
        #expect(metadata1 == metadata2)
        #expect(metadata1 != metadata3)
    }
    
    @Test func testHash() async throws {
        let metadata = try PoolMetadata(
            name: name,
            description: description,
            ticker: ticker,
            homepage: Url(homepage)
        )
        
        let testHash1 = try metadata.hash()
        let testHash2 = poolMetadataHash!
        let testHash3 = try poolMetadataJSON!.hash()
        
        #expect(metadata == poolMetadataJSON!)
        #expect(testHash1 == testHash2)
        #expect(testHash1 == testHash3)
    }
    
    @Test func testHashing() async throws {
        let metadata1 = try PoolMetadata(
            name: name,
            description: description,
            ticker: ticker,
            homepage: Url(homepage)
        )
        
        let metadata2 = try PoolMetadata(
            name: name,
            description: description,
            ticker: ticker,
            homepage: Url(homepage)
        )
        
        var hasher1 = Hasher()
        var hasher2 = Hasher()
        
        metadata1.hash(into: &hasher1)
        metadata2.hash(into: &hasher2)
        
        #expect(hasher1.finalize() == hasher2.finalize())
    }
}
