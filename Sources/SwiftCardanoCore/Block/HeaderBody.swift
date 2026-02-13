import Foundation
import OrderedCollections

/// Block header body as defined in the Conway CDDL:
/// ```
/// header_body =
///   [ block_number   : uint
///   , slot           : uint
///   , prev_hash      : $hash32 / nil
///   , issuer_vkey    : $vkey
///   , vrf_vkey       : $vrf_vkey
///   , vrf_result     : $vrf_cert
///   , block_body_size : uint
///   , block_body_hash : $hash32
///   , operational_cert : operational_cert
///   , protocol_version : protocol_version
///   ]
/// ```
///
/// Serialized as a CBOR array with 10 elements.
public struct HeaderBody: Serializable {
    /// Block number
    public var blockNumber: BlockNumber
    /// Slot number
    public var slot: SlotNumber
    /// Previous block header hash (nil for genesis block)
    public var prevHash: BlockHeaderHash?
    /// Block issuer verification key (32 bytes)
    public var issuerVKey: Data
    /// VRF verification key (32 bytes)
    public var vrfVKey: Data
    /// VRF result certificate
    public var vrfResult: VRFCert
    /// Size of the block body in bytes
    public var blockBodySize: UInt32
    /// Hash of the block body
    public var blockBodyHash: BlockBodyHash
    /// Operational certificate
    public var operationalCert: OperationalCert
    /// Protocol version
    public var protocolVersion: ProtocolVersion

    public static let VKEY_SIZE = 32
    public static let VRF_VKEY_SIZE = 32

    enum CodingKeys: String, CodingKey {
        case blockNumber
        case slot
        case prevHash
        case issuerVKey
        case vrfVKey
        case vrfResult
        case blockBodySize
        case blockBodyHash
        case operationalCert
        case protocolVersion
    }

    public init(
        blockNumber: BlockNumber,
        slot: SlotNumber,
        prevHash: BlockHeaderHash?,
        issuerVKey: Data,
        vrfVKey: Data,
        vrfResult: VRFCert,
        blockBodySize: UInt32,
        blockBodyHash: BlockBodyHash,
        operationalCert: OperationalCert,
        protocolVersion: ProtocolVersion
    ) {
        self.blockNumber = blockNumber
        self.slot = slot
        self.prevHash = prevHash
        self.issuerVKey = issuerVKey
        self.vrfVKey = vrfVKey
        self.vrfResult = vrfResult
        self.blockBodySize = blockBodySize
        self.blockBodyHash = blockBodyHash
        self.operationalCert = operationalCert
        self.protocolVersion = protocolVersion
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError(
                "Invalid HeaderBody primitive: expected list"
            )
        }

        guard elements.count == 10 else {
            throw CardanoCoreError.deserializeError(
                "HeaderBody requires exactly 10 elements, got \(elements.count)"
            )
        }

        // 0: block_number
        switch elements[0] {
        case .uint(let val):
            self.blockNumber = BlockNumber(val)
        case .int(let val):
            self.blockNumber = BlockNumber(val)
        default:
            throw CardanoCoreError.deserializeError("Invalid HeaderBody block_number type")
        }

        // 1: slot
        switch elements[1] {
        case .uint(let val):
            self.slot = SlotNumber(val)
        case .int(let val):
            self.slot = SlotNumber(val)
        default:
            throw CardanoCoreError.deserializeError("Invalid HeaderBody slot type")
        }

        // 2: prev_hash (hash32 / nil)
        if case .null = elements[2] {
            self.prevHash = nil
        } else {
            self.prevHash = try BlockHeaderHash(from: elements[2])
        }

        // 3: issuer_vkey (bytes .size 32)
        guard case let .bytes(issuerVKey) = elements[3] else {
            throw CardanoCoreError.deserializeError("Invalid HeaderBody issuer_vkey: expected bytes")
        }
        self.issuerVKey = issuerVKey

        // 4: vrf_vkey (bytes .size 32)
        guard case let .bytes(vrfVKey) = elements[4] else {
            throw CardanoCoreError.deserializeError("Invalid HeaderBody vrf_vkey: expected bytes")
        }
        self.vrfVKey = vrfVKey

        // 5: vrf_result (vrf_cert)
        self.vrfResult = try VRFCert(from: elements[5])

        // 6: block_body_size (uint .size 4)
        switch elements[6] {
        case .uint(let val):
            self.blockBodySize = UInt32(val)
        case .int(let val):
            self.blockBodySize = UInt32(val)
        default:
            throw CardanoCoreError.deserializeError("Invalid HeaderBody block_body_size type")
        }

        // 7: block_body_hash (hash32)
        self.blockBodyHash = try BlockBodyHash(from: elements[7])

        // 8: operational_cert
        self.operationalCert = try OperationalCert(from: elements[8])

