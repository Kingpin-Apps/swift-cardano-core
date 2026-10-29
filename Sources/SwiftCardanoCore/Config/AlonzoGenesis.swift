import Foundation
import OrderedCollections

// MARK: - AlonzoGenesis
/// The ledger's `AlonzoGenesis`: its `UpgradeAlonzoPParams` and optional
/// extra configuration (cardano-ledger `Cardano.Ledger.Alonzo.Genesis`). Each
/// field has the width of its ledger type, and the execution prices are held
/// exactly.
public struct AlonzoGenesis: JSONLoadable {
    /// `CoinPerWord`, a `Coin`.
    public let lovelacePerUTxOWord: Coin
    /// `Prices`: each a `NonNegativeInterval`.
    public let executionPrices: ExecutionUnitPrices
    public let maxTxExUnits: AlonzoGenesisExUnits
    public let maxBlockExUnits: AlonzoGenesisExUnits
    /// `Word32`.
    public let maxValueSize: UInt32
    /// `Word16`.
    public let collateralPercentage: UInt16
    /// `Word16`.
    public let maxCollateralInputs: UInt16
    /// The PlutusV1 cost model.
    public let costModels: AlonzoCostModels
    /// `StrictMaybe AlonzoExtraConfig`.
    public let extraConfig: AlonzoExtraConfig?

    public init(
        lovelacePerUTxOWord: Coin,
        executionPrices: ExecutionUnitPrices,
        maxTxExUnits: AlonzoGenesisExUnits,
        maxBlockExUnits: AlonzoGenesisExUnits,
        maxValueSize: UInt32,
        collateralPercentage: UInt16,
        maxCollateralInputs: UInt16,
        costModels: AlonzoCostModels,
        extraConfig: AlonzoExtraConfig? = nil
    ) {
        self.lovelacePerUTxOWord = lovelacePerUTxOWord
        self.executionPrices = executionPrices
        self.maxTxExUnits = maxTxExUnits
        self.maxBlockExUnits = maxBlockExUnits
        self.maxValueSize = maxValueSize
        self.collateralPercentage = collateralPercentage
        self.maxCollateralInputs = maxCollateralInputs
        self.costModels = costModels
        self.extraConfig = extraConfig
    }
}

// MARK: - ExUnits
/// `ExUnits`: `Natural` counts. The ledger's JSON reader accepts the full
/// `Word64` range; its CBOR reader nothing above `Int64.max`.
public struct AlonzoGenesisExUnits: Codable, Equatable, Hashable {
    public let exUnitsMem: UInt64
    public let exUnitsSteps: UInt64

    public init(exUnitsMem: UInt64, exUnitsSteps: UInt64) {
        self.exUnitsMem = exUnitsMem
        self.exUnitsSteps = exUnitsSteps
    }

    private enum CodingKeys: String, CodingKey {
        case memory, steps, exUnitsMem, exUnitsSteps
    }

    /// Reads `memory`/`steps`, or the older `exUnitsMem`/`exUnitsSteps`, as
    /// the ledger's `FromJSON ExUnits` does.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exUnitsMem = try c.contains(.memory)
            ? c.decode(UInt64.self, forKey: .memory) : c.decode(UInt64.self, forKey: .exUnitsMem)
        exUnitsSteps = try c.contains(.steps)
            ? c.decode(UInt64.self, forKey: .steps) : c.decode(UInt64.self, forKey: .exUnitsSteps)
    }

    /// Writes `memory` and `steps`, as the ledger's `ToJSON ExUnits` does.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(exUnitsMem, forKey: .memory)
        try c.encode(exUnitsSteps, forKey: .steps)
    }
}

// MARK: - CostModels
/// The genesis PlutusV1 cost model: its parameters in the ledger's order.
public struct AlonzoCostModels: Codable, Equatable, Hashable {
    /// The 166 PlutusV1 parameters, in `ParamName` order.
    public let plutusV1: [Int64]

    public init(plutusV1: [Int64]) {
        self.plutusV1 = plutusV1
    }

    enum CodingKeys: String, CodingKey {
        case plutusV1 = "PlutusV1"
    }

    /// The number of parameters the genesis PlutusV1 cost model has.
    static let plutusV1ParameterCount = PLUTUS_V1_COST_MODEL.count

    /// Reads `{"PlutusV1": …}` as the ledger's `parseCostModels False
    /// [PlutusV1]` does: a list of the parameters, or a map from their names;
    /// exactly 166 either way. Other languages are not read.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        plutusV1 = try decodeCostModel(c, .plutusV1, names: Array(PLUTUS_V1_COST_MODEL.keys), lenient: false)
    }

    /// Writes the parameters as a list, as the ledger's `ToJSON CostModel` does.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(plutusV1, forKey: .plutusV1)
    }
}

