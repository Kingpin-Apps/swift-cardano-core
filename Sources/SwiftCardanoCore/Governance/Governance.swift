import Foundation

public enum GovernanceKeyType: Int, Sendable {
    case ccHot = 0b0000
    case ccCold = 0b0001
    case drep = 0b0010
}

public enum GovernanceCredentialType: Int, Sendable {
    case keyHash = 0b0010
    case scriptHash = 0b0011
}

public enum GovActionCode: Int, Codable {
    case parameterChangeAction = 0
    case hardForkInitiationAction = 1
    case treasuryWithdrawalsAction = 2
    case noConfidence = 3
    case updateCommittee = 4
    case newConstitution = 5
    case infoAction = 6
}

public protocol GovernanceAction: CBORSerializable, Sendable {
    static var code: GovActionCode { get }
}

public enum GovAction: CBORSerializable, Sendable {
    case parameterChangeAction(ParameterChangeAction)
    case hardForkInitiationAction(HardForkInitiationAction)
    case treasuryWithdrawalsAction(TreasuryWithdrawalsAction)
    case noConfidence(NoConfidence)
    case updateCommittee(UpdateCommittee)
    case newConstitution(NewConstitution)
    case infoAction(InfoAction)

    public init(from decoder: Decoder) throws {
        if String(describing: type(of: decoder)).contains("JSONDecoder") {
            let container = try decoder.singleValueContainer()
            let cborHex = try container.decode(String.self)
            guard let data = Data(hexString: cborHex) else {
                throw CardanoCoreError.valueError("Invalid GovAction CBOR hex: '\(cborHex)'")
            }
            self = try GovAction.fromCBOR(data: data)
        } else {
            let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
            try self.init(from: primitive)
        }
    }

    public func encode(to encoder: Encoder) throws {
        if String(describing: type(of: encoder)).contains("JSONEncoder") {
            var container = encoder.singleValueContainer()
            try container.encode(try toCBORHex())
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(try toPrimitive())
        }
    }

    public init(from primitive: Primitive) throws {
        guard case let .list(primitiveList) = primitive,
              !primitiveList.isEmpty,
              case let .uint(code) = primitiveList[0],
              let intCode = Int(exactly: code),
              let govActionCode = GovActionCode(rawValue: intCode) else {
            throw CardanoCoreError.deserializeError("Invalid GovAction type: \(primitive)")
        }
        
        switch govActionCode {
            case .parameterChangeAction:
                let action = try ParameterChangeAction(from: primitive)
                self = .parameterChangeAction(action)
            case .hardForkInitiationAction:
                let action = try HardForkInitiationAction(from: primitive)
                self = .hardForkInitiationAction(action)
            case .treasuryWithdrawalsAction:
                let action = try TreasuryWithdrawalsAction(from: primitive)
                self = .treasuryWithdrawalsAction(action)
            case .noConfidence:
                let action = try NoConfidence(from: primitive)
                self = .noConfidence(action)
            case .updateCommittee:
                let action = try UpdateCommittee(from: primitive)
                self = .updateCommittee(action)
            case .newConstitution:
                let action = try NewConstitution(from: primitive)
                self = .newConstitution(action)
            case .infoAction:
                let action = try InfoAction(from: primitive)
                self = .infoAction(action)
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        switch self {
            case .parameterChangeAction(let action):
                return try action.toPrimitive()
            case .hardForkInitiationAction(let action):
                return try action.toPrimitive()
            case .treasuryWithdrawalsAction(let action):
                return try action.toPrimitive()
            case .noConfidence(let action):
                return try action.toPrimitive()
            case .updateCommittee(let action):
                return try action.toPrimitive()
            case .newConstitution(let action):
                return try action.toPrimitive()
            case .infoAction(let action):
                return try action.toPrimitive()
        }
    }
    
}

public struct GovActionID: Serializable, Sendable {
    public let transactionID: TransactionId
    public let govActionIndex: UInt16
    
    public init(transactionID: TransactionId, govActionIndex: UInt16) {
        self.transactionID = transactionID
        self.govActionIndex = govActionIndex
    }
    
    public init(from bech32: String) throws {
        let _bech32 = Bech32()
        let (hrp, checksum, _) = try _bech32.bech32Decode(bech32)
        let data = _bech32.convertBits(data: checksum, fromBits: 5, toBits: 8, pad: false)
        
        guard let data, hrp == "gov_action" else {
            throw CardanoCoreError.valueError("Invalid GovActionID format: \(bech32).")
        }
        
        try self.init(from: data)
    }
    