        // 9: protocol_version
        self.protocolVersion = try ProtocolVersion(from: elements[9])
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(blockNumber)),
            .uint(UInt(slot)),
            prevHash != nil ? prevHash!.toPrimitive() : .null,
            .bytes(issuerVKey),
            .bytes(vrfVKey),
            try vrfResult.toPrimitive(),
            .uint(UInt(blockBodySize)),
            blockBodyHash.toPrimitive(),
            try operationalCert.toPrimitive(),
            try protocolVersion.toPrimitive()
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> HeaderBody {
        guard case let .orderedDict(dict) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid HeaderBody dict")
        }

        guard let blockNumberPrimitive = dict[.string(CodingKeys.blockNumber.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing blockNumber in HeaderBody")
        }
        let blockNumber: BlockNumber
        switch blockNumberPrimitive {
        case .uint(let val): blockNumber = BlockNumber(val)
        case .int(let val): blockNumber = BlockNumber(val)
        default:
            throw CardanoCoreError.deserializeError("Invalid blockNumber type in HeaderBody")
        }

        guard let slotPrimitive = dict[.string(CodingKeys.slot.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing slot in HeaderBody")
        }
        let slot: SlotNumber
        switch slotPrimitive {
        case .uint(let val): slot = SlotNumber(val)
        case .int(let val): slot = SlotNumber(val)
        default:
            throw CardanoCoreError.deserializeError("Invalid slot type in HeaderBody")
        }

        var prevHash: BlockHeaderHash? = nil
        if let prevHashPrimitive = dict[.string(CodingKeys.prevHash.rawValue)] {
            if case .null = prevHashPrimitive {
                prevHash = nil
            } else {
                prevHash = try BlockHeaderHash.fromDict(prevHashPrimitive)
            }
        }

        guard let issuerVKeyPrimitive = dict[.string(CodingKeys.issuerVKey.rawValue)],
              case let .bytes(issuerVKey) = issuerVKeyPrimitive else {
            throw CardanoCoreError.deserializeError("Missing or invalid issuerVKey in HeaderBody")
        }

        guard let vrfVKeyPrimitive = dict[.string(CodingKeys.vrfVKey.rawValue)],
              case let .bytes(vrfVKey) = vrfVKeyPrimitive else {
            throw CardanoCoreError.deserializeError("Missing or invalid vrfVKey in HeaderBody")
        }

        guard let vrfResultPrimitive = dict[.string(CodingKeys.vrfResult.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing vrfResult in HeaderBody")
        }
        let vrfResult = try VRFCert.fromDict(vrfResultPrimitive)

        guard let blockBodySizePrimitive = dict[.string(CodingKeys.blockBodySize.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing blockBodySize in HeaderBody")
        }
        let blockBodySize: UInt32
        switch blockBodySizePrimitive {
        case .uint(let val): blockBodySize = UInt32(val)
        case .int(let val): blockBodySize = UInt32(val)
        default:
            throw CardanoCoreError.deserializeError("Invalid blockBodySize type in HeaderBody")
        }

        guard let blockBodyHashPrimitive = dict[.string(CodingKeys.blockBodyHash.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing blockBodyHash in HeaderBody")
        }
        let blockBodyHash = try BlockBodyHash.fromDict(blockBodyHashPrimitive)

        guard let operationalCertPrimitive = dict[.string(CodingKeys.operationalCert.rawValue)]
        else {
            throw CardanoCoreError.deserializeError("Missing operationalCert in HeaderBody")
        }
        let operationalCert = try OperationalCert.fromDict(operationalCertPrimitive)

        guard let protocolVersionPrimitive = dict[.string(CodingKeys.protocolVersion.rawValue)]
        else {
            throw CardanoCoreError.deserializeError("Missing protocolVersion in HeaderBody")
        }
        let protocolVersion = try ProtocolVersion(from: protocolVersionPrimitive)

        return HeaderBody(
            blockNumber: blockNumber,
            slot: slot,
            prevHash: prevHash,
            issuerVKey: issuerVKey,
            vrfVKey: vrfVKey,
            vrfResult: vrfResult,
            blockBodySize: blockBodySize,
            blockBodyHash: blockBodyHash,
            operationalCert: operationalCert,
            protocolVersion: protocolVersion
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.blockNumber.rawValue)] = .uint(UInt(blockNumber))
        dict[.string(CodingKeys.slot.rawValue)] = .uint(UInt(slot))
        if let prevHash = prevHash {
            dict[.string(CodingKeys.prevHash.rawValue)] = try prevHash.toDict()
        } else {
            dict[.string(CodingKeys.prevHash.rawValue)] = .null
        }
        dict[.string(CodingKeys.issuerVKey.rawValue)] = .bytes(issuerVKey)
        dict[.string(CodingKeys.vrfVKey.rawValue)] = .bytes(vrfVKey)
        dict[.string(CodingKeys.vrfResult.rawValue)] = try vrfResult.toDict()
        dict[.string(CodingKeys.blockBodySize.rawValue)] = .uint(UInt(blockBodySize))
        dict[.string(CodingKeys.blockBodyHash.rawValue)] = try blockBodyHash.toDict()
        dict[.string(CodingKeys.operationalCert.rawValue)] = try operationalCert.toDict()
        dict[.string(CodingKeys.protocolVersion.rawValue)] = try protocolVersion.toPrimitive()
        return .orderedDict(dict)
    }

    // MARK: - Equatable

    public static func == (lhs: HeaderBody, rhs: HeaderBody) -> Bool {
        return lhs.blockNumber == rhs.blockNumber &&
            lhs.slot == rhs.slot &&
            lhs.prevHash == rhs.prevHash &&
            lhs.issuerVKey == rhs.issuerVKey &&
            lhs.vrfVKey == rhs.vrfVKey &&
            lhs.vrfResult == rhs.vrfResult &&
            lhs.blockBodySize == rhs.blockBodySize &&
            lhs.blockBodyHash == rhs.blockBodyHash &&
            lhs.operationalCert == rhs.operationalCert &&
            lhs.protocolVersion == rhs.protocolVersion
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(blockNumber)
        hasher.combine(slot)
        hasher.combine(prevHash)
        hasher.combine(issuerVKey)
        hasher.combine(vrfVKey)
        hasher.combine(vrfResult)
        hasher.combine(blockBodySize)
        hasher.combine(blockBodyHash)
        hasher.combine(operationalCert)
        hasher.combine(protocolVersion)
    }
}
