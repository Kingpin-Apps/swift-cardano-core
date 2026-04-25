import Foundation

// MARK: - AlonzoGenesis
public struct AlonzoGenesis: JSONLoadable {
    public let lovelacePerUTxOWord: Int
    public let executionPrices: ExecutionPrices
    public let maxTxExUnits: AlonzoGenesisExUnits
    public let maxBlockExUnits: AlonzoGenesisExUnits
    public let maxValueSize: Int
    public let collateralPercentage: Int
    public let maxCollateralInputs: Int
    public let costModels: AlonzoCostModels

    public init(
        lovelacePerUTxOWord: Int,
        executionPrices: ExecutionPrices,
        maxTxExUnits: AlonzoGenesisExUnits,
        maxBlockExUnits: AlonzoGenesisExUnits,
        maxValueSize: Int,
        collateralPercentage: Int,
        maxCollateralInputs: Int,
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
public struct PriceRatio: Codable, Equatable, Hashable {
    public let numerator: Int
    public let denominator: Int
}

// MARK: - ExUnits
public struct AlonzoGenesisExUnits: Codable, Equatable, Hashable {
    public let exUnitsMem: Int
    public let exUnitsSteps: Int
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
                lovelacePerUTxOWord:  try c.decode(Int.self, forKey: .lovelacePerUTxOWord),
                executionPrices:      try c.decode(ExecutionPrices.self, forKey: .executionPrices),
                maxTxExUnits:         try c.decode(AlonzoGenesisExUnits.self, forKey: .maxTxExUnits),
                maxBlockExUnits:      try c.decode(AlonzoGenesisExUnits.self, forKey: .maxBlockExUnits),
                maxValueSize:         try c.decode(Int.self, forKey: .maxValueSize),
                collateralPercentage: try c.decode(Int.self, forKey: .collateralPercentage),
                maxCollateralInputs:  try c.decode(Int.self, forKey: .maxCollateralInputs),
                costModels:           try c.decode(AlonzoCostModels.self, forKey: .costModels)
            )
        } else {
            let container = try decoder.singleValueContainer()
            let primitive = try container.decode(Primitive.self)
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
        lovelacePerUTxOWord   = Int(try Self.readUInt(f[0], label: "lovelacePerUTxOWord"))
        costModels            = try AlonzoCostModels(from: f[1])
        executionPrices       = try ExecutionPrices(from: f[2])
        maxTxExUnits          = try AlonzoGenesisExUnits(from: f[3])
        maxBlockExUnits       = try AlonzoGenesisExUnits(from: f[4])
        maxValueSize          = Int(try Self.readUInt(f[5], label: "maxValueSize"))
        collateralPercentage  = Int(try Self.readUInt(f[6], label: "collateralPercentage"))
        maxCollateralInputs   = Int(try Self.readUInt(f[7], label: "maxCollateralInputs"))
    }

    public func toPrimitive() throws -> Primitive {
        .list([
            .int(lovelacePerUTxOWord),
            try costModels.toPrimitive(),
            try executionPrices.toPrimitive(),
            try maxTxExUnits.toPrimitive(),
            try maxBlockExUnits.toPrimitive(),
            .int(maxValueSize),
            .int(collateralPercentage),
            .int(maxCollateralInputs)
        ])
    }

    private static func readUInt(_ p: Primitive, label: String) throws -> UInt64 {
        switch p {
        case .uint(let u): return UInt64(u)
        case .int(let i) where i >= 0: return UInt64(i)
        default:
            throw CardanoCoreError.deserializeError("AlonzoGenesis: expected uint for \(label)")
        }
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
            numerator   = try Self.readInt(arr[0], label: "numerator")
            denominator = try Self.readInt(arr[1], label: "denominator")
        case .list(let arr) where arr.count == 2:
            numerator   = try Self.readInt(arr[0], label: "numerator")
            denominator = try Self.readInt(arr[1], label: "denominator")
        default:
            throw CardanoCoreError.deserializeError("PriceRatio: expected tag-30 or [num, den], got \(primitive)")
        }
    }

    public func toPrimitive() throws -> Primitive {
        let tag = CBORTag(tag: 30, value: .list([.int(numerator), .int(denominator)]))
        return .cborTag(tag)
    }

    private static func readInt(_ p: Primitive, label: String) throws -> Int {
        switch p {
        case .int(let i): return i
        case .uint(let u): return Int(u)
        default:
            throw CardanoCoreError.deserializeError("PriceRatio: expected int for \(label)")
        }
    }
}

// MARK: - AlonzoGenesisExUnits CBOR
// Encodes as [exUnitsMem, exUnitsSteps].
extension AlonzoGenesisExUnits {
    public init(from primitive: Primitive) throws {
        guard case .list(let f) = primitive, f.count >= 2 else {
            throw CardanoCoreError.deserializeError("AlonzoGenesisExUnits: expected list of 2 elements")
        }
        exUnitsMem   = try Self.readInt(f[0], label: "exUnitsMem")
        exUnitsSteps = try Self.readInt(f[1], label: "exUnitsSteps")
    }

    public func toPrimitive() throws -> Primitive {
        .list([.int(exUnitsMem), .int(exUnitsSteps)])
    }

    private static func readInt(_ p: Primitive, label: String) throws -> Int {
        switch p {
        case .int(let i): return i
        case .uint(let u): return Int(u)
        default:
            throw CardanoCoreError.deserializeError("AlonzoGenesisExUnits: expected int for \(label)")
        }
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
            let langId: Int
            switch k {
            case .uint(let u): langId = Int(u)
            case .int(let i): langId = i
            default: continue
            }
            guard langId == 0, case .list(let costs) = v else { continue }
            for (i, cost) in costs.enumerated() {
                switch cost {
                case .int(let c): v1["\(i)"] = c
                case .uint(let u): v1["\(i)"] = Int(u)
                default: break
                }
            }
        }
        plutusV1 = v1
    }

    public func toPrimitive() throws -> Primitive {
        let costs: [Primitive] = plutusV1.keys.sorted().compactMap { k in
            plutusV1[k].map { .int($0) }
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
