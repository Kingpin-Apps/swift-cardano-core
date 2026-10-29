import Testing
import Foundation
import CBORCodable
@testable import SwiftCardanoCore

/// ConwayGenesis against the ledger's encoders (cardano-ledger
/// `Cardano.Ledger.Conway.Genesis`, `EncCBOR (UpgradeConwayPParams Identity)`,
/// `Constitution`, `Committee`, `Delegatee`, `DRepState`, `InjectionData`).
@Suite("ConwayGenesis CBOR and exact rationals")
struct ConwayGenesisCBORTests {
    static func bytes(_ byte: String, _ count: Int) -> String { String(repeating: byte, count: count) }
    static func tagged(_ pair: String) -> String { "d81e82" + pair }

    // MARK: A vector built by hand from the ledger's encoders

    /// `[motionNoConfidence 1/2, committeeNormal 51/100, committeeNoConfidence 3/5,
    ///   hardForkInitiation 2/3, ppSecurityGroup 1/4]`
    static let poolThresholds = "85" + tagged("0102") + tagged("18331864") + tagged("0305")
        + tagged("0203") + tagged("0104")
    /// Nine halves and a treasury withdrawal of 1/1.
    static let dRepThresholds = "8a" + String(repeating: tagged("0102"), count: 9) + tagged("0101")
    static let upgrade = "8a" + poolThresholds + dRepThresholds
        + "07"                      // committeeMinSize
        + "1892"                    // committeeMaxTermLength 146
        + "06"                      // govActionLifetime
        + "1b000000174876e800"      // govActionDeposit 100_000_000_000
        + "1a1dcd6500"              // dRepDeposit 500_000_000
        + "14"                      // dRepActivity 20
        + tagged("0f01")            // minFeeRefScriptCostPerByte 15
        + "820121"                  // plutusV3CostModel [1, -2]
    static let anchor = "82" + "6968747470733a2f2f61" + "5820" + bytes("00", 32)
    static let constitution = "82" + anchor + "581c" + bytes("11", 28)
    /// Two members: the script credential sorts first although its tag is 1.
    static let committee = "82" + "a2"
        + "8201581c" + bytes("22", 28) + "1864"
        + "8200581c" + bytes("11", 28) + "1903e8"
        + tagged("0203")
    /// `{ keyHash-33.. : DelegStakeVote pool-44.. drep-alwaysNoConfidence }`
    static let delegs = "a1" + "8200581c" + bytes("33", 28) + "8302581c" + bytes("44", 28) + "8103"
    /// `{ scriptHash-55.. : DRepState 100 (Just anchor) 500_000_000 {keyHash-33..} }`
    static let initialDReps = "a1" + "8201581c" + bytes("55", 28)
        + "84" + "1864" + "81" + anchor + "1a1dcd6500" + "d9010281" + "8200581c" + bytes("33", 28)
    /// `SJust (ConwayExtraConfig NoInjection (InjectionFromFile ["a", "b"] hash))`
    static let extraConfig = "81" + "82" + "8100" + "83" + "01" + "8261616162" + "5820" + bytes("66", 32)
    static let genesis = "86" + upgrade + constitution + committee + delegs + initialDReps + extraConfig

