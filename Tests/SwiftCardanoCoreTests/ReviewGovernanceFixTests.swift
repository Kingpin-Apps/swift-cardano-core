import Testing
import Foundation
import CBORCodable
@testable import SwiftCardanoCore

/// Each fix from the governance review, checked with the input that showed it.
@Suite("Review fixes: governance, intervals, relays and outputs")
struct ReviewGovernanceFixTests {
    let zero28 = String(repeating: "00", count: 28)
    let zero32 = String(repeating: "00", count: 32)
    let addressText = "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7"

    /// `toCBORData()` writes the CBOR of `toPrimitive()`, and `fromCBOR`
    /// reads it back to the same value.
    func expectConsistent<T: CBORSerializable>(
        _ value: T, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let viaCodable = try value.toCBORData()
        let viaPrimitive = try CBOREncoder().encode(try value.toPrimitive())
        #expect(viaCodable.toHex == viaPrimitive.toHex, sourceLocation: sourceLocation)
        let back = try T.fromCBOR(data: viaCodable)
        #expect(back == value, sourceLocation: sourceLocation)
        #expect(try back.toCBORData() == viaCodable, sourceLocation: sourceLocation)
    }

    // MARK: 1. ProtocolParamUpdate

    @Test("extra_entropy is a nonce: [0] and [1, hash32] decode and round-trip")
    func extraEntropyNonce() throws {
        let neutral = try ProtocolParamUpdate.fromCBORHex("a10d8100")
        #expect(neutral.extraEntropy == .neutral)
        #expect(try neutral.toCBORHex() == "a10d8100")

        let hashed = try ProtocolParamUpdate.fromCBORHex("a10d8201" + "5820" + zero32)
        #expect(hashed.extraEntropy == (try Nonce(hash: Data(repeating: 0, count: 32))))
        #expect(try hashed.toCBORHex() == "a10d8201" + "5820" + zero32)

        // A nonce with the wrong hash size, an extra element or an unknown tag.
        #expect(throws: (any Error).self) { try ProtocolParamUpdate.fromCBORHex("a10d8201" + "581f" + String(repeating: "00", count: 31)) }
        #expect(throws: (any Error).self) { try ProtocolParamUpdate.fromCBORHex("a10d820000") }
        #expect(throws: (any Error).self) { try ProtocolParamUpdate.fromCBORHex("a10d8102") }
        // The old UInt32 reading is gone.
        #expect(throws: (any Error).self) { try ProtocolParamUpdate.fromCBORHex("a10d00") }
        // An indefinite-length nonce is what the ledger accepts too.
        #expect(try ProtocolParamUpdate.fromCBORHex("a10d9f00ff").extraEntropy == .neutral)
    }

    @Test("A Shelley update proposing extra_entropy [0] decodes")
    func shelleyUpdateWithNeutralNonce() throws {
        // [{genesis_hash: {13: [0]}}, epoch 5]
        let update = try Update.fromCBORHex("82a1581c" + zero28 + "a10d810005")
        let proposal = try #require(update.proposedprotocolParamUpdates.data.values.first)
        #expect(proposal.extraEntropy == .neutral)
    }

    @Test("min_utxo_value (key 15) is modelled")
    func minUtxoValue() throws {
        let update = try ProtocolParamUpdate.fromCBORHex("a10f1a000f4240")
        #expect(update.minUtxoValue == 1_000_000)
        #expect(try update.toCBORHex() == "a10f1a000f4240")
        #expect(try ProtocolParamUpdate(minUtxoValue: 1_000_000).toCBORHex() == "a10f1a000f4240")
    }

