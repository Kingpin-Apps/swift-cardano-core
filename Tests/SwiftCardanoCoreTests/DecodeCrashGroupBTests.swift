import Testing
import BigInt
import Foundation
import OrderedCollections
@testable import SwiftCardanoCore

/// Inputs that used to crash the process on decode (certificates, stake pools,
/// governance, native scripts, legacy). Each must now throw, or decode when the
/// ledger accepts the value, and a decoded value must encode without trapping.
@Suite("Decode crash sweep: group B")
struct DecodeCrashGroupBTests {
    // MARK: - Helpers

    static func zeros(_ count: Int) -> String { String(repeating: "00", count: count) }
    /// A 28-byte key-hash stake credential: `[0, h'00…']`.
    static let credential = "8200581c" + zeros(28)
    static let poolKeyHash = "581c" + zeros(28)
    static let hash32 = "5820" + zeros(32)
    static let maxUInt64 = "1bffffffffffffffff"

    /// Replaces one key of a dictionary primitive.
    static func replacing(_ key: String, with value: Primitive, in dict: Primitive) throws -> Primitive {
        guard case var .orderedDict(entries) = dict else {
            throw CardanoCoreError.valueError("expected a dict")
        }
        entries[.string(key)] = value
        return .orderedDict(entries)
    }

    // MARK: - Certificate dispatch

    @Test("A certificate code above Int.max throws")
    func certificateCodeOutOfRange() throws {
        #expect(throws: (any Error).self) { try Certificate.fromCBORHex("81" + Self.maxUInt64) }
        #expect(throws: (any Error).self) { try Certificate.fromDict(.list([.uint(.max)])) }
    }

