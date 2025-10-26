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

public protocol GovernanceAction: CBORSerializable {
    static var code: GovActionCode { get }
}

public enum GovAction: CBORSerializable {
    case parameterChangeAction(ParameterChangeAction)
    case hardForkInitiationAction(HardForkInitiationAction)
    case treasuryWithdrawalsAction(TreasuryWithdrawalsAction)
    case noConfidence(NoConfidence)
    case updateCommittee(UpdateCommittee)
    case newConstitution(NewConstitution)
    case infoAction(InfoAction)
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitiveList) = primitive,
              !primitiveList.isEmpty,
              case let .uint(code) = primitiveList[0],
              let govActionCode = GovActionCode(rawValue: Int(code)) else {
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

public struct GovActionID: CBORSerializable, Hashable, Equatable {
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
        
        let transactionID = try TransactionId(from: .string(utxoHex))
        
        self.init(
            transactionID: transactionID,
            govActionIndex: UInt16(idx)
        )
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        transactionID = try container.decode(TransactionId.self)
        govActionIndex = try container.decode(UInt16.self)
    }
    
    public init(from primitive: Primitive) throws {
        if case let .list(primitiveList) = primitive,
           primitiveList.count == 2 {
            
            let transactionID = try TransactionId(from: primitiveList[0])
            
            guard case let .uint(govActionIndex) = primitiveList[1] else {
                throw CardanoCoreError.deserializeError("Invalid GovActionID type")
            }
            
            self.init(transactionID: transactionID, govActionIndex: UInt16(govActionIndex))
            
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
        return .list([
            .string(transactionID.payload.toHex),
            .uint(UInt(govActionIndex))
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

public struct PoolVotingThresholds: CBORSerializable, Hashable, Equatable {
    public var committeeNoConfidence: UnitInterval?
    public var committeeNormal: UnitInterval?
    public var hardForkInitiation: UnitInterval?
    public var motionNoConfidence: UnitInterval?
    public var ppSecurityGroup: UnitInterval?
    
    enum CodingKeys: String, CodingKey {
        case committeeNoConfidence = "committee_no_confidence"
        case committeeNormal = "committee_normal"
        case hardForkInitiation = "hard_fork_initiation"
        case motionNoConfidence = "motion_no_confidence"
        case ppSecurityGroup = "pp_security_group"
    }
    
    public var thresholds: [UnitInterval]
    
    public init(committeeNoConfidence: UnitInterval, committeeNormal: UnitInterval, hardForkInitiation: UnitInterval, motionNoConfidence: UnitInterval, ppSecurityGroup: UnitInterval) {
        self.committeeNoConfidence = committeeNoConfidence
        self.committeeNormal = committeeNormal
        self.hardForkInitiation = hardForkInitiation
        self.motionNoConfidence = motionNoConfidence
        self.ppSecurityGroup = ppSecurityGroup
        
        self.thresholds = [
            committeeNoConfidence,
            committeeNormal,
            hardForkInitiation,
            motionNoConfidence,
            ppSecurityGroup
        ]
    }
    
    
    public init(from thresholds: [UnitInterval]) {
        precondition(thresholds.count == 5, "There must be exactly 5 unit intervals")
        self.thresholds = thresholds
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        committeeNoConfidence = try container.decodeIfPresent(UnitInterval.self)
        committeeNormal = try container.decodeIfPresent(UnitInterval.self)
        hardForkInitiation = try container.decodeIfPresent(UnitInterval.self)
        motionNoConfidence = try container.decodeIfPresent(UnitInterval.self)
        ppSecurityGroup = try container.decodeIfPresent(UnitInterval.self)
        
        thresholds = [
            committeeNoConfidence!,
            committeeNormal!,
            hardForkInitiation!,
            motionNoConfidence!,
            ppSecurityGroup!
        ]
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 5 else {
            throw CardanoCoreError.deserializeError("Invalid PoolVotingThresholds type")
        }
        self.committeeNoConfidence = try UnitInterval(from: primitive[0])
        self.committeeNormal = try UnitInterval(from: primitive[1])
        self.hardForkInitiation = try UnitInterval(from: primitive[2])
        self.motionNoConfidence = try UnitInterval(from: primitive[3])
        self.ppSecurityGroup = try UnitInterval(from: primitive[4])
        self.thresholds = [
            committeeNoConfidence!,
            committeeNormal!,
            hardForkInitiation!,
            motionNoConfidence!,
            ppSecurityGroup!
        ]
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(committeeNoConfidence)
        try container.encode(committeeNormal)
        try container.encode(hardForkInitiation)
        try container.encode(motionNoConfidence)
        try container.encode(ppSecurityGroup)
    }
    
    public func toPrimitive() throws -> Primitive {
        var list: [Primitive] = []
        if let committeeNoConfidence = committeeNoConfidence {
            list.append(try committeeNoConfidence.toPrimitive())
        } else {
            list.append(.null)
        }
        if let committeeNormal = committeeNormal {
            list.append(try committeeNormal.toPrimitive())
        } else {
            list.append(.null)
        }
        if let hardForkInitiation = hardForkInitiation {
            list.append(try hardForkInitiation.toPrimitive())
        } else {
            list.append(.null)
        }
        if let motionNoConfidence = motionNoConfidence {
            list.append(try motionNoConfidence.toPrimitive())
        } else {
            list.append(.null)
        }
        if let ppSecurityGroup = ppSecurityGroup {
            list.append(try ppSecurityGroup.toPrimitive())
        } else {
            list.append(.null)
        }
        return .list(list)
    }
    
}

public struct DrepVotingThresholds: CBORSerializable, Hashable, Equatable  {
    public var thresholds: [UnitInterval]
    
    public init(thresholds: [UnitInterval]) {
        precondition(thresholds.count == 10, "There must be exactly 10 unit intervals")
        self.thresholds = thresholds
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        thresholds = try container.decode([UnitInterval].self)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 10 else {
            throw CardanoCoreError.deserializeError("Invalid DrepVotingThresholds type")
        }
        self.thresholds = try primitive.map { try UnitInterval(from: $0) }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try thresholds.forEach { try container.encode($0) }
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list(try thresholds.map { try $0.toPrimitive() })
    }
}

public struct Constitution: CBORSerializable, Hashable, Equatable {
    public let anchor: Anchor
    public let scriptHash: ScriptHash?
    
    public init(anchor: Anchor, scriptHash: ScriptHash?) {
        self.anchor = anchor
        self.scriptHash = scriptHash
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        anchor = try container.decode(Anchor.self)
        scriptHash = try container.decode(ScriptHash.self)
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
              primitive.count == 2 else {
            throw CardanoCoreError.deserializeError("Invalid Constitution type")
        }
        self.anchor = try Anchor(from: primitive[0])
        self.scriptHash = try ScriptHash(from: primitive[1])
        
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(anchor)
        try container.encode(scriptHash)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            try anchor.toPrimitive(),
            scriptHash?.toPrimitive() ?? .null
        ])
    }
}
