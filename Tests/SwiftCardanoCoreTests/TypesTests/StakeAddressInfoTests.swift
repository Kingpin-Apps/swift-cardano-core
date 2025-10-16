import Testing
import Foundation
@testable import SwiftCardanoCore

@Suite("StakeAddressInfo Tests")
struct StakeAddressInfoTests {
    
    // Sample data for testing
    let sampleAddress = "stake1u9ylzsgxaa6xctf4juup682ar3juj85n8tx3hthnljg47zctvm3rc"
    let sampleGovActionDeposits = ["c832f194684d672316212e01efc6d28177e8965b7cd6956981fe37cc6715963e#0": UInt64(1000)]
    let sampleStakeRegistrationDeposit = 2_000_000
    let sampleRewardBalance = 5_000_000
    let sampleStakeDelegation = "pool1m5947rydk4n0ywe6ctlav0ztt632lcwjef7fsy93sflz7ctcx6z"
    let sampleDelegateRepresentative = "drep1kqhhkv66a0egfw7uyz7u8dv7fcvr4ck0c3ad9k9urx3yzhefup0"
    
    
    // MARK: - Initialization Tests
    
    @Test("StakeAddressInfo initializes correctly with all parameters")
    func testInitializationWithAllParameters() {
        let govActionDeposits = ["action1": UInt64(1000)]
        
        let info = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            govActionDeposits: govActionDeposits,
            rewardAccountBalance: 5000000,
            stakeDelegation: nil,
            stakeRegistrationDeposit: 2000000,
            voteDelegation: nil
        )
        