    @Test("Certificate.load throws on a cborHex that is not hex")
    func certificateLoadBadHex() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("crash-b-\(UUID().uuidString).json").path
        try #"{"type": "x", "description": "y", "cborHex": "zz"}"#
            .write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(throws: (any Error).self) { try Certificate.load(from: path) }
    }

    // MARK: - Coins up to 2^64 - 1 decode and re-encode

    /// Every Conway certificate that carries a coin, with a 2^64-1 coin.
    static let maxCoinCertificates: [String] = {
        let cred: String = credential
        let pool: String = poolKeyHash
        let coin: String = maxUInt64
        var hexes: [String] = []
        hexes.append("8307" + cred + coin)                           // reg_cert
        hexes.append("8308" + cred + coin)                           // unreg_cert
        hexes.append("840b" + cred + pool + coin)                    // stake_reg_deleg_cert
        hexes.append("840c" + cred + "8102" + coin)                  // vote_reg_deleg_cert
        hexes.append("850d" + cred + pool + "8102" + coin)           // stake_vote_reg_deleg_cert
        hexes.append("8410" + cred + coin + "f6")                    // reg_drep_cert
        hexes.append("8311" + cred + coin)                           // unreg_drep_cert
        return hexes
    }()

    @Test("Certificates with a 2^64-1 coin decode and re-encode", arguments: maxCoinCertificates)
    func certificateMaxCoin(hex: String) throws {
        let certificate = try Certificate.fromCBORHex(hex)
        #expect(try certificate.toCBORHex() == hex)
        // The text-envelope payload and the dict form must not trap either.
        _ = try certificate.toPrimitive()
    }

    @Test("A transaction body holding a 2^64-1 deposit certificate decodes and re-encodes")
    func transactionBodyMaxCoinCertificate() throws {
        let hex = "a4008001800200" + "0481" + "8307" + Self.credential + Self.maxUInt64
        let body = try TransactionBody.fromCBORHex(hex)
        _ = try body.toCBORData()
    }

    @Test("Negative coins and epochs in certificate dicts throw")
    func certificateDictNegative() throws {
        let drepCredential = DRepCredential(
            credential: .verificationKeyHash(VerificationKeyHash(payload: Data(count: 28))))
        let poolKeyHash = PoolKeyHash(payload: Data(count: 28))

        // The dicts are valid until the number is swapped, so each throw comes
        // from the range check rather than from another field.
        let maxRegDRep = try RegisterDRep(drepCredential: drepCredential, coin: .max, anchor: nil).toDict()
        #expect(try RegisterDRep.fromDict(maxRegDRep).coin == .max)
        let maxUnregDRep = try UnregisterDRep(drepCredential: drepCredential, coin: .max).toDict()
        #expect(try UnregisterDRep.fromDict(maxUnregDRep).coin == .max)
        let maxRetirement = try PoolRetirement(poolKeyHash: poolKeyHash, epoch: .max).toDict()
        #expect(try PoolRetirement.fromDict(maxRetirement).epoch == .max)

        let regDRep = try RegisterDRep(drepCredential: drepCredential, coin: 1, anchor: nil).toDict()
        #expect(throws: (any Error).self) {
            try RegisterDRep.fromDict(try Self.replacing("coin", with: .int(-1), in: regDRep))
        }
        let unregDRep = try UnregisterDRep(drepCredential: drepCredential, coin: 1).toDict()
        #expect(throws: (any Error).self) {
            try UnregisterDRep.fromDict(try Self.replacing("coin", with: .int(-1), in: unregDRep))
        }
        let retirement = try PoolRetirement(poolKeyHash: poolKeyHash, epoch: 1).toDict()
        #expect(throws: (any Error).self) {
            try PoolRetirement.fromDict(try Self.replacing("epoch", with: .int(-1), in: retirement))
        }
    }

    // MARK: - Text-envelope payload inits throw instead of trapping

    @Test("Payload inits throw on a payload that is not the certificate")
    func payloadInitsThrow() throws {
        let junk = Data([0x00])
        #expect(throws: (any Error).self) { try StakeRegistration(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try StakeDeregistration(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try StakeDelegation(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try PoolRetirement(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try GenesisKeyDelegation(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try MoveInstantaneousRewards(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try Register(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try Unregister(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try VoteDelegate(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try StakeVoteDelegate(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try StakeRegisterDelegate(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try VoteRegisterDelegate(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try StakeVoteRegisterDelegate(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try AuthCommitteeHot(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try ResignCommitteeCold(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try RegisterDRep(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try UnregisterDRep(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try UpdateDRep(payload: junk, type: nil, description: nil) }
        #expect(throws: (any Error).self) { try ProposalProcedure(payload: junk, type: nil, description: nil) }
    }

    // MARK: - Stake pools

    @Test("Pool registration with a pledge and cost above Int.max decodes and re-encodes")
    func poolPledgeAboveIntMax() throws {
        // pledge 2^63, cost 2^64 - 1: both are `coin`, a uint up to 2^64 - 1.
        let hex = "8a03" + Self.poolKeyHash + Self.hash32
            + "1b8000000000000000" + Self.maxUInt64
            + "d81e820001" + "581de0" + Self.zeros(28) + "80" + "80" + "f6"
        let certificate = try Certificate.fromCBORHex(hex)
        guard case let .poolRegistration(registration) = certificate else {
            Issue.record("expected a pool registration"); return
        }
        #expect(registration.poolParams.pledge == 1 << 63)
        #expect(registration.poolParams.cost == .max)
        #expect(try certificate.toCBORHex() == hex)
        #expect(try PoolParams.fromDict(try registration.poolParams.toDict()).cost == .max)
    }

    @Test("PoolParams dict margins above one or over zero throw")
    func poolParamsDictMargin() throws {
        let params = PoolParams(
            poolOperator: PoolKeyHash(payload: Data(count: 28)),
            vrfKeyHash: VrfKeyHash(payload: Data(count: 32)),
            pledge: 1,
            cost: 1,
            margin: UnitInterval(numerator: 1, denominator: 2),
            rewardAccount: RewardAccountHash(payload: Data([0xe0] + Array(repeating: 0, count: 28))),
            poolOwners: .list([]),
            relays: nil,
            poolMetadata: nil
        )
        let dict = try params.toDict()
        #expect(try PoolParams.fromDict(dict).pledge == 1)
        #expect(throws: (any Error).self) {
            try PoolParams.fromDict(try Self.replacing("margin", with: .list([.uint(1), .uint(0)]), in: dict))
        }
        #expect(throws: (any Error).self) {
            try PoolParams.fromDict(try Self.replacing("margin", with: .list([.uint(3), .uint(2)]), in: dict))
        }
        #expect(throws: (any Error).self) {
            try PoolParams.fromDict(try Self.replacing("pledge", with: .int(-1), in: dict))
        }
    }

    @Test("Relay ports outside 0...65535 throw, 65535 decodes")
    func relayPorts() throws {
        #expect(throws: (any Error).self) { try Relay.fromCBORHex("8400" + Self.maxUInt64 + "f6f6") }
        #expect(throws: (any Error).self) { try Relay.fromCBORHex("84001a00010000f6f6") }
        #expect(throws: (any Error).self) { try Relay.fromCBORHex("8301" + Self.maxUInt64 + "f6") }
        let addr = try Relay.fromCBORHex("840019fffff6f6")
        guard case let .singleHostAddr(single) = addr else {
            Issue.record("expected a single host address"); return
        }
        #expect(single.port == 65535)
        #expect(try addr.toCBORHex() == "840019fffff6f6")
        let name = try Relay.fromCBORHex("830119ffff63612e62")
        guard case let .singleHostName(host) = name else {
            Issue.record("expected a single host name"); return
        }
        #expect(host.port == 65535)
        #expect(throws: (any Error).self) {
            try SingleHostName.fromDict(.orderedDict([.string("code"): .uint(1), .string("port"): .int(-1)]))
        }
    }

    @Test("Operational certificates with negative counters throw")
    func operationalCertificateNegative() throws {
        #expect(throws: (any Error).self) {
            try OperationalCertificate.fromCBORHex("84" + Self.hash32 + "20" + "00" + "40")
        }
        #expect(throws: (any Error).self) {
            try OperationalCertificate.fromCBORHex("84" + Self.hash32 + "00" + "20" + "40")
        }
        #expect(throws: (any Error).self) {
            try OperationalCertificate.fromDict(.orderedDict([
                .string("hotVKey"): .bytes(Data(count: 32)),
                .string("sequenceNumber"): .int(-1),
                .string("kesPeriod"): .uint(0),
                .string("sigma"): .bytes(Data(count: 64)),
            ]))
        }
    }

    // MARK: - Native scripts

    @Test("Native scripts with missing elements throw", arguments: ["8105", "8104", "8101", "8102", "8103", "8100"])
    func nativeScriptShort(hex: String) throws {
        #expect(throws: (any Error).self) { try NativeScript.fromCBORHex(hex) }
    }

    @Test("A witness set holding a truncated native script throws")
    func witnessSetTruncatedNativeScript() throws {
        #expect(throws: (any Error).self) { try TransactionWitnessSet.fromCBORHex("a1018181" + "05") }
    }

    @Test("ScriptNofK n is an int64: out of range throws, negative decodes")
    func scriptNofK() throws {
        #expect(throws: (any Error).self) { try NativeScript.fromCBORHex("8303" + Self.maxUInt64 + "80") }
        let negative = try NativeScript.fromCBORHex("830320" + "80")
        guard case let .scriptNofK(script) = negative else {
            Issue.record("expected script_n_of_k"); return
        }
        #expect(script.required == -1)
        #expect(try negative.toCBORHex() == "83032080")
        #expect(try ScriptNofK.fromDict(try script.toDict()).required == -1)
    }

    @Test("Native script dicts with a negative slot throw")
    func nativeScriptNegativeSlot() throws {
        let dict: Primitive = .orderedDict([.string("slot"): .int(-1)])
        #expect(throws: (any Error).self) { try AfterScript.fromDict(dict) }
        #expect(throws: (any Error).self) { try BeforeScript.fromDict(dict) }
        let max: Primitive = .orderedDict([.string("slot"): .uint(.max)])
        #expect(try AfterScript.fromDict(max).slot == .max)
    }

    // MARK: - Governance

    @Test("A governance action code above Int.max throws")
    func govActionCodeOutOfRange() throws {
        #expect(throws: (any Error).self) { try GovAction.fromCBORHex("81" + Self.maxUInt64) }
        let code: Primitive = .uint(.max)
        #expect(throws: (any Error).self) {
            try HardForkInitiationAction(from: .list([code, .null, .list([.uint(10), .uint(0)])]))
        }
        #expect(throws: (any Error).self) {
            try TreasuryWithdrawalsAction(from: .list([code, .orderedDict([:]), .null]))
        }
        #expect(throws: (any Error).self) {
            try UpdateCommittee(from: .list([code, .null, .list([]), .orderedDict([:]),
                                             try UnitInterval(numerator: 1, denominator: 2).toPrimitive()]))
        }
        #expect(throws: (any Error).self) { try NewConstitution(from: .list([code, .null, .null])) }
        #expect(throws: (any Error).self) { try NoConfidence(from: .list([code, .null])) }
    }

    @Test("A governance action index above 65535 throws, 65535 decodes")
    func govActionIndex() throws {
        #expect(throws: (any Error).self) { try GovActionID.fromCBORHex("82" + Self.hash32 + "1a00010000") }
        #expect(throws: (any Error).self) { try GovActionID.fromCBORHex("82" + Self.hash32 + "20") }
        let id = try GovActionID.fromCBORHex("82" + Self.hash32 + "19ffff")
        #expect(id.govActionIndex == 65535)
        // The CIP-129 form: 32-byte transaction id then the big-endian index.
        #expect(throws: (any Error).self) { try GovActionID(from: Data(count: 32) + Data([0x01, 0x00, 0x00])) }
        #expect(try GovActionID(from: Data(count: 32) + Data([0xff, 0xff])).govActionIndex == 65535)
    }

    @Test("Voting thresholds with missing entries throw")
    func votingThresholds() throws {
        #expect(throws: (any Error).self) { try PoolVotingThresholds.fromCBORHex("80") }
        #expect(throws: (any Error).self) { try PoolVotingThresholds.fromCBORHex("85f6f6f6f6f6") }
        let half = "d81e820102"
        let pool = try PoolVotingThresholds.fromCBORHex("85" + String(repeating: half, count: 5))
        #expect(pool.thresholds.count == 5)
        #expect(throws: (any Error).self) {
            try DrepVotingThresholds.fromCBORHex("85" + String(repeating: half, count: 5))
        }
        let drep = try DrepVotingThresholds.fromCBORHex("8a" + String(repeating: half, count: 10))
        #expect(drep.thresholds.count == 10)
    }

    @Test("A vote above Int.max throws")
    func voteOutOfRange() throws {
        #expect(throws: (any Error).self) { try VotingProcedure.fromCBORHex("82" + Self.maxUInt64 + "f6") }
        #expect(throws: (any Error).self) { try Vote(from: .uint(.max)) }
        #expect(try Vote(from: .uint(2)) == .abstain)
        // Body key 19 as reported, with a real voter key hash so the vote is reached.
        let voter: String = "8200" + Self.poolKeyHash
        let actionID: String = "82" + Self.hash32 + "00"
        let procedure: String = "82" + Self.maxUInt64 + "f6"
        let procedures: String = "a1" + voter + "a1" + actionID + procedure
        #expect(throws: (any Error).self) { try VotingProcedures.fromCBORHex(procedures) }
    }

    @Test("A treasury withdrawal of 2^64-1 decodes and re-encodes")
    func treasuryWithdrawalMaxCoin() throws {
        let anchor = "82" + "6161" + Self.hash32
        let action = "8302" + "a1" + "40" + Self.maxUInt64 + "f6"
        let proposal = "84" + "00" + "40" + action + anchor
        let decoded = try ProposalProcedure.fromCBORHex(proposal)
        guard case let .treasuryWithdrawalsAction(withdrawals) = decoded.govAction else {
            Issue.record("expected a treasury withdrawal"); return
        }
        #expect(withdrawals.withdrawals.values.first == .max)
        #expect(try decoded.toCBORHex() == proposal)
        #expect(decoded.payload.toHex == proposal)
        // A withdrawal amount below zero is not a coin.
        #expect(throws: (any Error).self) {
            try TreasuryWithdrawalsAction(from: .list([.uint(2), .orderedDict([.bytes(Data()): .int(-1)]), .null]))
        }
    }

    @Test("A proposal with a parameter-change deposit of 2^64-1 re-encodes")
    func parameterChangeMaxDeposit() throws {
        let anchor = "82" + "6161" + Self.hash32
        // parameter_change_action = (0, gov_action_id / nil, {30: coin}, policy_hash / nil)
        let action = "8400" + "f6" + "a1181e" + Self.maxUInt64 + "f6"
        let proposal = "84" + "00" + "40" + action + anchor
        let decoded = try ProposalProcedure.fromCBORHex(proposal)
        #expect(try decoded.toCBORHex() == proposal)
    }

    @Test("Committee member epochs: negative throws, a uint decodes")
    func committeeMemberEpoch() throws {
        #expect(throws: (any Error).self) { try CommitteeMember.fromCBORHex("a1" + Self.credential + "20") }
        let member = try CommitteeMember.fromCBORHex("a1" + Self.credential + Self.maxUInt64)
        #expect(member.epoch == .max)
        #expect(try member.toCBORHex() == "a1" + Self.credential + Self.maxUInt64)
        #expect(throws: (any Error).self) {
            try UpdateCommittee(from: .list([.uint(4), .null, .list([]),
                                             .orderedDict([try Primitive.fromCBORHex(Self.credential): .int(-1)]),
                                             try UnitInterval(numerator: 1, denominator: 2).toPrimitive()]))
        }
    }

    @Test("Protocol versions outside uint .size 4 throw")
    func protocolVersion() throws {
        #expect(throws: (any Error).self) { try ProtocolVersion.fromCBORHex("82" + Self.maxUInt64 + "00") }
        #expect(throws: (any Error).self) { try ProtocolVersion.fromCBORHex("8200" + Self.maxUInt64) }
        #expect(throws: (any Error).self) { try ProtocolVersion.fromCBORHex("822000") }
        let version = try ProtocolVersion.fromCBORHex("820a00")
        #expect(version.major == 10 && version.minor == 0)
        // Reached through a hard-fork initiation action.
        #expect(throws: (any Error).self) { try GovAction.fromCBORHex("8301f6" + "82" + Self.maxUInt64 + "00") }
    }

    // MARK: - Legacy

    @Test("Update epochs: negative throws, 2^64-1 decodes and re-encodes")
    func updateEpoch() throws {
        #expect(throws: (any Error).self) { try Update.fromCBORHex("82a020") }
        let update = try Update.fromCBORHex("82a0" + Self.maxUInt64)
        #expect(update.epoch == .max)
        #expect(try update.toCBORHex() == "82a0" + Self.maxUInt64)
        #expect(try Update.fromDict(try update.toDict()).epoch == .max)
        #expect(throws: (any Error).self) {
            try Update.fromDict(.orderedDict([
                .string("proposedprotocolParamUpdates"): .orderedDict([:]),
                .string("epoch"): .int(-1),
            ]))
        }
        // The reported transaction body: key 6 holds the update.
        #expect(throws: (any Error).self) { try TransactionBody.fromCBORHex("a4008001800200" + "0682a020") }
    }

    @Test("Move instantaneous rewards out of range throw")
    func moveInstantaneousRewards() throws {
        let credential: Primitive = .list([.uint(0), .bytes(Data(count: 28))])
        // A source other than 0 or 1.
        #expect(throws: (any Error).self) {
            try MoveInstantaneousReward(from: .list([.uint(.max), .uint(0)]))
        }
        // A delta outside the CBOR int range.
        #expect(throws: (any Error).self) {
            try MoveInstantaneousReward(from: .list([
                .uint(0), .orderedDict([credential: .bigInt(BigInt(1) << 64)]),
            ]))
        }
        // A key that is not a stake credential.
        #expect(throws: (any Error).self) {
            try MoveInstantaneousReward(from: .list([.uint(0), .orderedDict([.string("a"): .uint(1)])]))
        }
        // A negative coin to the other pot.
        #expect(throws: (any Error).self) {
            try MoveInstantaneousReward(from: .list([.uint(0), .int(-1)]))
        }
        #expect(throws: (any Error).self) {
            try MoveInstantaneousReward.fromDict(.orderedDict([
                .string("source"): .uint(0), .string("coin"): .int(-1),
            ]))
        }
        let mir = try MoveInstantaneousReward(from: .list([.uint(1), .uint(.max)]))
        #expect(mir.coin == .max)
        #expect(try MoveInstantaneousReward.fromDict(try mir.toDict()).coin == .max)
        // The extremes of delta_coin decode and re-encode.
        let extremes = try MoveInstantaneousReward(from: .list([
            .uint(0), .orderedDict([credential: .bigInt(-(BigInt(1) << 64))]),
        ]))
        #expect(extremes.rewards?.values.first == -(BigInt(1) << 64))
        #expect(try extremes.toCBORHex() == "8200a1" + "8200581c" + Self.zeros(28) + "3bffffffffffffffff")
    }
}