/// A cost model read from `key`: a list of parameters, or a map from the
/// parameter `names` (in the ledger's order) to their values. Unless
/// `lenient`, exactly `names.count` parameters.
private func decodeCostModel<K: CodingKey>(
    _ c: KeyedDecodingContainer<K>, _ key: K, names: [String], lenient: Bool
) throws -> [Int64] {
    let values: [Int64]
    if let list = try? c.decode([Int64].self, forKey: key) {
        values = list
    } else {
        let map = try c.decode([String: Int64].self, forKey: key)
        guard !names.isEmpty else {
            throw CardanoCoreError.deserializeError("\(key.stringValue): its parameters have no names to read")
        }
        values = try names.map { name in
            guard let value = map[name] else {
                throw CardanoCoreError.deserializeError(
                    "\(key.stringValue): parameter name missing from cost model: \(name)")
            }
            return value
        }
        if !lenient, map.count != names.count {
            throw CardanoCoreError.deserializeError(
                "\(key.stringValue): number of parameters supplied \(map.count) does not match the expected number of \(names.count)")
        }
    }
    if !lenient, values.count != names.count {
        throw CardanoCoreError.deserializeError(
            "\(key.stringValue): number of parameters supplied \(values.count) does not match the expected number of \(names.count)")
    }
    return values
}

// MARK: - AlonzoExtraConfig
/// The ledger's `AlonzoExtraConfig`: cost models to inject for testing.
public struct AlonzoExtraConfig: Codable, Equatable, Hashable {
    /// Each language's parameters, keyed by its `Word8` (0 is PlutusV1), in
    /// ascending order.
    public let costModels: OrderedDictionary<UInt8, [Int64]>?

    public init(costModels: OrderedDictionary<UInt8, [Int64]>?) {
        self.costModels = costModels.map { models in
            OrderedDictionary(uniqueKeysWithValues: models.sorted { $0.key < $1.key }.map { ($0.key, $0.value) })
        }
    }

    private enum CodingKeys: String, CodingKey { case costModels }

    private struct LanguageKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    /// The language names the ledger writes, by `Word8`.
    private static let languageNames: [UInt8: String] = [0: "PlutusV1", 1: "PlutusV2", 2: "PlutusV3", 3: "PlutusV4"]

    /// The parameter names of the languages that have them, by `Word8`.
    private static let parameterNames: [UInt8: [String]] = [
        0: Array(PLUTUS_V1_COST_MODEL.keys), 1: Array(PLUTUS_V2_COST_MODEL.keys), 2: Array(PLUTUS_V3_COST_MODEL.keys),
    ]

    /// Reads `{"costModels": …}` as the ledger's lenient `parseCostModels`
    /// does: known languages by name, others under `"Unknown"` by number.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard c.contains(.costModels), try !c.decodeNil(forKey: .costModels) else {
            self.init(costModels: nil)
            return
        }
        let models = try c.nestedContainer(keyedBy: LanguageKey.self, forKey: .costModels)
        var result: [UInt8: [Int64]] = [:]
        for (language, name) in Self.languageNames {
            let key = LanguageKey(stringValue: name)
            if models.contains(key) {
                result[language] = try decodeCostModel(
                    models, key, names: Self.parameterNames[language] ?? [], lenient: true)
            }
        }
        let unknown = LanguageKey(stringValue: "Unknown")
        if models.contains(unknown) {
            for (name, values) in try models.decode([String: [Int64]].self, forKey: unknown) {
                guard let language = UInt8(name), result[language] == nil else {
                    throw CardanoCoreError.deserializeError("AlonzoExtraConfig: unknown language \(name)")
                }
                result[language] = values
            }
        }
        self.init(costModels: OrderedDictionary(uniqueKeysWithValues: result.map { ($0.key, $0.value) }))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        guard let costModels else {
            try c.encodeNil(forKey: .costModels)
            return
        }
        var models = c.nestedContainer(keyedBy: LanguageKey.self, forKey: .costModels)
        var unknown: [String: [Int64]] = [:]
        for (language, values) in costModels {
            if let name = Self.languageNames[language] {
                try models.encode(values, forKey: LanguageKey(stringValue: name))
            } else {
                unknown[String(language)] = values
            }
        }
        if !unknown.isEmpty {
            try models.encode(unknown, forKey: LanguageKey(stringValue: "Unknown"))
        }
    }
}

