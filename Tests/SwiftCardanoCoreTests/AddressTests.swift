import Testing
import Foundation
@testable import SwiftCardanoCore

struct PaymentPartTests {
    
    @Test func testPaymentPartVerificationKeyHash() async throws {
        let keyHash = try VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let paymentPart = PaymentPart.verificationKeyHash(keyHash)
        
        switch paymentPart {
            case .verificationKeyHash(let hash):
                #expect(hash == keyHash)
            case .scriptHash:
                Issue.record("Expected verificationKeyHash, but found scriptHash")
        }
    }
    
    @Test func testPaymentPartScriptHash() async throws {
        let scriptHash = try ScriptHash(payload: Data(repeating: 0, count: SCRIPT_HASH_SIZE))
        let paymentPart = PaymentPart.scriptHash(scriptHash)
        
        switch paymentPart {
            case .verificationKeyHash:
                Issue.record("Expected scriptHash, but found verificationKeyHash")
            case .scriptHash(let hash):
                #expect(hash == scriptHash)
        }
    }
}

struct StakingPartTests {
    
    @Test func testStakingPartVerificationKeyHash() async throws {
        let keyHash = try VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let stakingPart = StakingPart.verificationKeyHash(keyHash)
        
        switch stakingPart {
        case .verificationKeyHash(let hash):
            #expect(hash == keyHash)
        case .scriptHash, .pointerAddress:
            Issue.record("Expected verificationKeyHash, but found another type")
        }
    }
    
    @Test func testStakingPartScriptHash() async throws {
        let scriptHash = try ScriptHash(payload: Data(repeating: 0, count: SCRIPT_HASH_SIZE))
        let stakingPart = StakingPart.scriptHash(scriptHash)
        
        switch stakingPart {
        case .verificationKeyHash, .pointerAddress:
            Issue.record("Expected scriptHash, but found another type")
        case .scriptHash(let hash):
            #expect(hash == scriptHash)
        }
    }
    
    @Test func testStakingPartPointerAddress() async throws {
        let pointerAddress = PointerAddress(slot: 1, txIndex: 2, certIndex: 3)
        let stakingPart = StakingPart.pointerAddress(pointerAddress)
        
        switch stakingPart {
        case .verificationKeyHash, .scriptHash:
            Issue.record("Expected pointerAddress, but found another type")
        case .pointerAddress(let address):
            #expect(address == pointerAddress)
        }
    }
}

struct AddressFromPrimitiveDataTests {
    
    @Test func testAddressFromPrimitiveDataBytes() async throws {
        let data = Data([0x01, 0x02, 0x03])
        let addressData = AddressFromPrimitiveData.bytes(data)
        
        switch addressData {
        case .bytes(let result):
            #expect(result == data)
        case .string:
            Issue.record("Expected bytes, but found string")
        }
    }
    
    @Test func testAddressFromPrimitiveDataString() async throws {
        let string = "addr1v8xrqjtlfluk9axpmjj5enh0uw0cduwhz7txsqyl36m3ukgqdsn8w"
        let addressData = AddressFromPrimitiveData.string(string)
        
        switch addressData {
        case .bytes:
            Issue.record("Expected string, but found bytes")
        case .string(let result):
            #expect(result == string)
        }
    }
}

struct AddressTypeTests {
    @Test func testAddressTypeRawValues() async throws {
        #expect(AddressType.byron.rawValue == 0b1000)
        #expect(AddressType.keyKey.rawValue ==  0b0000)
        #expect(AddressType.scriptKey.rawValue ==  0b0001)
        #expect(AddressType.keyScript.rawValue ==  0b0010)
        #expect(AddressType.scriptScript.rawValue ==  0b0011)
        #expect(AddressType.keyPointer.rawValue ==  0b0100)
        #expect(AddressType.scriptPointer.rawValue ==  0b0101)
        #expect(AddressType.keyNone.rawValue ==  0b0110)
        #expect(AddressType.scriptNone.rawValue ==  0b0111)
        #expect(AddressType.noneKey.rawValue ==  0b1110)
        #expect(AddressType.noneScript.rawValue ==  0b1111)
    }
        
