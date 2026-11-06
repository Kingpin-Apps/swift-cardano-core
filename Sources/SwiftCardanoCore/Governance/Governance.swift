import Foundation

/// The key type in the high four bits of a CIP-129 governance id's header byte.
public enum GovernanceKeyType: Int, Sendable {
    /// A constitutional committee hot key.
    case ccHot = 0b0000
    /// A constitutional committee cold key.
    case ccCold = 0b0001
    /// A DRep key.
    case drep = 0b0010
}

/// The credential type in the low four bits of a CIP-129 governance id's header byte.
public enum GovernanceCredentialType: Int, Sendable {
    /// The credential is a key hash.
    case keyHash = 0b0010
    /// The credential is a script hash.
    case scriptHash = 0b0011
}

/// The tag that starts a governance action's CBOR array.
public enum GovActionCode: Int, Codable {
    /// Tag 0, ``ParameterChangeAction``.
    case parameterChangeAction = 0
    /// Tag 1, ``HardForkInitiationAction``.
    case hardForkInitiationAction = 1
    /// Tag 2, ``TreasuryWithdrawalsAction``.
    case treasuryWithdrawalsAction = 2
    /// Tag 3, ``NoConfidence``.
    case noConfidence = 3
    /// Tag 4, ``UpdateCommittee``.
    case updateCommittee = 4
    /// Tag 5, ``NewConstitution``.
    case newConstitution = 5
    /// Tag 6, ``InfoAction``.
    case infoAction = 6
}

/// A Conway governance action that a proposal procedure can carry.
public protocol GovernanceAction: CBORSerializable, Sendable {
    /// The action's tag: the integer that starts its CBOR array.
    static var code: GovActionCode { get }
}

/// A governance action of any kind: `gov_action` in the Conway CDDL.
///
/// Each case wraps the action type for one ``GovActionCode``. JSON writes the action as its CBOR hex.
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

/// The id of a governance action: `gov_action_id = [transaction_id, gov_action_index]`.
///
/// The id is the hash of the transaction that proposed the action and the action's index among that transaction's proposals.
public struct GovActionID: Serializable, Sendable {
    /// The id of the transaction that submitted the proposal.
    public let transactionID: TransactionId
    /// The index of the proposal within that transaction.
    public let govActionIndex: UInt16
    
    /// Creates a governance action id.
    /// - Parameters:
    ///   - transactionID: The id of the transaction that submitted the proposal.
    ///   - govActionIndex: The index of the proposal within that transaction.
    public init(transactionID: TransactionId, govActionIndex: UInt16) {
        self.transactionID = transactionID
        self.govActionIndex = govActionIndex
    }
    
    /// Creates a governance action id from a CIP-129 bech32 string.
    /// - Parameter bech32: A bech32 string with the `gov_action` prefix.
    /// - Throws: `CardanoCoreError.valueError` when the string is not a `gov_action` id.
    public init(from bech32: String) throws {
        let _bech32 = Bech32()
        let (hrp, checksum, _) = try _bech32.bech32Decode(bech32)
        let data = _bech32.convertBits(data: checksum, fromBits: 5, toBits: 8, pad: false)
        
        guard let data, hrp == "gov_action" else {
            throw CardanoCoreError.valueError("Invalid GovActionID format: \(bech32).")
        }
        
        try self.init(from: data)
    }
    
    /// Creates a governance action id from its CIP-129 bytes: the 32-byte transaction id followed by the index.
    /// - Parameter hex: The id's bytes. An index left out reads as 0.
    /// - Throws: `CardanoCoreError.valueError` when the bytes are malformed or the index does not fit in a `UInt16`.
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
    
    /// Reads ``toDict()``'s form.
    public static func fromDict(_ primitive: Primitive) throws -> GovActionID {
        guard case let .orderedDict(dict) = primitive,
              let transactionID = dict[.string("transactionId")],
              let index = dict[.string("govActionIndex")] else {
            throw CardanoCoreError.deserializeError("Invalid GovActionID dict: \(primitive)")
        }
        return GovActionID(
            transactionID: try TransactionId.fromDict(transactionID),
            govActionIndex: try index.integer("GovActionID index", as: UInt16.self))
    }

    /// `{"transactionId": hex, "govActionIndex": n}`.
    public func toDict() throws -> Primitive {
        .orderedDict([
            .string("transactionId"): .string(transactionID.payload.toHex),
            .string("govActionIndex"): .integer(govActionIndex),
        ])
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
    
    /// The governance action id as a string.
    /// - Parameter format: `.bech32` for a CIP-129 `gov_action…` string or `.hex` for its bytes in hex.
    /// - Returns: The id in the requested format.
    public func id(_ format: CredentialFormat = .bech32) throws -> String {
        switch format {
            case .bech32:
                return try self.toBech32()
            case .hex:
                return try self.toBytes().toHex
        }
    }
    
    /// Decode a bech32 string into an GovActionID object.
    /// - Parameter govActionID: Bech32-encoded string.
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
    
    /// The id's CIP-129 bytes: the transaction id followed by the index in big-endian, with no leading zero byte.
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
    /// The threshold for a motion of no confidence.
    public var motionNoConfidence: UnitInterval
    /// The threshold for updating the committee in a normal state.
    public var committeeNormal: UnitInterval
    /// The threshold for updating the committee in a state of no confidence.
    public var committeeNoConfidence: UnitInterval
    /// The threshold for a hard fork initiation.
    public var hardForkInitiation: UnitInterval
    /// The threshold for protocol parameter changes in the security group.
    public var ppSecurityGroup: UnitInterval

    /// The thresholds in the CDDL's order.
    public var thresholds: [UnitInterval] {
        [motionNoConfidence, committeeNormal, committeeNoConfidence, hardForkInitiation, ppSecurityGroup]
    }

    /// Creates pool voting thresholds.
    /// - Parameters:
    ///   - motionNoConfidence: The threshold for a motion of no confidence.
    ///   - committeeNormal: The threshold for updating the committee in a normal state.
    ///   - committeeNoConfidence: The threshold for updating the committee in a state of no confidence.
    ///   - hardForkInitiation: The threshold for a hard fork initiation.
    ///   - ppSecurityGroup: The threshold for security-group parameter changes.
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

/// The thresholds DReps vote with: `drep_voting_thresholds = [10 * unit_interval]`.
///
/// In the CDDL's order: motion no confidence, committee normal, committee no confidence, update constitution, hard fork initiation, network group, economic group, technical group, governance group and treasury withdrawal.
public struct DrepVotingThresholds: CBORSerializable, Sendable  {
    /// The ten thresholds, in the CDDL's order.
    public var thresholds: [UnitInterval]
    
    /// Thresholds known to be the ten in the CDDL's order.
    init(ledgerOrder thresholds: [UnitInterval]) {
        self.thresholds = thresholds
    }

    /// Creates DRep voting thresholds.
    /// - Parameter thresholds: The ten thresholds, in the CDDL's order.
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

/// The constitution: `constitution = [anchor, script_hash / nil]`.
public struct Constitution: CBORSerializable, Sendable {
    /// The anchor to the constitution's text.
    public let anchor: Anchor
    /// The hash of the guardrails script, or `nil` when there is none.
    public let scriptHash: ScriptHash?
    
    /// Creates a constitution.
    /// - Parameters:
    ///   - anchor: The anchor to the constitution's text.
    ///   - scriptHash: The hash of the guardrails script, or `nil` for none.
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