// MARK: - CBOR (the ledger's ToCBOR / DecCBOR)
//
// AlonzoGenesis encodes as a list of 9 fields (cardano-ledger alonzo):
//   [0] coinsPerUTxOWord  [1] PlutusV1 cost model (a plain list of int64)
//   [2] prices [prMem, prSteps]  [3] maxTxExUnits  [4] maxBlockExUnits
//   [5] maxValueSize  [6] collateralPercentage  [7] maxCollateralInputs
//   [8] extraConfig: [] or [[costModels / null]]

extension AlonzoGenesis: CBORSerializable {
    private enum CodingKeys: String, CodingKey {
        case lovelacePerUTxOWord, executionPrices, maxTxExUnits, maxBlockExUnits
        case maxValueSize, collateralPercentage, maxCollateralInputs, costModels, extraConfig
    }

    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                lovelacePerUTxOWord:  try c.decode(Coin.self, forKey: .lovelacePerUTxOWord),
                // Read exactly: `{"numerator", "denominator"}` or a decimal.
                executionPrices:      try c.decode(ExecutionUnitPrices.self, forKey: .executionPrices),
                maxTxExUnits:         try c.decode(AlonzoGenesisExUnits.self, forKey: .maxTxExUnits),
                maxBlockExUnits:      try c.decode(AlonzoGenesisExUnits.self, forKey: .maxBlockExUnits),
                maxValueSize:         try c.decode(UInt32.self, forKey: .maxValueSize),
                collateralPercentage: try c.decode(UInt16.self, forKey: .collateralPercentage),
                maxCollateralInputs:  try c.decode(UInt16.self, forKey: .maxCollateralInputs),
                costModels:           try c.decode(AlonzoCostModels.self, forKey: .costModels),
                extraConfig:          try c.decodeIfPresent(AlonzoExtraConfig.self, forKey: .extraConfig)
            )
        } else {
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
            try self.init(from: primitive)
        }
    }

    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(lovelacePerUTxOWord, forKey: .lovelacePerUTxOWord)
            try c.encode(costModels, forKey: .costModels)
            try c.encode(executionPrices, forKey: .executionPrices)
            try c.encode(maxTxExUnits, forKey: .maxTxExUnits)
            try c.encode(maxBlockExUnits, forKey: .maxBlockExUnits)
            try c.encode(maxValueSize, forKey: .maxValueSize)
            try c.encode(collateralPercentage, forKey: .collateralPercentage)
            try c.encode(maxCollateralInputs, forKey: .maxCollateralInputs)
            try c.encodeIfPresent(extraConfig, forKey: .extraConfig)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }

    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count == 9 else {
            throw CardanoCoreError.deserializeError(
                "AlonzoGenesis: expected a list of 9 elements, got \(primitive)")
        }
        lovelacePerUTxOWord   = try f[0].integer("AlonzoGenesis lovelacePerUTxOWord", as: Coin.self)
        // Alonzo's encoding predates version 9, so the ledger reads the cost
        // model with `decodeCostModelLegacy`: exactly 166 parameters.
        let plutusV1 = try alonzoIntList(f[1], "AlonzoGenesis PlutusV1 cost model")
        guard plutusV1.count == AlonzoCostModels.plutusV1ParameterCount else {
            throw CardanoCoreError.deserializeError(
                "AlonzoGenesis PlutusV1 cost model: expected \(AlonzoCostModels.plutusV1ParameterCount) entries, got \(plutusV1.count)")
        }
        costModels            = AlonzoCostModels(plutusV1: plutusV1)
        executionPrices       = try ExecutionUnitPrices(cbor: f[2], "AlonzoGenesis prices")
        maxTxExUnits          = try AlonzoGenesisExUnits(from: f[3])
        maxBlockExUnits       = try AlonzoGenesisExUnits(from: f[4])
        // Word32, Word16 and Word16 in the ledger's Alonzo parameters.
        maxValueSize          = try f[5].integer("AlonzoGenesis maxValueSize", as: UInt32.self)
        collateralPercentage  = try f[6].integer("AlonzoGenesis collateralPercentage", as: UInt16.self)
        maxCollateralInputs   = try f[7].integer("AlonzoGenesis maxCollateralInputs", as: UInt16.self)
        // StrictMaybe: [] or [x].
        guard case .list(let maybe) = f[8], maybe.count <= 1 else {
            throw CardanoCoreError.deserializeError("AlonzoGenesis extraConfig: expected [] or [config]")
        }
        extraConfig = try maybe.first.map { try AlonzoExtraConfig(from: $0) }
    }

    /// - Throws: When the PlutusV1 cost model does not have the 166
    ///   parameters the ledger reads, or a price is not a non-negative
    ///   interval.
    public func toPrimitive() throws -> Primitive {
        guard costModels.plutusV1.count == AlonzoCostModels.plutusV1ParameterCount else {
            throw CardanoCoreError.valueError(
                "AlonzoGenesis PlutusV1 cost model: expected \(AlonzoCostModels.plutusV1ParameterCount) entries, got \(costModels.plutusV1.count)")
        }
        return .list([
            .integer(lovelacePerUTxOWord),
            .list(costModels.plutusV1.map { .int($0) }),
            try executionPrices.ledgerPrimitive(),
            try maxTxExUnits.toPrimitive(),
            try maxBlockExUnits.toPrimitive(),
            .integer(maxValueSize),
            .integer(collateralPercentage),
            .integer(maxCollateralInputs),
            .list(try extraConfig.map { [try $0.toPrimitive()] } ?? []),
        ])
    }
}

