import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct AddressTests {
    
    let expectedPayment = "addr1q89gvt69g9hv3ushfzw64jr06qgml8rdeanuz2e3hn9xrytk99uy7hwe828zf7vzm5k37wuyzjrgmqnqakm2qmyy0f5suhvr47"
    let expectedStake = "stake1u9mzj7z0thvn4r3ylxpd6tgl8wzpfp5dsfswmd4qdjz856g5wz62x"
    
    let vkJson = """
    {
        "type": "GenesisUTxOVerificationKey_ed25519",
        "description": "Genesis Initial UTxO Verification Key",
        "cborHex": "58208be8339e9f3addfa6810d59e2f072f85e64d4c024c087e0d24f8317c6544f62f"
    }
    """
    
    let test_addr: Address = try! Address(from: .string("stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"))
    
    @Test("Test initialization", arguments: [
        PaymentPart.verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))),
        PaymentPart.scriptHash(ScriptHash(payload: Data(repeating: 0, count: SCRIPT_HASH_SIZE))),
    ],[
        StakingPart.verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))),
        StakingPart.scriptHash(ScriptHash(payload: Data(repeating: 0, count: SCRIPT_HASH_SIZE))),
        StakingPart.pointerAddress(PointerAddress(slot: 1, txIndex: 2, certIndex: 3))
    ])
    func testInitialization(_ paymentPart: PaymentPart, _ stakingPart: StakingPart) async throws {
        for network in NetworkId.allCases {
            let address = try Address(
                paymentPart: paymentPart,
                stakingPart: stakingPart,
                network: network
            )
            
            let addressType = try Address.inferAddressType(
                paymentPart: paymentPart,
                stakingPart: stakingPart
            )
            
            let cborData = try CBOREncoder().encode(address)
            let decodedAddress = try CBORDecoder().decode(Address.self, from: cborData)
            
            #expect(address.addressType == addressType)
            #expect(address == decodedAddress)
        }
    }
    
    @Test func testToBech32() async throws {
        let keyHash = VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let address = try Address(paymentPart: .verificationKeyHash(keyHash), stakingPart: .verificationKeyHash(keyHash), network: .mainnet)
        let bech32 = try address.toBech32()
        let excpected = "addr1qyqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv2t5am"
        #expect(bech32 == excpected)
    }
    
    @Test func testFromBech32() async throws {
        let data = "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7"
        let address = try Address.fromBech32(data)
        let bech32 = try address.toBech32()
        #expect(bech32 == data)
    }
    
    @Test func testEquality() async throws {
        let keyHash = VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let scriptHash = ScriptHash(payload: Data(repeating: 1, count: SCRIPT_HASH_SIZE))
        
        let address1 = try Address(paymentPart: .verificationKeyHash(keyHash), stakingPart: .verificationKeyHash(keyHash), network: .mainnet)
        let address2 = try Address(paymentPart: .verificationKeyHash(keyHash), stakingPart: .verificationKeyHash(keyHash), network: .mainnet)
        let address3 = try Address(paymentPart: .scriptHash(scriptHash), stakingPart: .scriptHash(scriptHash), network: .mainnet)
        
        #expect(address1 == address2)
        #expect(address1 != address3)
    }
    
    @Test func testDescription() async throws {
        let keyHash = VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let address = try Address(paymentPart: .verificationKeyHash(keyHash), stakingPart: .verificationKeyHash(keyHash), network: .mainnet)
        let encoded = try address.toBech32()
        #expect(address.description == encoded)
    }
    
    @Test func testFromPrimitiveData() async throws {
        let addr = "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7"
        let address: Address = try Address(from: .string(addr))
        #expect(try address.toBech32() == addr)
    }
    
    @Test func testToPrimitiveData() async throws {
        let keyHash = VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let address = try Address(paymentPart: .verificationKeyHash(keyHash), stakingPart: .verificationKeyHash(keyHash), network: .mainnet)
        let primitiveData = address.toBytes()
        #expect(primitiveData.count == 57)
    }
    
    @Test func testPaymentAddress() async throws {
        let vk = try! PaymentVerificationKey.fromTextEnvelope(vkJson)
        let address = try Address(
            paymentPart: .verificationKeyHash(vk.hash()),
            stakingPart: .none,
            network: .testnet
        )
        let expected = "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7"
        let addressBech32 = try address.toBech32()
        #expect(addressBech32 == expected)
    }
    
    @Test func testSave() async throws {
        let test_addr: Address = try! Address(from: .string("addr1q89gvt69g9hv3ushfzw64jr06qgml8rdeanuz2e3hn9xrytk99uy7hwe828zf7vzm5k37wuyzjrgmqnqakm2qmyy0f5suhvr47"))
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent("test.addr")
        
        if FileManager.default.fileExists(atPath: tempFileURL.path) {
            try FileManager.default.removeItem(at: tempFileURL)
        }
        
        try test_addr.save(to: tempFileURL.path())
        let loaded = try Address.load(from: tempFileURL.path())
        
        #expect(FileManager.default.fileExists(atPath: tempFileURL.path))
        #expect(test_addr == loaded)
    }
    
    @Test func testLoad() async throws {
        guard let paymentAddressFilePath = Bundle.module.path(forResource: "test.payment", ofType: "addr", inDirectory: "data") else {
            Issue.record("File not found: test.payment.addr")
            return
        }
        guard let stakeAddressFilePath = Bundle.module.path(forResource: "test.stake", ofType: "addr", inDirectory: "data") else {
            Issue.record("File not found: test.stake.addr")
            return
        }
        
        let paymentAddress = try Address.load(from: paymentAddressFilePath)
        let stakeAddress = try Address.load(from: stakeAddressFilePath)
        
        
        
        let paymentAddressBech32 = try paymentAddress.toBech32()
        let stakeAddressBech32 = try stakeAddress.toBech32()
        
        #expect(paymentAddressBech32 == expectedPayment)
        #expect(stakeAddressBech32 == expectedStake)
    }
}