        #expect(info.address == "stake_test1234567890abcdef")
        #expect(info.govActionDeposits == govActionDeposits)
        #expect(info.rewardAccountBalance == 5000000)
        #expect(info.stakeDelegation == nil)
        #expect(info.stakeRegistrationDeposit == 2000000)
        #expect(info.voteDelegation == nil)
    }
    
    @Test("StakeAddressInfo initializes correctly with minimal parameters")
    func testInitializationWithMinimalParameters() {
        let info = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            rewardAccountBalance: 1000000
        )
        
        #expect(info.address == "stake_test1234567890abcdef")
        #expect(info.govActionDeposits == nil)
        #expect(info.rewardAccountBalance == 1000000)
        #expect(info.stakeDelegation == nil)
        #expect(info.stakeRegistrationDeposit == nil)
        #expect(info.voteDelegation == nil)
    }
    
    @Test func testInitialization() async throws {
        // Test initialization with all parameters
        let info = StakeAddressInfo(
            address: sampleAddress,
            govActionDeposits: sampleGovActionDeposits,
            rewardAccountBalance: sampleRewardBalance,
            stakeDelegation: try PoolId(from: sampleStakeDelegation),
            stakeRegistrationDeposit: sampleStakeRegistrationDeposit,
            voteDelegation: try DRep(from: sampleDelegateRepresentative)
        )
        
        #expect(info.address == sampleAddress)
        #expect(info.govActionDeposits == sampleGovActionDeposits)
        #expect(info.rewardAccountBalance == sampleRewardBalance)
        #expect(info.stakeDelegation?.bech32 == sampleStakeDelegation)
        #expect(info.stakeRegistrationDeposit == sampleStakeRegistrationDeposit)
        #expect(try info.voteDelegation?.id() == sampleDelegateRepresentative)
    }
    // MARK: - Equatable Tests
    
    @Test("StakeAddressInfo equality works correctly for identical instances")
    func testEqualityForIdenticalInstances() {
        let info1 = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            rewardAccountBalance: 1000000,
            stakeRegistrationDeposit: 2000000
        )
        
        let info2 = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            rewardAccountBalance: 1000000,
            stakeRegistrationDeposit: 2000000
        )
        
        #expect(info1 == info2)
    }
    
    @Test("StakeAddressInfo inequality works correctly for different instances")
    func testInequalityForDifferentInstances() {
        let info1 = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            rewardAccountBalance: 1000000
        )
        
        let info2 = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            rewardAccountBalance: 2000000 // Different balance
        )
        
        #expect(info1 != info2)
    }
    
    @Test("StakeAddressInfo inequality works for different addresses")
    func testInequalityForDifferentAddresses() {
        let info1 = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            rewardAccountBalance: 1000000
        )
        
        let info2 = StakeAddressInfo(
            address: "stake_test9876543210fedcba", // Different address
            rewardAccountBalance: 1000000
        )
        
        #expect(info1 != info2)
    }
    
    @Test func testEquality() async throws {
        // Create two identical instances
        let info1 = StakeAddressInfo(
            address: sampleAddress,
            govActionDeposits: sampleGovActionDeposits,
            rewardAccountBalance: sampleRewardBalance,
            stakeDelegation: try PoolId(from: sampleStakeDelegation),
            stakeRegistrationDeposit: sampleStakeRegistrationDeposit,
            voteDelegation: try DRep(from: sampleDelegateRepresentative)
        )
        
        let info2 = StakeAddressInfo(
            address: sampleAddress,
            govActionDeposits: sampleGovActionDeposits,
            rewardAccountBalance: sampleRewardBalance,
            stakeDelegation: try PoolId(from: sampleStakeDelegation),
            stakeRegistrationDeposit: sampleStakeRegistrationDeposit,
            voteDelegation: try DRep(from: sampleDelegateRepresentative)
        )
        
        // Test equality
        #expect(info1 == info2)
        
        // Test inequality with different values
        let info3 = StakeAddressInfo(
            address: sampleAddress,
            govActionDeposits: sampleGovActionDeposits,
            rewardAccountBalance: sampleRewardBalance + 3000,
            stakeDelegation: try PoolId(from: sampleStakeDelegation),
            stakeRegistrationDeposit: sampleStakeRegistrationDeposit,
            voteDelegation: try DRep(from: sampleDelegateRepresentative)
        )
        
        #expect(info1 != info3)
    }
    
    
    // MARK: - Codable Tests
    
    @Test("StakeAddressInfo encodes and decodes correctly with all fields")
    func testFullCodableRoundTrip() throws {
        let govActionDeposits = ["action1": UInt64(1000), "action2": UInt64(2000)]
        
        let original = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            govActionDeposits: govActionDeposits,
            rewardAccountBalance: 5000000,
            stakeDelegation: nil,
            stakeRegistrationDeposit: 2000000,
            voteDelegation: nil
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StakeAddressInfo.self, from: data)
        
        #expect(decoded == original)
    }
    
    @Test("StakeAddressInfo encodes and decodes correctly with minimal fields")
    func testMinimalCodableRoundTrip() throws {
        let original = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            rewardAccountBalance: 1000000
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StakeAddressInfo.self, from: data)
        
        #expect(decoded == original)
    }
    
    @Test("StakeAddressInfo decodes from JSON with missing optional fields")
    func testDecodingWithMissingOptionalFields() throws {
        let json = """
        {
            "address": "stake_test1234567890abcdef",
            "rewardAccountBalance": 1500000
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StakeAddressInfo.self, from: data)
        
        #expect(decoded.address == "stake_test1234567890abcdef")
        #expect(decoded.rewardAccountBalance == 1500000)
        #expect(decoded.govActionDeposits == nil)
        #expect(decoded.stakeDelegation == nil)
        #expect(decoded.stakeRegistrationDeposit == nil)
        #expect(decoded.voteDelegation == nil)
    }
    
    @Test("StakeAddressInfo encodes null values correctly for optional fields")
    func testEncodingHandlesNullOptionalFields() throws {
        let info = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            rewardAccountBalance: 1000000
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(info)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Should contain the required fields and null optional fields
        #expect(jsonString.contains("\"address\":\"stake_test1234567890abcdef\""))
        #expect(jsonString.contains("\"rewardAccountBalance\":1000000"))
        #expect(jsonString.contains("\"govActionDeposits\":null"))
        #expect(jsonString.contains("\"stakeRegistrationDeposit\":null"))
    }
    
    @Test func testEncoding() throws {
        // Create an instance to encode
        let info = StakeAddressInfo(
            address: sampleAddress,
            govActionDeposits: sampleGovActionDeposits,
            rewardAccountBalance: sampleRewardBalance,
            stakeDelegation: try PoolId(from: sampleStakeDelegation),
            stakeRegistrationDeposit: sampleStakeRegistrationDeposit,
            voteDelegation: try DRep(from: sampleDelegateRepresentative)
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(info)
        
        // Decode the JSON to verify encoding
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(StakeAddressInfo.self, from: encodedData)
        
        // Verify the decoded object matches the original
        #expect(decodedInfo == info)
    }
    
    @Test func testDecoding() throws {
        // Create a JSON string with the expected format
        let jsonString = """
            [
                {
                    "address": "\(sampleAddress)",
                    "govActionDeposits": {
                        "c832f194684d672316212e01efc6d28177e8965b7cd6956981fe37cc6715963e#0": 1000
                    },
                    "rewardAccountBalance": \(sampleRewardBalance),
                    "stakeDelegation": "\(sampleStakeDelegation)",
                    "stakeRegistrationDeposit": \(sampleStakeRegistrationDeposit),
                    "voteDelegation": "keyHash-b02f7b335aebf284bbdc20bdc3b59e4e183ae2cfc47ad2d8bc19a241"
                }
            ]
            """
        
        // Convert string to data
        let jsonData = jsonString.data(using: .utf8)!
        
        // Decode the JSON
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode([StakeAddressInfo].self, from: jsonData)
        
        // Verify all properties were decoded correctly
        #expect(decodedInfo[0].address == sampleAddress)
        #expect(decodedInfo[0].govActionDeposits == sampleGovActionDeposits)
        #expect(decodedInfo[0].rewardAccountBalance == sampleRewardBalance)
        #expect(decodedInfo[0].stakeDelegation?.bech32 == sampleStakeDelegation)
        #expect(decodedInfo[0].stakeRegistrationDeposit == sampleStakeRegistrationDeposit)
        #expect(try decodedInfo[0].voteDelegation?.id() == sampleDelegateRepresentative)
    }
    
    @Test func testDecodingWithMissingValues() throws {
        // Create a JSON string with missing optional values
        let jsonString = """
            {
                "address": "\(sampleAddress)",
                "rewardAccountBalance": \(sampleRewardBalance)
            }
            """
        
        // Convert string to data
        let jsonData = jsonString.data(using: .utf8)!
        
        // Decode the JSON
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(StakeAddressInfo.self, from: jsonData)
        
        // Verify required properties were decoded correctly and optional ones are nil
        #expect(decodedInfo.address == sampleAddress)
        #expect(decodedInfo.stakeRegistrationDeposit == nil)
        #expect(decodedInfo.rewardAccountBalance == sampleRewardBalance)
        #expect(decodedInfo.stakeDelegation == nil)
        #expect(decodedInfo.voteDelegation == nil)
    }
    
    @Test func testDecodingWithDefaultValues() throws {
        // Create a JSON string with missing numeric values that should use defaults
        let jsonString = """
            {
                "address": "\(sampleAddress)",
                "stakeDelegation": "\(sampleStakeDelegation)"
            }
            """
        
        // Convert string to data
        let jsonData = jsonString.data(using: .utf8)!
        
        // Decode the JSON
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(StakeAddressInfo.self, from: jsonData)
        
        // Verify default values were applied
        #expect(decodedInfo.address == sampleAddress)
        #expect(decodedInfo.stakeRegistrationDeposit == nil)
        #expect(decodedInfo.rewardAccountBalance == 0)
        #expect(decodedInfo.stakeDelegation?.bech32 == sampleStakeDelegation)
        #expect(decodedInfo.voteDelegation == nil)
    }
    
    // MARK: - Edge Cases
    
    @Test("StakeAddressInfo handles zero reward balance")
    func testZeroRewardBalance() {
        let info = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            rewardAccountBalance: 0
        )
        
        #expect(info.rewardAccountBalance == 0)
    }
    
    @Test("StakeAddressInfo handles negative reward balance")
    func testNegativeRewardBalance() {
        let info = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            rewardAccountBalance: -1000000
        )
        
        #expect(info.rewardAccountBalance == -1000000)
    }
    
    @Test("StakeAddressInfo handles empty gov action deposits dictionary")
    func testEmptyGovActionDeposits() {
        let info = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            govActionDeposits: [:],
            rewardAccountBalance: 1000000
        )
        
        #expect(info.govActionDeposits?.isEmpty == true)
    }
    
    @Test("StakeAddressInfo handles large gov action deposits values")
    func testLargeGovActionDeposits() {
        let largeDeposits = ["action1": UInt64.max]
        
        let info = StakeAddressInfo(
            address: "stake_test1234567890abcdef",
            govActionDeposits: largeDeposits,
            rewardAccountBalance: 1000000
        )
        
        #expect(info.govActionDeposits?["action1"] == UInt64.max)
    }
}