    @Test func testAddressTypeInitialization() async throws {
        #expect(AddressType(rawValue: 0b1000) == .byron)
        #expect(AddressType(rawValue: 0b0000) == .keyKey)
        #expect(AddressType(rawValue: 0b0001) == .scriptKey)
        #expect(AddressType(rawValue: 0b0010) == .keyScript)
        #expect(AddressType(rawValue: 0b0011) == .scriptScript)
        #expect(AddressType(rawValue: 0b0100) == .keyPointer)
        #expect(AddressType(rawValue: 0b0101) == .scriptPointer)
        #expect(AddressType(rawValue: 0b0110) == .keyNone)
        #expect(AddressType(rawValue: 0b0111) == .scriptNone)
        #expect(AddressType(rawValue: 0b1110) == .noneKey)
        #expect(AddressType(rawValue: 0b1111) == .noneScript)
    }
    
    @Test func testAddressTypeDescriptions() async throws {
        #expect(AddressType.byron.description == "byron")
        #expect(AddressType.keyKey.description == "keyKey")
        #expect(AddressType.scriptKey.description == "scriptKey")
        #expect(AddressType.keyScript.description == "keyScript")
        #expect(AddressType.scriptScript.description == "scriptScript")
        #expect(AddressType.keyPointer.description == "keyPointer")
        #expect(AddressType.scriptPointer.description == "scriptPointer")
        #expect(AddressType.keyNone.description == "keyNone")
        #expect(AddressType.scriptNone.description == "scriptNone")
        #expect(AddressType.noneKey.description == "noneKey")
        #expect(AddressType.noneScript.description == "noneScript")
    }
}

struct PointerAddressTests {
    
    @Test func testInitialization() async throws {
        let pointerAddress = PointerAddress(slot: 1, txIndex: 2, certIndex: 3)
        #expect(pointerAddress.slot == 1)
        #expect(pointerAddress.txIndex == 2)
        #expect(pointerAddress.certIndex == 3)
    }
        
    @Test func testEncode() async throws {
        let pointerAddress = PointerAddress(slot: 1, txIndex: 2, certIndex: 3)
        let encodedData = pointerAddress.encode()
        #expect(encodedData == Data([0x01, 0x02, 0x03]))
        
        let largePointerAddress = PointerAddress(slot: 123456789, txIndex: 2, certIndex: 3)
        let largeEncodedData = largePointerAddress.encode()
        #expect(largeEncodedData == Data([0xba, 0xef, 0x9a, 0x15, 0x02, 0x03]))
    }
    
    @Test func testDecode() async throws {
        let data = Data([0x01, 0x02, 0x03])
        let decodedPointerAddress = try? PointerAddress.decode(data)
        #expect(decodedPointerAddress?.slot == 1)
        #expect(decodedPointerAddress?.txIndex == 2)
        #expect(decodedPointerAddress?.certIndex == 3)
        
        let largeData = Data([0xba, 0xef, 0x9a, 0x15, 0x02, 0x03])
        let largeDecodedPointerAddress = try? PointerAddress.decode(largeData)
        #expect(largeDecodedPointerAddress?.slot == 123456789)
        #expect(largeDecodedPointerAddress?.txIndex == 2)
        #expect(largeDecodedPointerAddress?.certIndex == 3)
    }
    
