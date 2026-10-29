import Testing
import Foundation
import OrderedCollections
@testable import SwiftCardanoCore

/// Shelley genesis against the ledger's `EncCBOR`/`DecCBOR ShelleyGenesis`
/// (cardano-ledger `eras/shelley/impl/src/Cardano/Ledger/Shelley/Genesis.hs`)
/// and its JSON instances.
@Suite struct ShelleyGenesisCBORTests {
    // MARK: Hand-built vectors
    //
    // Each piece follows the ledger's encoder, at the Shelley protocol
    // version: `encodeUTCTime`, `Network` as a word8, `activeSlotsCoeffEncCBOR`
    // (no tag 30), `Micro` as an integer, `PParams ShelleyEra` as 17 fields
    // with `BoundedRatio` always tagged, `encodeMap` for genDelegs, `ListMap`
    // as a definite map, `ShelleyGenesisStaking` as `[pools, stake]` and the
    // `StrictMaybe ShelleyExtraConfig` as `[]` or `[x]`.

    static let genesisKey = String(repeating: "11", count: 28)
    static let delegate = String(repeating: "22", count: 28)
    static let vrf = String(repeating: "33", count: 32)
    static let address = "60" + String(repeating: "44", count: 28)
    static let stakeKey = String(repeating: "55", count: 28)
    static let poolKey = String(repeating: "66", count: 28)
    static let fileHash = String(repeating: "77", count: 32)

    static let protocolParamsHex =
        "91"                       // list(17)
        + "182c"                   // minFeeA 44
        + "1a00025ef5"             // minFeeB 155381
        + "1a00010000"             // maxBlockBodySize 65536
        + "194000"                 // maxTxSize 16384
        + "19044c"                 // maxBlockHeaderSize 1100
        + "1a001e8480"             // keyDeposit 2000000
        + "1a1dcd6500"             // poolDeposit 500000000
        + "12"                     // eMax 18
        + "1896"                   // nOpt 150
        + "d81e82030a"             // a0 3/10
        + "d81e82031903e8"         // rho 3/1000
        + "d81e820105"             // tau 1/5
        + "d81e820101"             // d 1/1
        + "8100"                   // NeutralNonce
        + "820200"                 // ProtVer 2.0
        + "1a000f4240"             // minUTxOValue 1000000
        + "1a1443fd00"             // minPoolCost 340000000

    static func genesisHex(extraConfig: String = "80") -> String {
        "90"                                        // list(16)
        + "83" + "1907e1" + "19010a" + "1b0116253fec1c3000" // 2017, day 266, 78291 s
        + "1a2d964a09"                              // networkMagic 764824073
        + "01"                                      // Mainnet
        + "820114"                                  // activeSlotsCoeff [1, 20]
        + "190870"                                  // securityParam 2160
        + "1a00069780"                              // epochLength 432000
        + "1a0001fa40"                              // slotsPerKESPeriod 129600
        + "183e"                                    // maxKESEvolutions 62
        + "1a000f4240"                              // slotLength 1 s
        + "05"                                      // updateQuorum
        + "1b009fdf42f6e48000"                      // maxLovelaceSupply
        + protocolParamsHex
        + "a1" + "581c" + genesisKey + "82" + "581c" + delegate + "5820" + vrf
        + "a1" + "581d" + address + "1a000f4240"
        + "82" + "a0" + "a1" + "581c" + stakeKey + "581c" + poolKey
        + extraConfig
    }

    /// `SJust (ShelleyExtraConfig NoInjection (InjectionFromFile ["a", "b.json"] h) (EmbeddedInjection {}))`.
    static let extraConfigHex =
        "81" + "83"
        + "8100"
        + "8301" + "82" + "6161" + "66622e6a736f6e" + "5820" + fileHash
        + "8202" + "a0"

    func data(_ hex: String) -> Data { Data(hex.hexStringToData) }

    @Test("Decodes the ledger's 16-field layout and encodes it back byte for byte")
    func vector() throws {
        let genesis = try ShelleyGenesis.fromCBOR(data: data(Self.genesisHex()))
        #expect(genesis.systemStart == "2017-09-23T21:44:51Z")
        #expect(genesis.networkId == "Mainnet")
        #expect(genesis.activeSlotsCoeff == UnitInterval(numerator: 1, denominator: 20))
        #expect(genesis.securityParam == 2160)
        #expect(genesis.slotLength == 1)
        #expect(genesis.protocolParams.a0 == NonNegativeInterval(numerator: 3, denominator: 10))
        #expect(genesis.protocolParams.rho == UnitInterval(numerator: 3, denominator: 1000))
        #expect(genesis.protocolParams.tau == UnitInterval(numerator: 1, denominator: 5))
        #expect(genesis.protocolParams.decentralisationParam == UnitInterval(numerator: 1, denominator: 1))
        #expect(genesis.protocolParams.extraEntropy == .neutral)
        #expect(genesis.genDelegs[Self.genesisKey] == GenDelegation(delegate: Self.delegate, vrf: Self.vrf))
        #expect(genesis.initialFunds[Self.address] == 1_000_000)
        #expect(genesis.staking.stake[Self.stakeKey] == Self.poolKey)
        #expect(genesis.extraConfig == nil)
        #expect(try genesis.toCBORHex() == Self.genesisHex())
    }

