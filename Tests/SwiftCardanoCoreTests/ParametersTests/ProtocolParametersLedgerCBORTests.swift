import Foundation
import Testing
@testable import SwiftCardanoCore

/// Conway protocol parameters as the ledger writes them (`EncCBOR (PParams era)`):
/// a 31-element list in `eraPParams` order, rationals as `#6.30` pairs, lists
/// longer than 23 entries with an indefinite length, maps in key order.
@Suite("Protocol parameters in the ledger's CBOR")
struct ProtocolParametersLedgerCBORTests {
    /// Assembled by hand from the ledger's encoder rules: a PlutusV1 cost
    /// model of 166 entries (indefinite) and a PlutusV3 one of 20 (definite).
    static let ledgerHex = "981f182c1a00025ef51a0001600019400019044c1a001e84801a1dcd6500121901f4d81e82030ad81e82031903e8d81e820105820a001a0a21fe801910d6a2009f222120000102030405060708090a0b0c0d0e0f101112131415161718181819181a181b181c181d181e181f1820182118221823182418251826182718281829182a182b182c182d182e182f1830183118321833183418351836183718381839183a183b183c183d183e183f1840184118421843184418451846184718481849184a184b184c184d184e184f1850185118521853185418551856185718581859185a185b185c185d185e185f1860186118621863186418651866186718681869186a186b186c186d186e186f1870187118721873187418751876187718781879187a187b187c187d187e187f1880188118821883188418851886188718881889188a188b188c188d188e188f1890189118921893189418951896189718981899189a189b189c189d189e189f18a018a118a2ff0294001903e81907d0190bb8190fa0191388191770191b58191f40192328192710192af8192ee01932c81936b0193a98193e80194268194650194a3882d81e82190241192710d81e821902d11a00989680821a00d59f801b00000002540be400821a03b20b801b00000004a817c80019138818960385d81e8218331864d81e8218331864d81e8218331864d81e8218331864d81e82183318648ad81e8218431864d81e8218431864d81e820305d81e820304d81e820305d81e8218431864d81e8218431864d81e8218431864d81e820304d81e8218431864071892061b000000174876e8001a1dcd650014d81e820f01"

    @Test("Ledger bytes decode and are written back unchanged")
    func roundTripsLedgerBytes() throws {
        let bytes = try #require(Data(hexString: Self.ledgerHex))
        let params = try ProtocolParameters.fromCBOR(data: bytes)

        #expect(params.txFeePerByte == 44)
        #expect(params.txFeeFixed == 155381)
        #expect(params.maxTxSize == 16384)
        #expect(params.protocolVersion.major == 10)
        #expect(params.utxoCostPerByte == 4310)
        #expect(params.costModels.PlutusV1.count == 166)
        #expect(params.costModels.PlutusV1.first == -3)
        #expect(params.costModels.PlutusV2.isEmpty)
        #expect(params.costModels.PlutusV3.count == 20)
        #expect(params.maxBlockExecutionUnits.steps == 20_000_000_000)
        #expect(params.dRepDeposit == 500_000_000)
        #expect(params.minFeeRefScriptCostPerByte?.numerator == 15)

        #expect(try params.toCBORData() == bytes)
    }

    @Test("Parameters are written as a 31-element list, not a map")
    func writesList() throws {
        let params = try ProtocolParameters.fromCBOR(data: try #require(Data(hexString: Self.ledgerHex)))
        let written = try params.toCBORData()
        #expect(Array(written.prefix(2)) == [0x98, 0x1F])
    }

    @Test("An indefinite-length list is read as the ledger reads a record")
    func readsIndefiniteList() throws {
        var bytes = try #require(Data(hexString: Self.ledgerHex))
        bytes.replaceSubrange(0..<2, with: [0x9F])
        bytes.append(0xFF)
        let params = try ProtocolParameters.fromCBOR(data: bytes)
        #expect(params.txFeePerByte == 44)
    }

    @Test("A list of the wrong length is rejected")
    func rejectsWrongLength() throws {
        // 30 elements: the last parameter dropped.
        var bytes = try #require(Data(hexString: Self.ledgerHex))
        let reference = try #require(Data(hexString: "d81e820f01"))
        #expect(bytes.suffix(reference.count) == reference)
        bytes.removeLast(reference.count)
        bytes.replaceSubrange(0..<2, with: [0x98, 0x1E])
        #expect(throws: (any Error).self) { try ProtocolParameters.fromCBOR(data: bytes) }
    }

    @Test("Writing without the Conway reference-script fee throws")
    func requiresReferenceScriptFee() throws {
        let params = try ProtocolParameters.fromCBOR(data: try #require(Data(hexString: Self.ledgerHex)))
        var dict = try params.toDict()
        guard case .dict(var fields) = dict else { return }
        fields[.string("minFeeRefScriptCostPerByte")] = nil
        dict = .dict(fields)
        let withoutFee = try ProtocolParameters.fromDict(dict)
        #expect(withoutFee.minFeeRefScriptCostPerByte == nil)
        #expect(throws: (any Error).self) { try withoutFee.toCBORData() }
    }
}

extension ProtocolParameters {
    /// The `protocol_param_update` key of each position in the ledger's list.
    static let ledgerKeys: [Int64] = Array(0...11) + [14] + Array(16...33)

    /// The ledger's 31-element list, with the parameter at update key `key`
    /// set to `value`.
    func ledgerList(setting key: Int64, to value: Primitive) throws -> Primitive {
        guard var elements = try toPrimitive().arrayElements,
              let index = Self.ledgerKeys.firstIndex(of: key) else {
            throw CardanoCoreError.valueError("no ledger position for key \(key)")
        }
        elements[index] = value
        return .list(elements)
    }

    /// The parameters as the integer-keyed map form, which is still read.
    func ledgerMap() throws -> [Primitive: Primitive] {
        guard let elements = try toPrimitive().arrayElements, elements.count == Self.ledgerKeys.count else {
            throw CardanoCoreError.valueError("expected the ledger's 31-element list")
        }
        return Dictionary(uniqueKeysWithValues: zip(Self.ledgerKeys.map { Primitive.int($0) }, elements))
    }
}