    @Test func testDecodeInvalidData() async throws {
        let invalidData = Data([0x01, 0x02])
        #expect(throws: CardanoException.self) {
            let _ = try PointerAddress.decode(invalidData)
        }
    }
    
    @Test func testToPrimitive() async throws {
        let pointerAddress = PointerAddress(slot: 1, txIndex: 2, certIndex: 3)
        let primitiveData = pointerAddress.toPrimitive()
        #expect(primitiveData == Data([0x01, 0x02, 0x03]))
    }
    
    @Test func testFromPrimitive() async throws {
        let data = Data([0x01, 0x02, 0x03])
        let pointerAddress = try PointerAddress.fromPrimitive(data)
        #expect(pointerAddress?.slot == 1)
        #expect(pointerAddress?.txIndex == 2)
        #expect(pointerAddress?.certIndex == 3)
    }
    
    @Test func testEquatable() async throws {
        let pointerAddress1 = PointerAddress(slot: 1, txIndex: 2, certIndex: 3)
        let pointerAddress2 = PointerAddress(slot: 1, txIndex: 2, certIndex: 3)
        let pointerAddress3 = PointerAddress(slot: 123456789, txIndex: 2, certIndex: 3)
        
        #expect(pointerAddress1 == pointerAddress2)
        #expect(pointerAddress1 != pointerAddress3)
    }
    
    @Test func testDescription() async throws {
        let pointerAddress = PointerAddress(slot: 1, txIndex: 2, certIndex: 3)
        #expect(pointerAddress.description == "PointerAddress(1, 2, 3)")
    }
}

struct AddressTests {
    
    @Test func testInitialization() async throws {
        let keyHash = try VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let scriptHash = try ScriptHash(payload: Data(repeating: 0, count: SCRIPT_HASH_SIZE))
        let pointerAddress = PointerAddress(slot: 1, txIndex: 2, certIndex: 3)
        
        let address1 = try Address(paymentPart: .verificationKeyHash(keyHash), stakingPart: .verificationKeyHash(keyHash), network: .mainnet)
        #expect(address1 != nil)
        
        let address2 = try Address(paymentPart: .scriptHash(scriptHash), stakingPart: .scriptHash(scriptHash), network: .testnet)
        #expect(address2 != nil)
        
        let address3 = try Address(paymentPart: .verificationKeyHash(keyHash), stakingPart: .pointerAddress(pointerAddress), network: .mainnet)
        #expect(address3 != nil)
    }
    
    @Test func testEncode() async throws {
        let keyHash = try VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let address = try Address(paymentPart: .verificationKeyHash(keyHash), stakingPart: .verificationKeyHash(keyHash), network: .mainnet)
        let encoded = try address.encode()
        #expect(encoded != nil)
        // Additional assertions can be added based on the actual encoding logic
    }
    
    @Test func testDecode() async throws {
        let data = "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7"
        let address = try Address.decode(data)
        #expect(address != nil)
        // Additional assertions can be added based on the actual decoding logic
    }
    
    @Test func testEquality() async throws {
        let keyHash = try VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let scriptHash = try ScriptHash(payload: Data(repeating: 1, count: SCRIPT_HASH_SIZE))
        
        let address1 = try Address(paymentPart: .verificationKeyHash(keyHash), stakingPart: .verificationKeyHash(keyHash), network: .mainnet)
        let address2 = try Address(paymentPart: .verificationKeyHash(keyHash), stakingPart: .verificationKeyHash(keyHash), network: .mainnet)
        let address3 = try Address(paymentPart: .scriptHash(scriptHash), stakingPart: .scriptHash(scriptHash), network: .mainnet)
        
        #expect(address1 == address2)
        #expect(address1 != address3)
    }
    
    @Test func testDescription() async throws {
        let keyHash = try VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let address = try Address(paymentPart: .verificationKeyHash(keyHash), stakingPart: .verificationKeyHash(keyHash), network: .mainnet)
        let encoded = try address.encode()
        #expect(address.description == encoded)
    }
    
    @Test func testFromPrimitiveData() async throws {
        let addr = "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7"
        let address = try Address.fromPrimitive(data: addr)
        #expect(address != nil)
        // Additional assertions can be added based on the actual primitive data
    }
    
    @Test func testToPrimitiveData() async throws {
        let keyHash = try VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let address = try Address(paymentPart: .verificationKeyHash(keyHash), stakingPart: .verificationKeyHash(keyHash), network: .mainnet)
        let primitiveData = address.toPrimitive()
        #expect(primitiveData != nil)
        // Additional assertions can be added based on the actual primitive data
    }
}
