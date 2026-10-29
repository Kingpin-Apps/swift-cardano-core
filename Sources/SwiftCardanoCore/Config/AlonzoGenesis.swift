import Foundation

// MARK: - AlonzoGenesis
/// The ledger's `AlonzoGenesis` (`UpgradeAlonzoPParams`, cardano-ledger
/// `Cardano.Ledger.Alonzo.Genesis`). Each integer field has the width of its
/// ledger type.
public struct AlonzoGenesis: JSONLoadable {
    /// `CoinPerWord`, a `Coin`.
    public let lovelacePerUTxOWord: Coin
    public let executionPrices: ExecutionPrices
    public let maxTxExUnits: AlonzoGenesisExUnits
    public let maxBlockExUnits: AlonzoGenesisExUnits
    /// `Word32`.
    public let maxValueSize: UInt32
    /// `Word16`.
    public let collateralPercentage: UInt16
    /// `Word16`.
    public let maxCollateralInputs: UInt16
    public let costModels: AlonzoCostModels

    public init(
        lovelacePerUTxOWord: Coin,
        executionPrices: ExecutionPrices,
        maxTxExUnits: AlonzoGenesisExUnits,
        maxBlockExUnits: AlonzoGenesisExUnits,
        maxValueSize: UInt32,
        collateralPercentage: UInt16,
        maxCollateralInputs: UInt16,
        costModels: AlonzoCostModels
    ) {
        self.lovelacePerUTxOWord = lovelacePerUTxOWord
        self.executionPrices = executionPrices
        self.maxTxExUnits = maxTxExUnits
        self.maxBlockExUnits = maxBlockExUnits
        self.maxValueSize = maxValueSize
        self.collateralPercentage = collateralPercentage
        self.maxCollateralInputs = maxCollateralInputs
        self.costModels = costModels
    }
}

// MARK: - ExecutionPrices
public struct ExecutionPrices: Codable, Equatable, Hashable {
    public let prSteps: PriceRatio
    public let prMem: PriceRatio
}

// MARK: - PriceRatio
/// A `NonNegativeInterval`: a `Word64` numerator over a `Word64` denominator
/// above zero.
public struct PriceRatio: Codable, Equatable, Hashable {
    public let numerator: UInt64
    public let denominator: UInt64

    public init(numerator: UInt64, denominator: UInt64) throws {
        guard denominator > 0 else {
            throw CardanoCoreError.valueError("PriceRatio: denominator is zero")
        }
        self.numerator = numerator
        self.denominator = denominator
    }

    private enum CodingKeys: String, CodingKey {
        case numerator, denominator
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let denominator = try c.decode(UInt64.self, forKey: .denominator)
        guard denominator > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .denominator, in: c, debugDescription: "PriceRatio: denominator is zero")
        }
        self.numerator = try c.decode(UInt64.self, forKey: .numerator)
        self.denominator = denominator
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
}

// MARK: - CostModels
public struct AlonzoCostModels: Codable, Equatable, Hashable {
    public let plutusV1: [String: Int]

    enum CodingKeys: String, CodingKey {
        case plutusV1 = "PlutusV1"
    }
}

// MARK: - CBOR (Haskell ToCBOR field order)
//
// AlonzoGenesis encodes as a list of 8 fields (cardano-ledger):
//   [0] lovelacePerUTxOWord  [1] costModels  [2] executionPrices
//   [3] maxTxExUnits  [4] maxBlockExUnits  [5] maxValueSize
//   [6] collateralPercentage  [7] maxCollateralInputs
//
// NOTE: costModels is field 1 in CBOR but stored last in the JSON/Swift struct.
// NOTE: Verify field order against live node output; adjust if decoding fails.

extension AlonzoGenesis: CBORSerializable {
    private enum CodingKeys: String, CodingKey {
        case lovelacePerUTxOWord, executionPrices, maxTxExUnits, maxBlockExUnits
        case maxValueSize, collateralPercentage, maxCollateralInputs, costModels
    }

    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                lovelacePerUTxOWord:  try c.decode(Coin.self, forKey: .lovelacePerUTxOWord),
                executionPrices:      try c.decode(ExecutionPrices.self, forKey: .executionPrices),
                maxTxExUnits:         try c.decode(AlonzoGenesisExUnits.self, forKey: .maxTxExUnits),
                maxBlockExUnits:      try c.decode(AlonzoGenesisExUnits.self, forKey: .maxBlockExUnits),
                maxValueSize:         try c.decode(UInt32.self, forKey: .maxValueSize),
                collateralPercentage: try c.decode(UInt16.self, forKey: .collateralPercentage),
                maxCollateralInputs:  try c.decode(UInt16.self, forKey: .maxCollateralInputs),
                costModels:           try c.decode(AlonzoCostModels.self, forKey: .costModels)
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
            try c.encode(executionPrices, forKey: .executionPrices)
            try c.encode(maxTxExUnits, forKey: .maxTxExUnits)
            try c.encode(maxBlockExUnits, forKey: .maxBlockExUnits)
            try c.encode(maxValueSize, forKey: .maxValueSize)
            try c.encode(collateralPercentage, forKey: .collateralPercentage)
            try c.encode(maxCollateralInputs, forKey: .maxCollateralInputs)
            try c.encode(costModels, forKey: .costModels)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }

    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count >= 8 else {
            throw CardanoCoreError.deserializeError(
                "AlonzoGenesis: expected list of 8+ elements, got \(primitive)")
        }
        lovelacePerUTxOWord   = try f[0].integer("AlonzoGenesis lovelacePerUTxOWord", as: Coin.self)
        costModels            = try AlonzoCostModels(from: f[1])
        executionPrices       = try ExecutionPrices(from: f[2])
        maxTxExUnits          = try AlonzoGenesisExUnits(from: f[3])
        maxBlockExUnits       = try AlonzoGenesisExUnits(from: f[4])
        // Word32, Word16 and Word16 in the ledger's Alonzo parameters.
        maxValueSize          = try f[5].integer("AlonzoGenesis maxValueSize", as: UInt32.self)
        collateralPercentage  = try f[6].integer("AlonzoGenesis collateralPercentage", as: UInt16.self)
        maxCollateralInputs   = try f[7].integer("AlonzoGenesis maxCollateralInputs", as: UInt16.self)
    }

    public func toPrimitive() throws -> Primitive {
        .list([
            .integer(lovelacePerUTxOWord),
            try costModels.toPrimitive(),
            try executionPrices.toPrimitive(),
            try maxTxExUnits.toPrimitive(),
            try maxBlockExUnits.toPrimitive(),
            .integer(maxValueSize),
            .integer(collateralPercentage),
            .integer(maxCollateralInputs)
        ])
    }
}

