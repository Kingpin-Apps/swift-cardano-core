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

    @Test func testMatchesWithValidHash() async throws {
        let filePath = try getFilePath(
            forResource: poolMetadataJSONFilePath.forResource,
            ofType: poolMetadataJSONFilePath.ofType,
            inDirectory: poolMetadataJSONFilePath.inDirectory
        )
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath!))
        let hash = PoolMetadataHash(payload: poolMetadataHash!.hexStringToData)

        #expect(try PoolMetadata.matches(data: data, hash: hash) == true)
    }

    @Test func testMatchesWithInvalidHash() async throws {
        let filePath = try getFilePath(
            forResource: poolMetadataJSONFilePath.forResource,
            ofType: poolMetadataJSONFilePath.ofType,
            inDirectory: poolMetadataJSONFilePath.inDirectory
        )
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath!))
        let wrongHash = PoolMetadataHash(payload: Data(repeating: 0xAB, count: 32))

        #expect(try PoolMetadata.matches(data: data, hash: wrongHash) == false)
    }

    // MARK: - fetch tests

    private func fixtureData() throws -> Data {
        let filePath = try getFilePath(
            forResource: poolMetadataJSONFilePath.forResource,
            ofType: poolMetadataJSONFilePath.ofType,
            inDirectory: poolMetadataJSONFilePath.inDirectory
        )
        return try Data(contentsOf: URL(fileURLWithPath: filePath!))
    }

    @Test func testFetchPopulatesAllFields() async throws {
        let data = try fixtureData()
        let hash = PoolMetadataHash(payload: poolMetadataHash!.hexStringToData)
        let url = try Url("https://pool.example.com/fetch-all-fields.json")

        MockURLProtocol.responses[url.absoluteString] = .success(data)
        defer { MockURLProtocol.responses[url.absoluteString] = nil }

        let metadata = try await PoolMetadata.fetch(
            url: url,
            poolMetadataHash: hash,
            session: MockURLProtocol.makeSession()
        )

        #expect(metadata.name == name)
        #expect(metadata.desc == description)
        #expect(metadata.ticker == ticker)
        #expect(metadata.homepage?.absoluteString == homepage)
        #expect(metadata.url == url)
        #expect(metadata.poolMetadataHash == hash)
    }

    @Test func testFetchWithHashMismatchThrows() async throws {
        let data = try fixtureData()
        let wrongHash = PoolMetadataHash(payload: Data(repeating: 0xAB, count: 32))
        let url = try Url("https://pool.example.com/fetch-hash-mismatch.json")

        MockURLProtocol.responses[url.absoluteString] = .success(data)
        defer { MockURLProtocol.responses[url.absoluteString] = nil }

        await #expect(throws: CardanoCoreError.self) {
            _ = try await PoolMetadata.fetch(
                url: url,
                poolMetadataHash: wrongHash,
                session: MockURLProtocol.makeSession()
            )
        }
    }

    @Test func testFetchWithoutHashSkipsVerification() async throws {
        let data = try fixtureData()
        let url = try Url("https://pool.example.com/fetch-no-hash.json")

        MockURLProtocol.responses[url.absoluteString] = .success(data)
        defer { MockURLProtocol.responses[url.absoluteString] = nil }

        let metadata = try await PoolMetadata.fetch(
            url: url,
            session: MockURLProtocol.makeSession()
        )

        #expect(metadata.name == name)
        #expect(metadata.desc == description)
        #expect(metadata.ticker == ticker)
        #expect(metadata.homepage?.absoluteString == homepage)
        #expect(metadata.url == url)
        #expect(metadata.poolMetadataHash == nil)
    }

    @Test func testFetchWithInvalidJSONThrows() async throws {
        // A JSON array is valid JSON but fails fromDict's guard for an orderedDict
        let url = try Url("https://pool.example.com/fetch-invalid-json.json")
        let arrayJSON = "[]".data(using: .utf8)!

        MockURLProtocol.responses[url.absoluteString] = .success(arrayJSON)
        defer { MockURLProtocol.responses[url.absoluteString] = nil }

        await #expect(throws: CardanoCoreError.self) {
            _ = try await PoolMetadata.fetch(
                url: url,
                session: MockURLProtocol.makeSession()
            )
        }
    }
}