/// A list of `int64`s, definite or indefinite.
private func alonzoIntList(_ p: Primitive, _ what: String) throws -> [Int64] {
    let items: [Primitive]
    switch p {
    case .list(let list): items = list
    case .indefiniteList(let list): items = list.getAll()
    default: throw CardanoCoreError.deserializeError("\(what): expected a list of integers")
    }
    return try items.map { try $0.integer(what, as: Int64.self) }
}

// MARK: - AlonzoGenesisExUnits CBOR
// Encodes as [exUnitsMem, exUnitsSteps].
extension AlonzoGenesisExUnits {
    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count == 2 else {
            throw CardanoCoreError.deserializeError("AlonzoGenesisExUnits: expected list of 2 elements")
        }
        exUnitsMem   = try exUnitsParameter(f[0], "AlonzoGenesisExUnits exUnitsMem")
        exUnitsSteps = try exUnitsParameter(f[1], "AlonzoGenesisExUnits exUnitsSteps")
    }

    /// - Throws: When a count is above `Int64.max`, which the ledger's CBOR
    ///   reader refuses.
    public func toPrimitive() throws -> Primitive {
        for (value, what) in [(exUnitsMem, "exUnitsMem"), (exUnitsSteps, "exUnitsSteps")]
        where value > UInt64(Int64.max) {
            throw CardanoCoreError.valueError("AlonzoGenesisExUnits \(what): \(value) is above Int64.max")
        }
        return .list([.integer(exUnitsMem), .integer(exUnitsSteps)])
    }
}

// MARK: - AlonzoExtraConfig CBOR
// `Rec AlonzoExtraConfig` of one field: [costModels], the cost models a map
// from language `Word8` to its parameters, or null (`encodeNullMaybe`).
extension AlonzoExtraConfig {
    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count == 1 else {
            throw CardanoCoreError.deserializeError("AlonzoExtraConfig: expected [costModels]")
        }
        if case .null = f[0] {
            self.init(costModels: nil)
            return
        }
        let pairs: [(Primitive, Primitive)]
        switch f[0] {
        case .dict(let d): pairs = d.map { ($0.key, $0.value) }
        case .orderedDict(let d), .indefiniteDictionary(let d): pairs = d.map { ($0.key, $0.value) }
        default:
            throw CardanoCoreError.deserializeError("AlonzoExtraConfig: expected a cost model map or null")
        }
        var result: [UInt8: [Int64]] = [:]
        for (key, value) in pairs {
            let language = try key.integer("AlonzoExtraConfig language", as: UInt8.self)
            guard result[language] == nil else {
                throw CardanoCoreError.deserializeError("AlonzoExtraConfig: language \(language) appears twice")
            }
            result[language] = try alonzoIntList(value, "AlonzoExtraConfig cost model")
        }
        self.init(costModels: OrderedDictionary(uniqueKeysWithValues: result.map { ($0.key, $0.value) }))
    }

    public func toPrimitive() throws -> Primitive {
        guard let costModels else { return .list([.null]) }
        var map = OrderedDictionary<Primitive, Primitive>()
        for (language, values) in costModels.sorted(by: { $0.key < $1.key }) {
            map[.uint(UInt64(language))] = .list(values.map { .int($0) })
        }
        return .list([.orderedDict(map)])
    }
}

// MARK: - Sendable
extension AlonzoGenesis: Sendable {}
extension AlonzoGenesisExUnits: Sendable {}
extension AlonzoCostModels: Sendable {}
extension AlonzoExtraConfig: Sendable {}