// MARK: - ExecutionPrices CBOR
// Encodes as [prSteps, prMem] where each is a tag-30 rational [numerator, denominator].
extension ExecutionPrices {
    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count >= 2 else {
            throw CardanoCoreError.deserializeError("ExecutionPrices: expected list of 2 elements")
        }
        prSteps = try PriceRatio(from: f[0])
        prMem   = try PriceRatio(from: f[1])
    }

    public func toPrimitive() throws -> Primitive {
        .list([try prSteps.toPrimitive(), try prMem.toPrimitive()])
    }
}

// MARK: - PriceRatio CBOR
// Encodes as tag-30 [numerator, denominator].
extension PriceRatio {
    public init(from primitive: Primitive) throws {
        switch primitive {
        case .cborTag(let t) where t.tag == 30:
            guard case .list(let arr) = t.value, arr.count == 2 else {
                throw CardanoCoreError.deserializeError("PriceRatio: malformed tag-30")
            }
            numerator   = try arr[0].integer("PriceRatio numerator", as: UInt64.self)
            denominator = try arr[1].integer("PriceRatio denominator", as: UInt64.self)
        case .list(let arr) where arr.count == 2:
            numerator   = try arr[0].integer("PriceRatio numerator", as: UInt64.self)
            denominator = try arr[1].integer("PriceRatio denominator", as: UInt64.self)
        default:
            throw CardanoCoreError.deserializeError("PriceRatio: expected tag-30 or [num, den], got \(primitive)")
        }
        // A NonNegativeInterval: its denominator is positive.
        guard denominator > 0 else {
            throw CardanoCoreError.deserializeError("PriceRatio: denominator is zero")
        }
    }

    public func toPrimitive() throws -> Primitive {
        let tag = CBORTag(tag: 30, value: .list([.integer(numerator), .integer(denominator)]))
        return .cborTag(tag)
    }
}

// MARK: - AlonzoGenesisExUnits CBOR
// Encodes as [exUnitsMem, exUnitsSteps].
extension AlonzoGenesisExUnits {
    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count >= 2 else {
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

// MARK: - AlonzoCostModels CBOR
// Encodes as map { language_id → [int cost_model_values] }.
// Language 0 = PlutusV1.
extension AlonzoCostModels {
    public init(from primitive: Primitive) throws {
        let pairs: [(Primitive, Primitive)]
        switch primitive {
        case .dict(let d): pairs = Array(d)
        case .orderedDict(let d): pairs = d.map { ($0.key, $0.value) }
        case .list(let items):
            // Some encodings wrap as [[language_id, [costs]]]
            var p: [(Primitive, Primitive)] = []
            for item in items {
                if case .list(let kv) = item, kv.count >= 2 { p.append((kv[0], kv[1])) }
            }
            pairs = p
        default:
            throw CardanoCoreError.deserializeError("AlonzoCostModels: expected map")
        }

        var v1: [String: Int] = [:]
        for (k, v) in pairs {
            // Language 0 = PlutusV1
            guard k.integerValue == 0, case .list(let costs) = v else { continue }
            for (i, cost) in costs.enumerated() {
                switch cost {
                case .int, .uint, .bigInt, .bigUInt:
                    // Cost model parameters are `int64` in the CDDL.
                    v1["\(i)"] = Int(try cost.integer("AlonzoCostModels PlutusV1", as: Int64.self))
                default: break
                }
            }
        }
        plutusV1 = v1
    }

    public func toPrimitive() throws -> Primitive {
        let costs: [Primitive] = plutusV1.keys.sorted().compactMap { k in
            plutusV1[k].map { .int(Int64($0)) }
        }
        let pairs: [(Primitive, Primitive)] = [(.uint(0), .list(costs))]
        return .dict(Dictionary(uniqueKeysWithValues: pairs))
    }
}

// MARK: - Sendable
extension AlonzoGenesis: Sendable {}
extension ExecutionPrices: Sendable {}
extension PriceRatio: Sendable {}
extension AlonzoGenesisExUnits: Sendable {}
extension AlonzoCostModels: Sendable {}
