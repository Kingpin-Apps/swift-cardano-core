import Foundation
import Testing
@testable import SwiftCardanoCore

func getTestAddress(forResource: String, ofType: String, inDirectory: String) throws -> Address? {
    guard let filePath = Bundle.module.path(
        forResource: forResource,
        ofType: ofType,
        inDirectory: inDirectory) else {
        Issue.record("File not found: \(forResource).\(ofType)")
        try #require(Bool(false))
        return nil
    }
    
    do {
        return try Address.load(from: filePath)
    } catch {
        Issue.record("Failed to load address from file: \(filePath)")
        try #require(Bool(false))
        return nil
    }
}

func getFilePath(forResource: String, ofType: String, inDirectory: String) throws -> String? {
    guard let filePath = Bundle.module.path(
        forResource: forResource,
        ofType: ofType,
        inDirectory: inDirectory) else {
        Issue.record("File not found: \(forResource).\(ofType)")
        try #require(Bool(false))
        return nil
    }
    return filePath
}

func getVerificationKey<T>(forResource: String, ofType: String, inDirectory: String) throws -> T? where T: VerificationKeyProtocol {
    guard let filePath = Bundle.module.path(
        forResource: forResource,
        ofType: ofType,
        inDirectory: inDirectory) else {
        Issue.record("File not found: \(forResource).\(ofType)")
        try #require(Bool(false))
        return nil
    }
    
    do {
        let key = try T.load(from: filePath)
        return key
    } catch {
        Issue.record("Failed to load address from file: \(filePath)")
        try #require(Bool(false))
        return nil
    }
}

func makeTransactionBody() throws -> TransactionBody {
    let txIdHex = "732bfd67e66be8e8288349fcaaa2294973ef6271cc189a239bb431275401b8e5"
    guard let txIdData = Data(hexString: txIdHex) else {
        throw CardanoCoreError.invalidArgument("Invalid transaction ID hex string")
    }
    
    let txId = TransactionId(payload: txIdData)
    let txIn = TransactionInput(transactionId: txId, index: 0)
    
    guard let addr = try? Address(from:
        .string("addr_test1vrm9x2zsux7va6w892g38tvchnzahvcd9tykqf3ygnmwtaqyfg52x")
    ) else {
        throw CardanoCoreError.invalidArgument("Invalid address string")
    }
    
    let output1 = TransactionOutput(address: addr, amount: Value(coin: 100_000_000_000))
    let output2 = TransactionOutput(address: addr, amount: Value(coin:799_999_834_103))
    let fee: UInt64 = 165_897
    
    // Use the new InputCollection type to handle the array of inputs
    let txBody = TransactionBody(
        inputs: .list([txIn]),
        outputs: [output1, output2],
        fee: fee,
        collateral: .list([]),
        requiredSigners: .list([]),
    )
    
    return txBody
}

func checkTwoWayCBOR<T: CBORSerializable & Equatable>(serializable: T) throws {
    let cborData = try serializable.toCBORData()
    let restored = try T.self.fromCBOR(data: cborData)
    #expect(restored == serializable, "Two-way CBOR serialization failed")
}