    public init(from hex: Data) throws {
        let hexData = Bech32().encode(hrp: "gov_action", witprog: hex)
        
        if hexData == nil, hex.count >= 32 {
            throw CardanoCoreError.valueError("Invalid GovActionID format: \(hex).")
        }
        
        let utxoData = hex.prefix(32)
        let idxData = hex.dropFirst(32)
        
        let utxoHex = utxoData.toHex
        
        // Index may be empty (treated as 0), otherwise parse big-endian hex to integer
        var idx: UInt64 = 0
        if !idxData.isEmpty {
            let idxHex = idxData.toHex
            // Remove leading zeros to avoid overflow on very long inputs
            let trimmed = idxHex.trimmingCharacters(in: CharacterSet(charactersIn: "0")).isEmpty ? "0" : String(idxHex.drop { $0 == "0" })
            guard let parsed = UInt64(trimmed, radix: 16) else {
                throw CardanoCoreError.valueError("Invalid GovActionID index format: \(idxHex).")
            }
            idx = parsed
        }
        
        // gov_action_index = uint .size 2
        guard let govActionIndex = UInt16(exactly: idx) else {
            throw CardanoCoreError.valueError("GovActionID index \(idx) is out of range for UInt16.")
        }
        
        let transactionID = try TransactionId(from: .string(utxoHex))
        
        self.init(
            transactionID: transactionID,
            govActionIndex: govActionIndex
        )
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        transactionID = try container.decode(TransactionId.self)
        govActionIndex = try container.decode(UInt16.self)
        // gov_action_id = [transaction_id, gov_action_index]: nothing more.
        guard container.isAtEnd else {
            throw CardanoCoreError.deserializeError("GovActionID must have exactly 2 elements")
        }
    }
    