    @Test("extraConfig and its injection sources round-trip")
    func extraConfig() throws {
        let hex = Self.genesisHex(extraConfig: Self.extraConfigHex)
        let genesis = try ShelleyGenesis.fromCBOR(data: data(hex))
        let extra = try #require(genesis.extraConfig)
        #expect(extra.initialFunds == .none)
        #expect(extra.stakePools == .file(path: ["a", "b.json"], hash: Self.fileHash))
        #expect(extra.stakeCredentials == .embedded([:]))
        #expect(try genesis.toCBORHex() == hex)

        // And through JSON.
        let json = try JSONEncoder().encode(genesis)
        #expect(try JSONDecoder().decode(ShelleyGenesis.self, from: json) == genesis)
    }

    @Test("A Nonce extra entropy is [1, hash]")
    func nonce() throws {
        let hash = String(repeating: "ab", count: 32)
        let params = Self.protocolParamsHex.replacingOccurrences(of: "8100820200", with: "82015820\(hash)820200")
        let decoded = try ProtocolParams(from: Primitive.fromCBOR(data: data(params)))
        #expect(decoded.extraEntropy == ProtocolParams.ExtraEntropy(tag: "Nonce", contents: hash))
        #expect(try decoded.toPrimitive().toCBORHex() == params)

        let json = try JSONEncoder().encode(decoded.extraEntropy)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: String])
        #expect(object == ["tag": "Nonce", "contents": hash])
    }

    @Test("Fractional seconds in systemStart are exact")
    func utcTime() throws {
        // 2022-10-25T00:00:00.5Z: day 298, half a second in picoseconds.
        let start = "83" + "1907e6" + "19012a" + "1b000000746a528800"
        let hex = Self.genesisHex().replacingOccurrences(
            of: "83" + "1907e1" + "19010a" + "1b0116253fec1c3000", with: start)
        let genesis = try ShelleyGenesis.fromCBOR(data: data(hex))
        #expect(genesis.systemStart == "2022-10-25T00:00:00.5Z")
        #expect(try genesis.toCBORHex() == hex)
        #expect(genesis.systemStartDate == ISO8601DateFormatter().date(from: "2022-10-25T00:00:00Z")!
            .addingTimeInterval(0.5))
    }

    // MARK: Rejections

    func fields() throws -> [Primitive] {
        guard case .list(let f) = try Primitive.fromCBOR(data: data(Self.genesisHex())) else {
            Issue.record("expected a list")
            return []
        }
        return f
    }

    @Test("The decoder takes exactly the ledger's fields and values")
    func rejections() throws {
        var f = try fields()
        #expect(throws: CardanoCoreError.self) { try ShelleyGenesis(from: .list(Array(f.dropLast()))) }

        // activeSlotsCoeff: untagged, in (0, 1].
        for bad: Primitive in [
            .list([.uint(0), .uint(1)]), .list([.uint(3), .uint(2)]), .list([.uint(1), .uint(0)]),
            .list([.int(-1), .uint(20)]),
            .cborTag(CBORTag(tag: 30, value: .list([.uint(1), .uint(20)]))),
            .unitInterval(UnitInterval(numerator: 1, denominator: 20)),
        ] {
            f = try fields()
            f[3] = bad
            #expect(throws: CardanoCoreError.self) { try ShelleyGenesis(from: .list(f)) }
        }

        f = try fields()
        f[2] = .uint(2)
        #expect(throws: CardanoCoreError.self) { try ShelleyGenesis(from: .list(f)) }

        f = try fields()
        f[0] = .string("2017-09-23T21:44:51Z")
        #expect(throws: CardanoCoreError.self) { try ShelleyGenesis(from: .list(f)) }

        // A rational parameter must carry tag 30.
        guard case .list(var params) = f[11] else { return }
        params[10] = .list([.uint(3), .uint(1000)])
        f = try fields()
        f[11] = .list(params)
        #expect(throws: CardanoCoreError.self) { try ShelleyGenesis(from: .list(f)) }
    }

    // MARK: JSON

    func path(_ network: String) throws -> String {
        try #require(try getFilePath(forResource: "shelley-genesis", ofType: "json",
                                     inDirectory: "data/config/\(network)"))
    }

    @Test("Rationals read exactly from every network's genesis",
          arguments: ["mainnet", "preprod", "preview", "sanchonet"])
    func exactFromFiles(_ network: String) throws {
        let genesis = try ShelleyGenesis.load(from: path(network))
        #expect(genesis.activeSlotsCoeff == UnitInterval(numerator: 1, denominator: 20))
        #expect(genesis.protocolParams.rho == UnitInterval(numerator: 3, denominator: 1000))
        #expect(genesis.protocolParams.tau == UnitInterval(numerator: 1, denominator: 5))
        #expect(genesis.protocolParams.a0 == NonNegativeInterval(numerator: 3, denominator: 10))
        #expect(genesis.protocolParams.decentralisationParam == UnitInterval(numerator: 1, denominator: 1))

        // JSON and CBOR round trips keep every value.
        let json = try JSONEncoder().encode(genesis)
        #expect(try JSONDecoder().decode(ShelleyGenesis.self, from: json) == genesis)
        #expect(try ShelleyGenesis.fromCBOR(data: genesis.toCBORData()) == genesis)
    }

    @Test("Rationals are written back as the ledger writes them")
    func jsonWrittenAsLedger() throws {
        let genesis = try ShelleyGenesis.load(from: path("mainnet"))
        let object = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(genesis)) as? [String: Any])
        let params = try #require(object["protocolParams"] as? [String: Any])
        #expect((object["activeSlotsCoeff"] as? NSNumber)?.decimalValue == Decimal(string: "0.05"))
        #expect((params["rho"] as? NSNumber)?.decimalValue == Decimal(string: "0.003"))
        #expect((params["decentralisationParam"] as? NSNumber)?.intValue == 1)
    }

    func mainnetJSON(setting key: String, to value: String, inParams: Bool = false) throws -> Data {
        var text = try String(contentsOfFile: path("mainnet"), encoding: .utf8)
        let pattern = inParams ? "\"\(key)\": 0.3" : "\"\(key)\": 0.05"
        #expect(text.contains(pattern))
        text = text.replacingOccurrences(of: pattern, with: "\"\(key)\": \(value)")
        return Data(text.utf8)
    }

    @Test("Out-of-range and over-precise rationals are refused", arguments: [
        "0", "1.5", "-0.05", "1e-20", "0.00000000000000000001", "{\"numerator\": 1, \"denominator\": 0}",
    ])
    func jsonRejections(_ value: String) throws {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ShelleyGenesis.self, from: mainnetJSON(setting: "activeSlotsCoeff", to: value))
        }
    }

    @Test("Decimals and fractions are both read exactly")
    func jsonForms() throws {
        for (text, n, d) in [("5.0e-2", 1, 20), ("{\"numerator\": 2, \"denominator\": 40}", 1, 20),
                             ("0.0000000000000000001", 1, 10_000_000_000_000_000_000 as UInt64)] as [(String, UInt64, UInt64)] {
            let genesis = try JSONDecoder().decode(
                ShelleyGenesis.self, from: mainnetJSON(setting: "activeSlotsCoeff", to: text))
            #expect(genesis.activeSlotsCoeff == UnitInterval(numerator: n, denominator: d))
        }
        // a0 is a NonNegativeInterval: above one is fine, negative is not.
        let a0 = try JSONDecoder().decode(
            ShelleyGenesis.self, from: mainnetJSON(setting: "a0", to: "2.5", inParams: true))
        #expect(a0.protocolParams.a0 == NonNegativeInterval(numerator: 5, denominator: 2))
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ShelleyGenesis.self, from: mainnetJSON(setting: "a0", to: "-1", inParams: true))
        }
    }

    @Test("A rational that cannot be written throws, not traps")
    func encodeRejections() throws {
        let genesis = try ShelleyGenesis.load(from: path("mainnet"))
        let zero = ShelleyGenesis(
            activeSlotsCoeff: UnitInterval(numerator: 0, denominator: 1), protocolParams: genesis.protocolParams,
            genDelegs: [:], updateQuorum: 1, networkId: "Mainnet", initialFunds: [:], maxLovelaceSupply: 1,
            networkMagic: 1, epochLength: 1, systemStart: genesis.systemStart, slotsPerKESPeriod: 1,
            slotLength: 1, maxKESEvolutions: 1, securityParam: 1)
        #expect(throws: CardanoCoreError.self) { try zero.toPrimitive() }

        let p = genesis.protocolParams
        let bad = ProtocolParams(
            protocolVersion: p.protocolVersion, decentralisationParam: UnitInterval(numerator: 2, denominator: 1),
            eMax: p.eMax, extraEntropy: p.extraEntropy, maxTxSize: p.maxTxSize, maxBlockBodySize: p.maxBlockBodySize,
            maxBlockHeaderSize: p.maxBlockHeaderSize, minFeeA: p.minFeeA, minFeeB: p.minFeeB,
            minUTxOValue: p.minUTxOValue, poolDeposit: p.poolDeposit, minPoolCost: p.minPoolCost,
            keyDeposit: p.keyDeposit, nOpt: p.nOpt, rho: p.rho, tau: p.tau, a0: p.a0)
        #expect(throws: CardanoCoreError.self) { try bad.toPrimitive() }
    }
}
