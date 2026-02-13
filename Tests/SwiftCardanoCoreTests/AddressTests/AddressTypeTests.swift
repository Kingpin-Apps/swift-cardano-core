import Testing
import Foundation
@testable import SwiftCardanoCore

struct PaymentPartTests {
    
    @Test func testPaymentPartVerificationKeyHash() async throws {
        let keyHash = VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let paymentPart = PaymentPart.verificationKeyHash(keyHash)
        
        switch paymentPart {
            case .verificationKeyHash(let hash):
                #expect(hash == keyHash)
            case .scriptHash:
                Issue.record("Expected verificationKeyHash, but found scriptHash")
        }
        #expect(paymentPart.hash() == keyHash.payload)
    }
    
    @Test func testPaymentPartScriptHash() async throws {
        let scriptHash = ScriptHash(payload: Data(repeating: 0, count: SCRIPT_HASH_SIZE))
        let paymentPart = PaymentPart.scriptHash(scriptHash)
        
        switch paymentPart {
            case .verificationKeyHash:
                Issue.record("Expected scriptHash, but found verificationKeyHash")
            case .scriptHash(let hash):
                #expect(hash == scriptHash)
        }
        #expect(paymentPart.hash() == scriptHash.payload)
    }
}

struct StakingPartTests {
    
    @Test func testStakingPartVerificationKeyHash() async throws {
        let keyHash = VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE))
        let stakingPart = StakingPart.verificationKeyHash(keyHash)
        
        switch stakingPart {
        case .verificationKeyHash(let hash):
            #expect(hash == keyHash)
        case .scriptHash, .pointerAddress:
            Issue.record("Expected verificationKeyHash, but found another type")
        }
        #expect(stakingPart.hash() == keyHash.payload)
    }
    
    @Test func testStakingPartScriptHash() async throws {
        let scriptHash = ScriptHash(payload: Data(repeating: 0, count: SCRIPT_HASH_SIZE))
        let stakingPart = StakingPart.scriptHash(scriptHash)
        
        switch stakingPart {
        case .verificationKeyHash, .pointerAddress:
            Issue.record("Expected scriptHash, but found another type")
        case .scriptHash(let hash):
            #expect(hash == scriptHash)
        }
        #expect(stakingPart.hash() == scriptHash.payload)
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
        #expect(stakingPart.hash() == pointerAddress.encode())
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