    @Test("Unknown keys are refused, as by the ledger's sparse record decoder")
    func unknownKeysThrow() throws {
        // {34: 0}, {99: 0}, and {0: 0, 34: 0}.
        #expect(throws: (any Error).self) { try ProtocolParamUpdate.fromCBORHex("a1182200") }
        #expect(throws: (any Error).self) { try ProtocolParamUpdate.fromCBORHex("a1186300") }
        #expect(throws: (any Error).self) { try ProtocolParamUpdate.fromCBORHex("a20000182200") }
        #expect(throws: (any Error).self) { try ProtocolParamUpdate(from: .orderedDict([.uint(99): .uint(0)])) }
        #expect(throws: (any Error).self) {
            try ProtocolParamUpdate(from: .list([.list([.uint(0), .uint(1)])]))
        }
    }

    @Test("Codable writes the integer-keyed map, and JSON keeps its field names")
    func codableGoesThroughPrimitive() throws {
        let update = ProtocolParamUpdate(
            minFeeA: 44, extraEntropy: .neutral, minUtxoValue: 1_000_000,
            executionCosts: ExUnitPrices(
                memPrice: NonNegativeInterval(numerator: 577, denominator: 10_000),
                stepPrice: NonNegativeInterval(numerator: 721, denominator: 10_000_000)))
        // {0: 44, 13: [0], 15: 1000000, 19: [#6.30([577, 10000]), #6.30([721, 10000000])]}
        let expected = "a400182c0d81000f1a000f424013" + "82d81e8219024119271" + "0d81e821902d11a00989680"
        #expect(try CBOREncoder().encode(update).toHex == expected)
        try expectConsistent(update)

        let json = try JSONEncoder().encode(update)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        #expect(object["minFeeA"] as? Int == 44)
        #expect(object["minUtxoValue"] as? Int == 1_000_000)
        #expect(try JSONDecoder().decode(ProtocolParamUpdate.self, from: json) == update)
        let minimal = try JSONDecoder().decode(
            ProtocolParamUpdate.self, from: Data(#"{"minPoolCost": 170000000}"#.utf8))
        #expect(minimal.minPoolCost == 170_000_000)
    }

    @Test("Shelley genesis extra entropy converts to and from a Nonce")
    func genesisExtraEntropy() throws {
        #expect(ProtocolParams.ExtraEntropy(.neutral) == .neutral)
        #expect(try ProtocolParams.ExtraEntropy.neutral.nonce() == .neutral)
        let nonce = try Nonce(hash: Data(repeating: 0xab, count: 32))
        let entropy = ProtocolParams.ExtraEntropy(nonce)
        #expect(entropy.tag == "Nonce")
        #expect(try entropy.nonce() == nonce)
        #expect(throws: (any Error).self) { try Nonce(hash: Data(repeating: 0, count: 31)) }

        let json = try JSONEncoder().encode(nonce)
        #expect(try JSONDecoder().decode(Nonce.self, from: json) == nonce)
        #expect(try JSONDecoder().decode(Nonce.self, from: Data(#"{"tag":"NeutralNonce"}"#.utf8)) == .neutral)
    }

    // MARK: 2. Codable agrees with toPrimitive

    @Test("NonNegativeInterval writes #6.30([n, d]) through Codable")
    func nonNegativeIntervalTag() throws {
        let interval = NonNegativeInterval(numerator: 1, denominator: 2)
        #expect(try interval.toCBORHex() == "d81e820102")
        #expect(try NonNegativeInterval.fromCBORHex("d81e820102") == interval)
        try expectConsistent(interval)
        // JSON is still the bare array.
        #expect(String(decoding: try JSONEncoder().encode(interval), as: UTF8.self) == "[1,2]")
        #expect(try JSONDecoder().decode(NonNegativeInterval.self, from: Data("[1,2]".utf8)) == interval)
    }

    @Test("Codable and toPrimitive agree for every type with its own encode(to:)")
    func codableMatchesPrimitive() throws {
        let keyHash = try VerificationKeyHash(payload: Data(repeating: 0x11, count: 28))
        let otherHash = try VerificationKeyHash(payload: Data(repeating: 0x22, count: 28))
        let anchor = Anchor(
            anchorUrl: try Url("https://example.com/a.json"),
            anchorDataHash: AnchorDataHash(payload: Data(repeating: 0x33, count: 32)))
        let actionID = GovActionID(
            transactionID: try TransactionId(payload: Data(repeating: 0x44, count: 32)), govActionIndex: 1)
        let constitution = Constitution(anchor: anchor, scriptHash: nil)
        let rewardA = Data([0xe0] + Array(repeating: 0x55, count: 28))
        let rewardB = Data([0xe0] + Array(repeating: 0x01, count: 28))
        let cold = CommitteeColdCredential(credential: .verificationKeyHash(keyHash))
        let cold2 = CommitteeColdCredential(credential: .verificationKeyHash(otherHash))

        try expectConsistent(ExUnitPrices(
            memPrice: NonNegativeInterval(numerator: 1, denominator: 2),
            stepPrice: NonNegativeInterval(numerator: 3, denominator: 4)))
        try expectConsistent(ExUnits(mem: 10, steps: 20))
        try expectConsistent(UpdateCommittee(
            id: actionID, coldCredentials: [cold, cold2], credentialEpochs: [cold: 10, cold2: 20],
            interval: UnitInterval(numerator: 2, denominator: 3)))
        try expectConsistent(TreasuryWithdrawalsAction(withdrawals: [rewardA: 5, rewardB: 7], policyHash: nil))
        try expectConsistent(InfoAction())
        try expectConsistent(NoConfidence(id: nil))
        try expectConsistent(HardForkInitiationAction(id: nil, protocolVersion: ProtocolVersion(major: 10, minor: 0)))
        try expectConsistent(NewConstitution(id: actionID, constitution: constitution))
        try expectConsistent(ParameterChangeAction(
            id: actionID, protocolParamUpdate: ProtocolParamUpdate(minFeeB: 155_381), policyHash: nil))
        try expectConsistent(GovAction.infoAction(InfoAction()))
        try expectConsistent(constitution)
        try expectConsistent(Constitution(anchor: anchor, scriptHash: try ScriptHash(payload: Data(repeating: 9, count: 28))))
        try expectConsistent(DRep(credential: .verificationKeyHash(keyHash)))
        try expectConsistent(DRep(credential: .alwaysAbstain))
        try expectConsistent(Nonce.neutral)
        try expectConsistent(try MultiHostName(dnsName: "relay.example.com"))
        try expectConsistent(try SingleHostName(port: 3001, dnsName: "relay.example.com"))
        try expectConsistent(PoolOperator(poolKeyHash: try PoolKeyHash(payload: Data(repeating: 7, count: 28))))
        try expectConsistent(try OrderedSet<VerificationKeyHash>([keyHash, otherHash]))

        // The bytes that were wrong before.
        #expect(try InfoAction().toCBORHex() == "8106")
        let withdrawals = try TreasuryWithdrawalsAction(withdrawals: [rewardA: 5], policyHash: nil).toCBORHex()
        #expect(withdrawals == "8302a1581de0" + String(repeating: "55", count: 28) + "05f6")
        let committee = try UpdateCommittee(
            id: nil, coldCredentials: [cold], credentialEpochs: [:],
            interval: UnitInterval(numerator: 1, denominator: 2)).toCBORHex()
        #expect(committee == "8504f6d90102818200581c" + String(repeating: "11", count: 28) + "a0d81e820102")
    }

    @Test("A set written with an indefinite length decodes through Codable")
    func indefiniteSetThroughCodable() throws {
        let hash = String(repeating: "11", count: 28)
        let tagged = try OrderedSet<VerificationKeyHash>.fromCBORHex("d901029f581c" + hash + "ff")
        #expect(tagged.count == 1)
        let plain = try OrderedSet<VerificationKeyHash>.fromCBORHex("9f581c" + hash + "ff")
        #expect(plain.count == 1)
    }

    // MARK: 3. DRep

    @Test("DRep [2] and [3] take no further elements")
    func drepElementCount() throws {
        #expect(throws: (any Error).self) { try DRep.fromCBORHex("82024100") }
        #expect(throws: (any Error).self) { try DRep.fromCBORHex("82034100") }
        #expect(throws: (any Error).self) { try DRepType(from: .list([.uint(2), .bytes(Data([0]))])) }
        #expect(try DRep.fromCBORHex("8102").credential == .alwaysAbstain)
        #expect(try DRep.fromCBORHex("8103").credential == .alwaysNoConfidence)
        #expect(try DRep.fromCBORHex("9f02ff").credential == .alwaysAbstain)
        // A key hash DRep still needs its hash, of the right size.
        #expect(throws: (any Error).self) { try DRep.fromCBORHex("8100") }
        #expect(throws: (any Error).self) { try DRep.fromCBORHex("8200581b" + String(repeating: "00", count: 27)) }
    }

    // MARK: 4. UpdateCommittee

    @Test("A #6.258 set of cold credentials may be indefinite, and must be an array")
    func updateCommitteeSetTag() throws {
        let credential = "8200581c" + String(repeating: "11", count: 28)
        let indefinite = try UpdateCommittee.fromCBORHex("8504f6d901029f" + credential + "ffa0d81e820102")
        #expect(indefinite.coldCredentials.count == 1)
        let plainIndefinite = try UpdateCommittee.fromCBORHex("8504f69f" + credential + "ffa0d81e820102")
        #expect(plainIndefinite.coldCredentials.count == 1)
        // A tag around a map, or a number, is not a set.
        #expect(throws: (any Error).self) { try UpdateCommittee.fromCBORHex("8504f6d90102a0a0d81e820102") }
        #expect(throws: (any Error).self) { try UpdateCommittee.fromCBORHex("8504f6d9010200a0d81e820102") }
    }

    // MARK: 5. Anchors

    @Test("Anchor(from:) refuses a data hash that is not 32 bytes, wherever it is read")
    func anchorHashSize() throws {
        let shortAnchor = "826041" + "00"
        #expect(throws: (any Error).self) { try Anchor.fromCBORHex(shortAnchor) }
        #expect(throws: (any Error).self) { try Constitution.fromCBORHex("82" + shortAnchor + "f6") }
        #expect(throws: (any Error).self) { try VotingProcedure.fromCBORHex("8201" + shortAnchor) }
        #expect(throws: (any Error).self) {
            try Anchor.fromDict(.orderedDict([
                .string("anchorUrl"): .string("https://example.com"),
                .string("anchorDataHash"): .bytes(Data(repeating: 0, count: 31)),
            ]))
        }
        let anchor = try Anchor.fromCBORHex("82605820" + zero32)
        #expect(anchor.anchorDataHash.payload.count == 32)
        #expect(try VotingProcedure.fromCBORHex("820182605820" + zero32).anchor == anchor)
    }

    // MARK: 6. Hash lengths

    @Test("PoolOperator and DRep(from:as:) refuse a hash of the wrong length")
    func hashLengths() throws {
        #expect(throws: (any Error).self) { try PoolOperator(from: Data(repeating: 1, count: 27)) }
        #expect(throws: (any Error).self) { try PoolOperator(from: Data(repeating: 1, count: 32)) }
        let shortBech32 = try #require(Bech32().encode(hrp: "pool", witprog: Data(repeating: 1, count: 27)))
        #expect(throws: (any Error).self) { try PoolOperator(from: shortBech32) }
        #expect(throws: (any Error).self) { try PoolOperator.fromCBORHex("581b" + String(repeating: "01", count: 27)) }
        let pool = try PoolOperator(from: Data(repeating: 1, count: 28))
        #expect(try PoolOperator(from: try pool.toBech32()) == pool)
        // JSON is still the bech32 id.
        let json = try JSONEncoder().encode(pool)
        #expect(String(decoding: json, as: UTF8.self) == "\"\(try pool.toBech32())\"")
        #expect(try JSONDecoder().decode(PoolOperator.self, from: json) == pool)

        #expect(throws: (any Error).self) { try DRep(from: Data(repeating: 1, count: 27), as: .keyHash) }
        #expect(throws: (any Error).self) { try DRep(from: Data(repeating: 1, count: 29), as: .scriptHash) }
        #expect(try DRep(from: Data(repeating: 1, count: 28), as: .scriptHash).code == 1)
    }

    // MARK: 7. dns_name

    @Test("A relay's DNS name is at most 128 bytes of UTF-8, on decode and on construction")
    func dnsNameSize() throws {
        let max = String(repeating: "a", count: 128)
        let over = String(repeating: "a", count: 129)
        // 65 characters but 130 bytes: the ledger counts bytes.
        let multibyte = String(repeating: "é", count: 65)
        #expect(try SingleHostName(port: nil, dnsName: max).dnsName == max)
        #expect(throws: (any Error).self) { try SingleHostName(port: nil, dnsName: over) }
        #expect(throws: (any Error).self) { try SingleHostName(port: 1, dnsName: multibyte) }
        #expect(try MultiHostName(dnsName: max).dnsName == max)
        #expect(throws: (any Error).self) { try MultiHostName(dnsName: over) }
        #expect(throws: (any Error).self) { try MultiHostName(dnsName: multibyte) }

        let overHex = "7881" + String(repeating: "61", count: 129)
        #expect(throws: (any Error).self) { try SingleHostName.fromCBORHex("8301f6" + overHex) }
        #expect(throws: (any Error).self) { try MultiHostName.fromCBORHex("8202" + overHex) }
        #expect(throws: (any Error).self) { try Relay.fromCBORHex("8301f6" + overHex) }
        #expect(throws: (any Error).self) { try Relay.fromCBORHex("8202" + overHex) }
        let maxHex = "7880" + String(repeating: "61", count: 128)
        #expect(try Relay.fromCBORHex("8202" + maxHex) == .multiHostName(try MultiHostName(dnsName: max)))
    }

    // MARK: 8. Old-style outputs

    @Test("An old-style output may be an indefinite-length array, and keeps its bytes")
    func indefiniteLegacyOutput() throws {
        let address = try Address(from: .string(addressText))
        let definite = try TransactionOutput(address: address, amount: Value(coin: 1_000_000)).toCBORHex()
        #expect(definite.hasPrefix("82"))
        let indefinite = "9f" + String(definite.dropFirst(2)) + "ff"
        let output = try TransactionOutput.fromCBORHex(indefinite)
        #expect(output.address == address)
        #expect(output.amount.coin == 1_000_000)
        #expect(try output.toCBORHex() == indefinite)

        // With a datum hash (Alonzo and later), and with too many elements.
        let datumHash = "5820" + String(repeating: "aa", count: 32)
        let open = String(indefinite.dropLast(2))
        let withHash = try TransactionOutput.fromCBORHex(open + datumHash + "ff")
        #expect(withHash.datumHash?.payload == Data(repeating: 0xaa, count: 32))
        #expect(throws: (any Error).self) {
            try TransactionOutput.fromCBORHex(open + datumHash + datumHash + "ff")
        }
        #expect(try ShelleyTransactionOutput(from: .indefiniteList(IndefiniteList([
            address.toPrimitive(), .uint(5),
        ]))).amount.coin == 5)
    }

    // MARK: 9. ExUnits

    @Test("ExUnits are limited to Int64.max, as the ledger's decoder is")
    func exUnitsRange() throws {
        let max = try ExUnits.fromCBORHex("821b7fffffffffffffff1b7fffffffffffffff")
        #expect(max.mem == UInt64(Int64.max))
        #expect(throws: (any Error).self) { try ExUnits.fromCBORHex("821b800000000000000001") }
        #expect(throws: (any Error).self) { try ExUnits.fromCBORHex("82011b8000000000000000") }
        #expect(throws: (any Error).self) { try ExUnits(mem: UInt64.max, steps: 0).toCBORData() }
        #expect(throws: (any Error).self) { try ExUnits(mem: 0, steps: UInt64(Int64.max) + 1).validate() }
        // The same limit for the protocol parameter that holds them.
        #expect(throws: (any Error).self) { try ProtocolParamUpdate.fromCBORHex("a114821b800000000000000001") }
    }

    // MARK: 10. One datum per output

    @Test("An output with both a datum hash and a datum option is refused, in CBOR and JSON alike")
    func oneDatum() throws {
        let address = try Address(from: .string(addressText))
        let hash = try DatumHash(payload: Data(repeating: 1, count: 32))
        let inline = DatumOption(datum: .data(try SwiftCardanoCore.Unit().toPlutusData()))
        let both = TransactionOutput(
            address: address, amount: Value(coin: 1), datumHash: hash, datumOption: inline, postAlonzo: true)
        #expect(throws: (any Error).self) { try both.toCBORData() }
        #expect(throws: (any Error).self) { try both.toDict() }
        #expect(throws: (any Error).self) { try both.validate() }
        #expect(throws: (any Error).self) { try JSONEncoder().encode(both) }

        // Either one alone writes the same datum to CBOR and JSON.
        let inlineOnly = TransactionOutput(address: address, amount: Value(coin: 1), datumOption: inline, postAlonzo: true)
        try inlineOnly.validate()
        #expect(try TransactionOutput.fromCBOR(data: try inlineOnly.toCBORData()).datumOption == inline)
        #expect(try TransactionOutput.fromDict(try inlineOnly.toDict()).datumOption == inline)
        let hashOnly = TransactionOutput(address: address, amount: Value(coin: 1), datumHash: hash, postAlonzo: true)
        #expect(try TransactionOutput.fromCBOR(data: try hashOnly.toCBORData()).datumHash == hash)
        #expect(try TransactionOutput.fromDict(try hashOnly.toDict()).datumHash == hash)

        // A dict carrying a second datum under `_datumHash` is refused.
        guard case .orderedDict(var dict) = try inlineOnly.toDict() else {
            Issue.record("toDict did not return a dict")
            return
        }
        dict[.string("_datumHash")] = .string(Data(repeating: 1, count: 32).base64EncodedString())
        #expect(throws: (any Error).self) { try TransactionOutput.fromDict(.orderedDict(dict)) }
    }
}

@Suite("Records written as indefinite-length arrays")
struct IndefiniteRecordTests {
    @Test("Relays and governance action ids read indefinite-length arrays")
    func indefinite() throws {
        // single_host_addr = (0, port / null, ipv4 / null, ipv6 / null)
        let relay = try Relay.fromCBORHex("9f00f6f6f6ff")
        guard case .singleHostAddr = relay else {
            Issue.record("expected a single-host-addr relay, got \(relay)")
            return
        }
        let id = try GovActionID.fromCBORHex("9f5820" + String(repeating: "11", count: 32) + "00ff")
        #expect(id.govActionIndex == 0)
    }

    @Test("A governance action id with extra elements is rejected")
    func extraElements() {
        #expect(throws: (any Error).self) {
            try GovActionID.fromCBORHex("835820" + String(repeating: "11", count: 32) + "0000")
        }
    }
}
