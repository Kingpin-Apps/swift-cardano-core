import Testing
import Foundation
@testable import SwiftCardanoCore

/// Byron genesis and node config fields hold the ledger's and the node's
/// types exactly, and refuse values outside them instead of trapping.
@Suite("ByronGenesis and NodeConfig widths")
struct ByronNodeConfigWidthTests {
    static let networks = ["mainnet", "preprod", "preview", "sanchonet"]

    func path(_ network: String, _ file: String) throws -> String {
        try #require(try getFilePath(forResource: file, ofType: "json", inDirectory: "data/config/\(network)"))
    }

    func byronJSON(_ network: String = "mainnet") throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: try path(network, "byron-genesis")))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// A JSON value from its literal text.
    func fragment(_ literal: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(literal.utf8), options: [.fragmentsAllowed])
    }

    func decode(_ json: [String: Any]) throws -> ByronGenesis {
        try JSONDecoder().decode(ByronGenesis.self, from: JSONSerialization.data(withJSONObject: json))
    }

    /// `json` with `value` set at the nested `keys`.
    func setting(_ json: [String: Any], _ keys: [String], _ value: Any) -> [String: Any] {
        var json = json
        guard let first = keys.first else { return json }
        if keys.count == 1 {
            json[first] = value
        } else {
            json[first] = setting(json[first] as? [String: Any] ?? [:], Array(keys.dropFirst()), value)
        }
        return json
    }

    // MARK: Exact values from the real files

    @Test("Mainnet Byron genesis reads exactly", arguments: ["mainnet"])
    func mainnetValues(_ network: String) throws {
        let genesis = try ByronGenesis.load(from: try path(network, "byron-genesis"))
        let bvd = genesis.blockVersionData
        #expect(genesis.protocolConsts.k == 2160)
        #expect(genesis.protocolConsts.protocolMagic == 764_824_073)
        #expect(genesis.protocolConsts.vssMaxTTL == 6)
        #expect(genesis.protocolConsts.vssMinTTL == 2)
        #expect(genesis.startTime == 1_506_203_091)
        #expect(bvd.slotDuration == 20_000)
        #expect(bvd.maxBlockSize == 2_000_000)
        #expect(bvd.maxTxSize == 4096)
        #expect(bvd.scriptVersion == 0)
        #expect(bvd.updateImplicit == 10_000)
        // 2^64 - 1: an EpochNumber at the very top of Word64.
        #expect(bvd.unlockStakeEpoch == UInt64.max)
        #expect(bvd.heavyDelThd.numerator == 300_000_000_000)
        #expect(bvd.heavyDelThd.rational == (3, 10_000))
        #expect(bvd.softforkRule.initThd.rational == (9, 10))
        #expect(bvd.softforkRule.minThd.rational == (3, 5))
        #expect(bvd.softforkRule.thdDecrement.rational == (1, 20))
        // 155381000000000 / 10^9 lovelace, and 43946000000 / 10^9 per byte.
        #expect(bvd.txFeePolicy.summand == 155_381)
        #expect(bvd.txFeePolicy.multiplier == 43_946_000_000)
        #expect(bvd.txFeePolicy.multiplierRational == (21_973, 500))
        #expect(genesis.avvmDistr["-0BJDi-gauylk4LptQTgjMeo7kY9lTCbZv12vwOSTZk="] == 9_999_300_000_000)
        #expect(genesis.bootStakeholders.values.allSatisfy { $0 == 1 })
        #expect(genesis.heavyDelegation.values.allSatisfy { $0.omega == 0 })
        #expect(genesis.vssCerts?.values.allSatisfy { $0.expiryEpoch == 5 } == true)
    }

    @Test("Every Byron genesis loads, round-trips JSON and CBOR", arguments: networks)
    func roundTrips(_ network: String) throws {
        let genesis = try ByronGenesis.load(from: try path(network, "byron-genesis"))
        let json = try JSONEncoder().encode(genesis)
        #expect(try JSONDecoder().decode(ByronGenesis.self, from: json) == genesis)
        #expect(try ByronGenesis(from: genesis.toPrimitive()) == genesis)
        #expect(try ByronGenesis.fromCBOR(data: genesis.toCBORData()) == genesis)
    }

    @Test("JSON is written the way the node writes it")
    func jsonShape() throws {
        let genesis = try ByronGenesis.load(from: try path("mainnet", "byron-genesis"))
        let written = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(genesis)) as? [String: Any])
        let bvd = try #require(written["blockVersionData"] as? [String: Any])
        #expect(bvd["unlockStakeEpoch"] as? String == "18446744073709551615")
        #expect(bvd["heavyDelThd"] as? String == "300000000000")
        #expect(bvd["slotDuration"] as? String == "20000")
        #expect((bvd["scriptVersion"] as? NSNumber)?.intValue == 0)
        let fee = try #require(bvd["txFeePolicy"] as? [String: Any])
        #expect(fee["summand"] as? String == "155381000000000")
        #expect(fee["multiplier"] as? String == "43946000000")
        let consts = try #require(written["protocolConsts"] as? [String: Any])
        #expect((consts["protocolMagic"] as? NSNumber)?.int64Value == 764_824_073)
        let avvm = try #require(written["avvmDistr"] as? [String: Any])
        #expect(avvm["-0BJDi-gauylk4LptQTgjMeo7kY9lTCbZv12vwOSTZk="] as? String == "9999300000000")
    }

    // MARK: Out-of-range Byron values

    @Test("Out-of-range Byron values are refused", arguments: [
        (["protocolConsts", "protocolMagic"], "4294967296"),          // above Word32
        (["protocolConsts", "k"], "-1"),
        (["protocolConsts", "vssMaxTTL"], "4294967296"),
        (["blockVersionData", "scriptVersion"], "65536"),               // above Word16
        (["blockVersionData", "slotDuration"], "\"18446744073709551616\""), // above Word64
        (["blockVersionData", "maxBlockSize"], "\"-1\""),
        (["blockVersionData", "maxTxSize"], "\"4096.5\""),
        (["blockVersionData", "unlockStakeEpoch"], "\"18446744073709551616\""),
        (["blockVersionData", "updateImplicit"], "\"abc\""),
        (["blockVersionData", "heavyDelThd"], "\"1000000000000001\""),     // above 10^15
        (["blockVersionData", "mpcThd"], "\"-5\""),
        (["blockVersionData", "softforkRule", "initThd"], "\"1000000000000001\""),
        (["blockVersionData", "txFeePolicy", "summand"], "\"45000000000000001000000000\""), // > supply
        (["blockVersionData", "txFeePolicy", "summand"], "\"-1\""),
        (["blockVersionData", "txFeePolicy", "multiplier"], "\"18446744073709551616\""),
        (["startTime"], "\"9223372036854775808\""),                        // above Int64
    ])
    func refusesOutOfRange(_ keys: [String], _ literal: String) throws {
        let json = setting(try byronJSON(), keys, try fragment(literal))
        #expect(throws: (any Error).self) { try decode(json) }
    }

    @Test("Out-of-range map values are refused")
    func refusesOutOfRangeMapValues() throws {
        var json = try byronJSON()
        json["bootStakeholders"] = ["aa": 65_536]
        #expect(throws: (any Error).self) { try decode(json) }
        json = try byronJSON()
        json["avvmDistr"] = ["aa": "45000000000000001"]
        #expect(throws: (any Error).self) { try decode(json) }
        json = try byronJSON()
        json["nonAvvmBalances"] = ["aa": "18446744073709551616"]
        #expect(throws: (any Error).self) { try decode(json) }
        json = try byronJSON()
        var heavy = try #require(json["heavyDelegation"] as? [String: [String: Any]])
        let key = try #require(heavy.keys.first)
        heavy[key]?["omega"] = -1
        json["heavyDelegation"] = heavy
        #expect(throws: (any Error).self) { try decode(json) }
    }

    @Test("The values at the top of each range are accepted")
    func acceptsBounds() throws {
        var json = try byronJSON()
        json = setting(json, ["protocolConsts", "protocolMagic"], 4_294_967_295)
        json = setting(json, ["blockVersionData", "scriptVersion"], 65_535)
        json = setting(json, ["blockVersionData", "heavyDelThd"], "1000000000000000")
        json = setting(json, ["blockVersionData", "txFeePolicy", "summand"], "45000000000000000000000000")
        json = setting(json, ["blockVersionData", "slotDuration"], 18_446_744_073_709_551_615 as UInt64)
        let genesis = try decode(json)
        #expect(genesis.protocolConsts.protocolMagic == UInt32.max)
        #expect(genesis.blockVersionData.scriptVersion == UInt16.max)
        #expect(genesis.blockVersionData.heavyDelThd.rational == (1, 1))
        #expect(genesis.blockVersionData.txFeePolicy.summand == ByronGenesis.maxLovelace)
        #expect(genesis.blockVersionData.slotDuration == UInt64.max)
    }

    @Test("The summand is floored to lovelace, as the ledger's div does")
    func summandFloors() throws {
        let json = setting(try byronJSON(), ["blockVersionData", "txFeePolicy", "summand"], "155381999999999")
        #expect(try decode(json).blockVersionData.txFeePolicy.summand == 155_381)
    }

    @Test("Out-of-range CBOR values are refused, not trapped")
    func refusesOutOfRangeCBOR() throws {
        let genesis = try ByronGenesis.load(from: try path("mainnet", "byron-genesis"))
        guard case .dict(var map) = try genesis.toPrimitive() else {
            Issue.record("expected a map"); return
        }
        map[.string("startTime")] = .uint(UInt64.max)
        #expect(throws: (any Error).self) { try ByronGenesis(from: .dict(map)) }
        map[.string("startTime")] = .int(0)
        map[.string("bootStakeholders")] = .dict([.string("aa"): .uint(UInt64.max)])
        #expect(throws: (any Error).self) { try ByronGenesis(from: .dict(map)) }
        map[.string("bootStakeholders")] = .dict([:])
        map[.string("vssCerts")] = .dict([.string("aa"): .string("not a certificate")])
        #expect(throws: (any Error).self) { try ByronGenesis(from: .dict(map)) }
    }

    @Test("LovelacePortion and TxFeePolicy refuse out-of-range values")
    func checkedInits() throws {
        #expect(throws: (any Error).self) { try LovelacePortion(numerator: LovelacePortion.denominator + 1) }
        #expect(try LovelacePortion(numerator: 0).rational == (0, 1))
        #expect(throws: (any Error).self) { try TxFeePolicy(summand: ByronGenesis.maxLovelace + 1, multiplier: 0) }
        #expect(try TxFeePolicy(summand: 0, multiplier: 0).multiplierRational == (0, 1))
    }

    // MARK: NodeConfig

    @Test("Every node config loads", arguments: networks.flatMap { [($0, "config"), ($0, "config-bp")] })
    func nodeConfigLoads(_ network: String, _ file: String) throws {
        let config = try NodeConfig.load(from: try path(network, file))
        let data = try Data(contentsOf: URL(fileURLWithPath: try path(network, file)))
        let raw = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(config.lastKnownBlockVersionMajor.map(Int.init) == (raw["LastKnownBlockVersion-Major"] as? Int))
        #expect(config.lastKnownBlockVersionMinor.map(Int.init) == (raw["LastKnownBlockVersion-Minor"] as? Int))
        #expect(config.lastKnownBlockVersionAlt.map(Int.init) == (raw["LastKnownBlockVersion-Alt"] as? Int))
        #expect(config.rotation?.rpLogLimitBytes == 5_000_000)
        if network == "preview" || network == "sanchonet" {
            #expect(config.testShelleyHardForkAtEpoch == 0)
            #expect(config.testAlonzoHardForkAtEpoch == 0)
            #expect(config.experimentalHardForksEnabled != nil)
        }
    }

    func nodeConfigJSON() throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: try path("mainnet", "config")))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("Out-of-range node config values are refused", arguments: [
        ("LastKnownBlockVersion-Major", "65536"),            // above Word16
        ("LastKnownBlockVersion-Minor", "-1"),
        ("LastKnownBlockVersion-Alt", "256"),                 // above Word8
        ("TestConwayHardForkAtEpoch", "-1"),                  // EpochNo is a Word64
        ("TestConwayHardForkAtVersion", "18446744073709551616.0"),
        ("MaxKnownMajorProtocolVersion", "-1"),
    ])
    func nodeConfigRefusesOutOfRange(_ key: String, _ literal: String) throws {
        var json = try nodeConfigJSON()
        json[key] = try fragment(literal)
        let data = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(NodeConfig.self, from: data) }
    }

    @Test("Node config reads the top of each range")
    func nodeConfigBounds() throws {
        var json = try nodeConfigJSON()
        json["LastKnownBlockVersion-Major"] = 65_535
        json["LastKnownBlockVersion-Alt"] = 255
        json["TestDijkstraHardForkAtEpoch"] = UInt64.max
        json["rotation"] = ["rpKeepFilesNum": 1, "rpLogLimitBytes": UInt64.max, "rpMaxAgeHours": 1]
        let config = try JSONDecoder().decode(NodeConfig.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(config.lastKnownBlockVersionMajor == UInt16.max)
        #expect(config.lastKnownBlockVersionAlt == UInt8.max)
        #expect(config.testDijkstraHardForkAtEpoch == UInt64.max)
        #expect(config.rotation?.rpLogLimitBytes == UInt64.max)
    }
}
