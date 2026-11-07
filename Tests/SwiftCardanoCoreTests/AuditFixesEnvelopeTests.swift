import Testing
import Foundation
import CBORCodable
import SwiftNaCl
import SwiftKES
@testable import SwiftCardanoCore

private let skeyHex = "5820" + String(repeating: "ab", count: 32)

private func envelopeDict(_ json: String) throws -> [String: String] {
    let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
    return try #require(object as? [String: String])
}

private func testBody(fee: Coin = 200_000) -> TransactionBody {
    TransactionBody(
        inputs: .list([TransactionInput(transactionId: TransactionId(payload: Data(repeating: 1, count: 32)), index: 0)]),
        outputs: [TransactionOutput(
            address: try! Address.fromBech32("addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7"),
            amount: Value(coin: 2_000_000))],
        fee: fee)
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("audit-envelope-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func mode(of path: String) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: path)
    return try #require(attributes[.posixPermissions] as? NSNumber).intValue & 0o777
}

private func blake2b256(_ data: Data) throws -> Data {
    try Hash().blake2b(data: data, digestSize: 32, encoder: RawEncoder.self)
}

// MARK: - SwiftCardanoCore/Serialization/CBORSerializable.swift:fromCBORHex:secret-hex-in-error

@Suite struct HexErrorRedactionTests {
    let corrupted = "5820" + String(repeating: "ab", count: 31) + "zz"

    @Test("A corrupted signing key envelope's error does not echo the key hex")
    func signingKeyErrorOmitsHex() throws {
        let json = #"{"type":"PaymentSigningKeyShelley_ed25519","description":"Payment Signing Key","cborHex":"\#(corrupted)"}"#
        let error = #expect(throws: CardanoCoreError.self) {
            try PaymentSigningKey.fromTextEnvelope(json, validateType: true)
        }
        let text = String(describing: try #require(error))
        #expect(!text.contains(String(repeating: "ab", count: 31)))
        #expect(text.contains("\(corrupted.count)"))

        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("bad.skey").path
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        let loadError = #expect(throws: CardanoCoreError.self) { try PaymentSigningKey.load(from: path) }
        #expect(!(loadError?.description.contains(String(repeating: "ab", count: 31)) ?? true))
    }

    @Test("A corrupted TextEnvelopable envelope's error does not echo its hex")
    func textEnvelopableErrorOmitsHex() throws {
        let json = #"{"type":"Tx ConwayEra","description":"","cborHex":"\#(corrupted)"}"#
        #expect(throws: CardanoCoreError.invalidArgument("Invalid hex string (\(corrupted.count) characters)")) {
            try Transaction.fromTextEnvelope(json)
        }
        #expect(throws: CardanoCoreError.invalidArgument("Invalid hex string (\(corrupted.count) characters)")) {
            try PaymentSigningKey.fromCBORHex(corrupted)
        }
    }
}