    public init(from primitive: Primitive) throws {
        if let primitiveList = primitive.arrayElements,
           primitiveList.count == 2 {
            
            let transactionID = try TransactionId(from: primitiveList[0])
            
            // gov_action_index = uint .size 2
            let govActionIndex = try primitiveList[1].integer("GovActionID index", as: UInt16.self)
            
            self.init(transactionID: transactionID, govActionIndex: govActionIndex)
            
        } else if case let .string(primitiveString) = primitive {
            try self.init(from: primitiveString)
        } else {
            throw CardanoCoreError.deserializeError("Invalid GovActionID type: \(primitive)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(transactionID)
        try container.encode(govActionIndex)
    }
    
    public func id(_ format: CredentialFormat = .bech32) throws -> String {
        switch format {
            case .bech32:
                return try self.toBech32()
            case .hex:
                return try self.toBytes().toHex
        }
    }
    
    /// Decode a bech32 string into an GovActionID object.
    /// - Parameter data: Bech32-encoded string.
    /// - Returns: Decoded GovActionID.
    public static func fromBech32(_ govActionID: String) throws -> GovActionID {
        return try GovActionID(from: .string(govActionID))
    }
    
    public func toPrimitive() throws -> Primitive {
        // The CDDL is `gov_action_id = [transaction_id : $hash32, index : ...]`,
        // i.e. the transaction id is a 32-byte bytestring, NOT a hex text string.
        // Emitting `.string(...)` here made the ledger reject votes/proposals with
        // `DeserialiseFailure "expected bytes"`.
        return .list([
            .bytes(transactionID.payload),
            .uint(UInt64(govActionIndex))
        ])
    }
    
    public func toBytes() throws -> Data {
        var idxHex = String(self.govActionIndex, radix: 16, uppercase: false)
        if idxHex.count % 2 != 0 {
            idxHex = "0" + idxHex
        }
        
        guard let idxHexData = Data(hexString: idxHex) else {
            throw CardanoCoreError.encodingError("Error encoding data: \(idxHex)")
        }
        
        return self.transactionID.payload + idxHexData
    }
    
    /// Encode the GovActionID in Bech32 format.
    ///
    /// More info about Bech32 (here)[https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki#Bech32].
    
    /// - Returns: Encoded GovActionID in Bech32.
    /// - Note: Converts a Governance Action ID (e.g., "<64-hex>#<idx>") into CIP-129 bech32 string with HRP "gov_action".
    public func toBech32() throws -> String {
        let data = try self.toBytes()
        
        guard let encoded =  Bech32().encode(hrp: "gov_action", witprog: data) else {
            throw CardanoCoreError.encodingError("Error encoding data: \(data)")
        }
        return encoded
    }
}

/// The thresholds stake pools vote with, in the CDDL's order:
///
/// ```
/// pool_voting_thresholds =
///   [ motion no confidence, committee normal, committee no confidence
///   , hard fork initiation, security relevant parameter voting threshold ]
/// ```
public struct PoolVotingThresholds: CBORSerializable, Sendable {
    public var motionNoConfidence: UnitInterval
    public var committeeNormal: UnitInterval
    public var committeeNoConfidence: UnitInterval
    public var hardForkInitiation: UnitInterval
    public var ppSecurityGroup: UnitInterval

    /// The thresholds in the CDDL's order.
    public var thresholds: [UnitInterval] {
        [motionNoConfidence, committeeNormal, committeeNoConfidence, hardForkInitiation, ppSecurityGroup]
    }

    public init(
        motionNoConfidence: UnitInterval,
        committeeNormal: UnitInterval,
        committeeNoConfidence: UnitInterval,
        hardForkInitiation: UnitInterval,
        ppSecurityGroup: UnitInterval
    ) {
        self.motionNoConfidence = motionNoConfidence
        self.committeeNormal = committeeNormal
        self.committeeNoConfidence = committeeNoConfidence
        self.hardForkInitiation = hardForkInitiation
        self.ppSecurityGroup = ppSecurityGroup
    }

    /// The thresholds from a list in the CDDL's order.
    ///
    /// - Throws: Unless there are exactly 5.
    public init(from thresholds: [UnitInterval]) throws {
        guard thresholds.count == 5 else {
            throw CardanoCoreError.deserializeError(
                "PoolVotingThresholds must contain exactly 5 unit intervals, got \(thresholds.count)")
        }
        self.init(
            motionNoConfidence: thresholds[0],
            committeeNormal: thresholds[1],
            committeeNoConfidence: thresholds[2],
            hardForkInitiation: thresholds[3],
            ppSecurityGroup: thresholds[4])
    }

    public init(from decoder: Decoder) throws {
        let primitive = try Primitive.decode(from: decoder, preservingEncoding: false)
        try self.init(from: primitive)
    }

    public init(from primitive: Primitive) throws {
        let elements: [Primitive]
        switch primitive {
        case .list(let list): elements = list
        case .indefiniteList(let list): elements = list.getAll()
        default: throw CardanoCoreError.deserializeError("Invalid PoolVotingThresholds type")
        }
        try self.init(from: try elements.map { try UnitInterval(from: $0) })
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(try toPrimitive())
    }

    public func toPrimitive() throws -> Primitive {
        .list(try thresholds.map { try $0.toPrimitive() })
    }
}

public struct DrepVotingThresholds: CBORSerializable, Sendable  {
    public var thresholds: [UnitInterval]
    
    /// Thresholds known to be the ten in the CDDL's order.
    init(ledgerOrder thresholds: [UnitInterval]) {
        self.thresholds = thresholds
    }

    /// - Throws: Unless there are exactly 10, in the CDDL's order.
    public init(thresholds: [UnitInterval]) throws {
        guard thresholds.count == 10 else {
            throw CardanoCoreError.deserializeError(
                "DrepVotingThresholds must contain exactly 10 unit intervals, got \(thresholds.count)")
        }
        self.thresholds = thresholds
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let thresholds = try container.decode([UnitInterval].self)
        // drep_voting_thresholds = [10 * unit_interval]
        guard thresholds.count == 10 else {
            throw CardanoCoreError.deserializeError("DrepVotingThresholds must contain exactly 10 unit intervals, got \(thresholds.count)")
        }
        self.thresholds = thresholds
    }
    
    public init(from primitive: Primitive) throws {
        let elements: [Primitive]
        switch primitive {
        case .list(let list): elements = list
        case .indefiniteList(let list): elements = list.getAll()
        default: throw CardanoCoreError.deserializeError("Invalid DrepVotingThresholds type")
        }
        try self.init(thresholds: try elements.map { try UnitInterval(from: $0) })
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try thresholds.forEach { try container.encode($0) }
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list(try thresholds.map { try $0.toPrimitive() })
    }
}

public struct Constitution: CBORSerializable, Sendable {
    public let anchor: Anchor
    public let scriptHash: ScriptHash?
    
    public init(anchor: Anchor, scriptHash: ScriptHash?) {
        self.anchor = anchor
        self.scriptHash = scriptHash
    }
    
    // Codable goes through `init(from: Primitive)` and `toPrimitive()`, the
    // default for a `CBORSerializable`: a guardrails-less constitution's null
    // script hash, and the anchor's checks, are handled there.

    public init(from primitive: Primitive) throws {
        let elements: [Primitive]
        switch primitive {
        case .list(let list): elements = list
        case .indefiniteList(let list): elements = list.getAll()
        default: throw CardanoCoreError.deserializeError("Invalid Constitution type")
        }
        guard elements.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid Constitution type")
        }
        self.anchor = try Anchor(from: elements[0])
        // A constitution with no guardrails script encodes its script hash as
        // `.null` (see `toPrimitive`); map that back to nil rather than feeding
        // `.null` to `ScriptHash(from:)`, which throws "Invalid ScriptHash type: null".
        if case .null = elements[1] {
            self.scriptHash = nil
        } else {
            self.scriptHash = try ScriptHash(from: elements[1])
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            try anchor.toPrimitive(),
            scriptHash?.toPrimitive() ?? .null
        ])
    }
}