    @Test("The ledger's six-field layout decodes and re-encodes byte for byte")
    func vector() throws {
        let g = try ConwayGenesis.fromCBORHex(Self.genesis)
        #expect(g.poolVotingThresholds.motionNoConfidence == UnitInterval(numerator: 1, denominator: 2))
        #expect(g.poolVotingThresholds.committeeNormal == UnitInterval(numerator: 51, denominator: 100))
        #expect(g.poolVotingThresholds.committeeNoConfidence == UnitInterval(numerator: 3, denominator: 5))
        #expect(g.poolVotingThresholds.hardForkInitiation == UnitInterval(numerator: 2, denominator: 3))
        #expect(g.poolVotingThresholds.ppSecurityGroup == UnitInterval(numerator: 1, denominator: 4))
        #expect(g.dRepVotingThresholds.treasuryWithdrawal == UnitInterval(numerator: 1, denominator: 1))
        #expect(g.dRepVotingThresholds.motionNoConfidence == UnitInterval(numerator: 1, denominator: 2))
        #expect(g.committeeMaxTermLength == 146)
        #expect(g.govActionDeposit == 100_000_000_000)
        #expect(g.minFeeRefScriptCostPerByte == NonNegativeInterval(numerator: 15, denominator: 1))
        #expect(g.plutusV3CostModel == [1, -2])
        #expect(g.constitution.anchor.url == "https://a")
        #expect(g.constitution.script == Self.bytes("11", 28))
        #expect(g.committee.members["scriptHash-" + Self.bytes("22", 28)] == 100)
        #expect(g.committee.members["keyHash-" + Self.bytes("11", 28)] == 1000)
        #expect(g.committee.threshold == UnitInterval(numerator: 2, denominator: 3))

        let staker = try GenesisCredential(kind: .keyHash, hash: Data(repeating: 0x33, count: 28))
        #expect(g.delegs == [ConwayGenesisDelegation(
            credential: staker,
            delegatee: .stakeVote(pool: Data(repeating: 0x44, count: 28), dRep: .alwaysNoConfidence))])
        let dRep = try #require(g.initialDReps.first)
        #expect(dRep.credential.text == "scriptHash-" + Self.bytes("55", 28))
        #expect(dRep.state.expiry == 100 && dRep.state.deposit == 500_000_000)
        #expect(dRep.state.anchor?.dataHash == Self.bytes("00", 32))
        #expect(dRep.state.delegs == [staker])
        #expect(g.extraConfig == ConwayGenesisExtraConfig(
            delegs: .noInjection,
            initialDReps: .fromFile(path: ["a", "b"], hash: Data(repeating: 0x66, count: 32))))

        #expect(try g.toCBORHex() == Self.genesis)
    }

    @Test("A genesis built in Swift encodes as the ledger does")
    func encode() throws {
        let g = try ConwayGenesis.fromCBORHex(Self.genesis)
        let rebuilt = ConwayGenesis(
            poolVotingThresholds: g.poolVotingThresholds, dRepVotingThresholds: g.dRepVotingThresholds,
            committeeMinSize: 7, committeeMaxTermLength: 146, govActionLifetime: 6,
            govActionDeposit: 100_000_000_000, dRepDeposit: 500_000_000, dRepActivity: 20,
            // Unreduced on the way in, reduced on the way out.
            minFeeRefScriptCostPerByte: NonNegativeInterval(numerator: 30, denominator: 2),
            plutusV3CostModel: [1, -2],
            constitution: g.constitution,
            committee: Committee(members: g.committee.members, threshold: UnitInterval(numerator: 4, denominator: 6)),
            delegs: g.delegs, initialDReps: g.initialDReps, extraConfig: g.extraConfig)
        #expect(try rebuilt.toCBORHex() == Self.genesis)
    }

    @Test("No script hash and no extra configuration encode as null and []")
    func absent() throws {
        let noScript = "82" + Self.anchor + "f6"
        let constitution = try ConwayGenesisConstitution(from: try Primitive.fromCBORHex(noScript))
        #expect(constitution.script == nil)
        #expect(try constitution.toPrimitive().toCBORHex() == noScript)

        let minimal = "86" + Self.upgrade + noScript + "82a0" + Self.tagged("0203") + "a0" + "a0" + "80"
        let g = try ConwayGenesis.fromCBORHex(minimal)
        #expect(g.extraConfig == nil && g.delegs.isEmpty && g.initialDReps.isEmpty)
        #expect(try g.toCBORHex() == minimal)
    }

    @Test("The flat twelve-field layout and wrong counts are refused")
    func strictCounts() throws {
        let g = try ConwayGenesis.fromCBORHex(Self.genesis)
        guard case .list(let outer) = try g.toPrimitive(), case .list(let upgrade) = outer[0] else {
            Issue.record("not a list"); return
        }
        #expect(throws: CardanoCoreError.self) { try ConwayGenesis(from: .list(upgrade + Array(outer.dropFirst()))) }
        #expect(throws: CardanoCoreError.self) { try ConwayGenesis(from: .list(Array(outer.dropLast()))) }
        #expect(throws: CardanoCoreError.self) {
            try ConwayGenesis(from: .list([.list(Array(upgrade.dropLast()))] + Array(outer.dropFirst())))
        }
        // An untagged threshold, a zero denominator, and a ratio above one.
        #expect(throws: CardanoCoreError.self) {
            try ConwayGenesisPoolVotingThresholds(from: .list(Array(repeating: .list([.uint(1), .uint(2)]), count: 5)))
        }
        #expect(throws: (any Error).self) { try Committee(from: try Primitive.fromCBORHex("82a0" + Self.tagged("0100"))) }
        #expect(throws: CardanoCoreError.self) { try Committee(from: try Primitive.fromCBORHex("82a0" + Self.tagged("0302"))) }
        // A credential hash of the wrong size, and an unknown credential tag.
        #expect(throws: CardanoCoreError.self) {
            try Committee(from: try Primitive.fromCBORHex("82a1" + "8200581b" + Self.bytes("11", 27) + "01" + Self.tagged("0102")))
        }
        #expect(throws: CardanoCoreError.self) {
            try Committee(from: try Primitive.fromCBORHex("82a1" + "8202581c" + Self.bytes("11", 28) + "01" + Self.tagged("0102")))
        }
    }

    @Test("A committee of more than 23 members is an indefinite-length map")
    func largeCommittee() throws {
        var members: [String: EpochNumber] = [:]
        for i in 0 ..< 24 { members["keyHash-" + Self.bytes(String(format: "%02x", i), 28)] = 1 }
        let committee = Committee(members: members, threshold: UnitInterval(numerator: 1, denominator: 2))
        let hex = try committee.toPrimitive().toCBORHex()
        #expect(hex.hasPrefix("82bf8200581c" + Self.bytes("00", 28) + "01"))
        #expect(try Committee(from: try Primitive.fromCBORHex(hex)) == committee)
    }

    // MARK: Exact values from the network files

    static func load(_ network: String) throws -> ConwayGenesis {
        let path = try #require(try getFilePath(
            forResource: "conway-genesis", ofType: "json", inDirectory: "data/config/\(network)"))
        return try ConwayGenesis.load(from: path)
    }

    @Test("Thresholds and the ref-script price read exactly", arguments: ["mainnet", "preprod", "preview", "sanchonet"])
    func networkFiles(_ network: String) throws {
        let g = try Self.load(network)
        #expect(g.minFeeRefScriptCostPerByte == NonNegativeInterval(numerator: 15, denominator: 1))
        #expect(g.dRepVotingThresholds.committeeNormal == UnitInterval(numerator: 67, denominator: 100))
        #expect(g.dRepVotingThresholds.ppGovGroup == UnitInterval(numerator: 3, denominator: 4))
        #expect(g.poolVotingThresholds.hardForkInitiation == UnitInterval(numerator: 51, denominator: 100))
        // Sanchonet writes its quorum as the decimal 0.67, the others as 2/3.
        #expect(g.committee.threshold == (network == "sanchonet"
            ? UnitInterval(numerator: 67, denominator: 100) : UnitInterval(numerator: 2, denominator: 3)))

        let viaCBOR = try ConwayGenesis(from: try g.toPrimitive())
        #expect(viaCBOR == g)
        let viaJSON = try JSONDecoder().decode(ConwayGenesis.self, from: try JSONEncoder().encode(g))
        #expect(viaJSON == g)
    }

    @Test("Rationals are written to JSON as the ledger writes them")
    func jsonForm() throws {
        let g = try Self.load("mainnet")
        let object = try #require(try JSONSerialization.jsonObject(with: try JSONEncoder().encode(g)) as? [String: Any])
        let committee = try #require(object["committee"] as? [String: Any])
        // 2/3 has no finite decimal: a fraction object.
        let threshold = try #require(committee["threshold"] as? [String: Any])
        #expect((threshold["numerator"] as? NSNumber)?.intValue == 2)
        #expect((threshold["denominator"] as? NSNumber)?.intValue == 3)
        // 0.51 is written as the number 0.51, exactly.
        let text = try #require(String(data: try JSONEncoder().encode(g.poolVotingThresholds), encoding: .utf8))
        #expect(text.contains("\"ppSecurityGroup\":0.51"))
        #expect(object["minFeeRefScriptCostPerByte"] as? NSNumber == 15)
    }

    @Test("Out-of-range JSON thresholds and bad credentials are refused")
    func jsonRejects() throws {
        let path = try #require(try getFilePath(
            forResource: "conway-genesis", ofType: "json", inDirectory: "data/config/mainnet"))
        let base = try String(contentsOfFile: path, encoding: .utf8)
        func decode(_ text: String) throws -> ConwayGenesis {
            try JSONDecoder().decode(ConwayGenesis.self, from: Data(text.utf8))
        }
        #expect(throws: (any Error).self) {
            try decode(base.replacingOccurrences(of: "\"ppSecurityGroup\": 0.51", with: "\"ppSecurityGroup\": 1.01"))
        }
        #expect(throws: (any Error).self) {
            try decode(base.replacingOccurrences(of: "\"ppSecurityGroup\": 0.51", with: "\"ppSecurityGroup\": -0.5"))
        }
        #expect(throws: (any Error).self) {
            try decode(base.replacingOccurrences(of: "\"minFeeRefScriptCostPerByte\": 15",
                                                 with: "\"minFeeRefScriptCostPerByte\": 1e-20"))
        }
        #expect(throws: (any Error).self) {
            try decode(base.replacingOccurrences(of: "scriptHash-df0e", with: "pubKey-df0e"))
        }
        // A decimal threshold reads exactly.
        let exact = try decode(base.replacingOccurrences(of: "\"ppSecurityGroup\": 0.51",
                                                         with: "\"ppSecurityGroup\": 5.77e-2"))
        #expect(exact.poolVotingThresholds.ppSecurityGroup == UnitInterval(numerator: 577, denominator: 10000))
    }

    @Test("delegs, initialDReps and extraConfig round-trip through JSON")
    func jsonExtras() throws {
        let g = try ConwayGenesis.fromCBORHex(Self.genesis)
        let data = try JSONEncoder().encode(g)
        let back = try JSONDecoder().decode(ConwayGenesis.self, from: data)
        #expect(back.delegs == g.delegs)
        #expect(back.extraConfig == g.extraConfig)
        // The ledger's JSON does not carry a DRep's delegators.
        #expect(back.initialDReps.first?.state.delegs == [])
        #expect(back.initialDReps.first?.state.expiry == 100)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let delegs = try #require(object["delegs"] as? [String: Any])
        let entry = try #require(delegs["keyHash-" + Self.bytes("33", 28)] as? [String: Any])
        #expect(entry["kind"] as? String == "DelegStakeVote")
        #expect(entry["dRep"] as? String == "drep-alwaysNoConfidence")
    }
}
