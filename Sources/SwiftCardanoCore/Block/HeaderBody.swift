import Foundation
import OrderedCollections
import SwiftNcal

/// Block header body as defined in the Cardano CDDL.
///
/// The wire format inlines the `operational_cert` group and `protocol_version` group
/// directly into the parent array, so the actual element count differs from the logical
/// CDDL field count:
///
/// **Alonzo / Babbage / Conway (eras 4–6) — 14 flat elements:**
/// ```
///  [0]  block_number    : uint
///  [1]  slot            : uint
///  [2]  prev_hash       : hash32 / nil
///  [3]  issuer_vkey     : bytes (32)
///  [4]  vrf_vkey        : bytes (32)
///  [5]  vrf_result      : vrf_cert [output, proof(80)]
///  [6]  block_body_size : uint
///  [7]  block_body_hash : bytes (32)
///  [8]  hot_vkey        : bytes (32)   ← operational_cert inlined
///  [9]  sequence_number : uint
/// [10]  kes_period      : uint
/// [11]  sigma           : bytes (64)
/// [12]  major           : uint          ← protocol_version inlined
/// [13]  minor           : uint
/// ```
///
/// **Shelley / Allegra / Mary (eras 1–3) — 15 flat elements:**
/// Same layout but with two VRF fields instead of one:
/// ```
///  [5]  nonce_vrf       : vrf_cert
///  [6]  leader_vrf      : vrf_cert
///  [7]  block_body_size  …
/// ```
public struct HeaderBody: Serializable {
    /// Block number (height)
    public var blockNumber: BlockNumber
    /// Absolute slot number
    public var slot: SlotNumber
    /// Previous block header hash (nil for genesis)
    public var prevHash: BlockHeaderHash?
    /// Block issuer verification key (32 bytes)
    public var issuerVKey: Data
    /// VRF verification key (32 bytes)
    public var vrfVKey: Data
    /// Primary VRF result certificate (`leader_vrf` for Shelley–Mary, `vrf_result` for Alonzo+)
    public var vrfResult: VRFCert
    /// Nonce VRF certificate (Shelley / Allegra / Mary only — eras 1–3)
    public var nonceVrf: VRFCert?
    /// Size of the block body in bytes
    public var blockBodySize: UInt32
    /// Hash of the block body
    public var blockBodyHash: BlockBodyHash
    /// Operational certificate (fields inlined in the wire format)
    public var operationalCert: OperationalCertificate
    /// Protocol version (fields inlined in the wire format)
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
        case nonceVrf
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
        nonceVrf: VRFCert? = nil,
        blockBodySize: UInt32,
        blockBodyHash: BlockBodyHash,
        operationalCert: OperationalCertificate,
        protocolVersion: ProtocolVersion
    ) {
        self.blockNumber = blockNumber
        self.slot = slot
        self.prevHash = prevHash
        self.issuerVKey = issuerVKey
        self.vrfVKey = vrfVKey
        self.vrfResult = vrfResult
        self.nonceVrf = nonceVrf
        self.blockBodySize = blockBodySize
        self.blockBodyHash = blockBodyHash
        self.operationalCert = operationalCert
        self.protocolVersion = protocolVersion
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case .list(let elements) = primitive else {
            throw CardanoCoreError.deserializeError(
                "Invalid HeaderBody primitive: expected list"
            )
        }

        // 14 elements: Alonzo / Babbage / Conway (single vrf_result, flat op_cert + protocol_version)
        // 15 elements: Shelley / Allegra / Mary (nonce_vrf + leader_vrf, flat op_cert + protocol_version)
        // 10 elements: Alonzo / Babbage / Conway (single vrf_result, nested op_cert + protocol_version)
        // 11 elements: Shelley / Allegra / Mary (nonce_vrf + leader_vrf, nested op_cert + protocol_version)
        guard
            elements.count == 10 || elements.count == 11 || elements.count == 14
                || elements.count == 15
        else {
            throw CardanoCoreError.deserializeError(
                "HeaderBody requires 14 or 15 elements on the wire, got \(elements.count)"
            )
        }

        let hasSplitVrf = elements.count == 15 || elements.count == 11
        let nestedCert = elements.count == 10 || elements.count == 11

        // [0] block_number
        switch elements[0] {
        case .uint(let val): self.blockNumber = BlockNumber(val)
        case .int(let val): self.blockNumber = BlockNumber(val)
        default: throw CardanoCoreError.deserializeError("Invalid HeaderBody block_number type")
        }

        // [1] slot
        switch elements[1] {
        case .uint(let val): self.slot = SlotNumber(val)
        case .int(let val): self.slot = SlotNumber(val)
        default: throw CardanoCoreError.deserializeError("Invalid HeaderBody slot type")
        }

        // [2] prev_hash (hash32 / nil)
        if case .null = elements[2] {
            self.prevHash = nil
        } else {
            self.prevHash = try BlockHeaderHash(from: elements[2])
        }

        // [3] issuer_vkey
        guard case .bytes(let issuerVKey) = elements[3] else {
            throw CardanoCoreError.deserializeError(
                "Invalid HeaderBody issuer_vkey: expected bytes")
        }
        self.issuerVKey = issuerVKey

        // [4] vrf_vkey
        guard case .bytes(let vrfVKey) = elements[4] else {
            throw CardanoCoreError.deserializeError("Invalid HeaderBody vrf_vkey: expected bytes")
        }
        self.vrfVKey = vrfVKey

        // [5] nonce_vrf (Shelley–Mary) or vrf_result (Alonzo+)
        // [6] leader_vrf (Shelley–Mary only)
        let vrfOffset: Int
        if hasSplitVrf {
            self.nonceVrf = try VRFCert(from: elements[5])
            self.vrfResult = try VRFCert(from: elements[6])
            vrfOffset = 1
        } else {
            self.nonceVrf = nil
            self.vrfResult = try VRFCert(from: elements[5])
            vrfOffset = 0
        }

        // block_body_size — index shifts by 1 for split-VRF eras
        switch elements[6 + vrfOffset] {
        case .uint(let val): self.blockBodySize = UInt32(val)
        case .int(let val): self.blockBodySize = UInt32(val)
        default: throw CardanoCoreError.deserializeError("Invalid HeaderBody block_body_size type")
        }

        // block_body_hash
        self.blockBodyHash = try BlockBodyHash(from: elements[7 + vrfOffset])

        if nestedCert {
            // operational_cert encoded as a nested 4-element array
            guard case .list(let certElems) = elements[8 + vrfOffset], certElems.count == 4 else {
                throw CardanoCoreError.deserializeError(
                    "Invalid HeaderBody operational_cert: expected 4-element array")
            }
            guard case .bytes(let hotVKeyBytes) = certElems[0] else {
                throw CardanoCoreError.deserializeError(
                    "Invalid HeaderBody hot_vkey: expected bytes")
            }
            let hotVKey = KESVerificationKey(payload: hotVKeyBytes, type: nil, description: nil)

            let sequenceNumber: UInt64
            switch certElems[1] {
            case .uint(let val): sequenceNumber = UInt64(val)
            case .int(let val): sequenceNumber = UInt64(val)
            default:
                throw CardanoCoreError.deserializeError("Invalid HeaderBody sequence_number type")
            }

            let kesPeriod: UInt64
            switch certElems[2] {
            case .uint(let val): kesPeriod = UInt64(val)
            case .int(let val): kesPeriod = UInt64(val)
            default: throw CardanoCoreError.deserializeError("Invalid HeaderBody kes_period type")
            }

            guard case .bytes(let sigma) = certElems[3] else {
                throw CardanoCoreError.deserializeError("Invalid HeaderBody sigma: expected bytes")
            }

            self.operationalCert = try OperationalCertificate(
                hotVKey: hotVKey,
                sequenceNumber: sequenceNumber,
                kesPeriod: kesPeriod,
                sigma: sigma
            )

            // protocol_version encoded as a nested 2-element array
            guard case .list(let pvElems) = elements[9 + vrfOffset], pvElems.count == 2 else {
                throw CardanoCoreError.deserializeError(
                    "Invalid HeaderBody protocol_version: expected 2-element array")
            }
            let major: Int
            switch pvElems[0] {
            case .uint(let val): major = Int(val)
            case .int(let val): major = Int(val)
            default:
                throw CardanoCoreError.deserializeError("Invalid HeaderBody protocol major type")
            }
            let minor: Int
            switch pvElems[1] {
            case .uint(let val): minor = Int(val)
            case .int(let val): minor = Int(val)
            default:
                throw CardanoCoreError.deserializeError("Invalid HeaderBody protocol minor type")
            }
            self.protocolVersion = ProtocolVersion(major: major, minor: minor)
        } else {
            // operational_cert — 4 fields inlined flat
            guard case .bytes(let hotVKeyBytes) = elements[8 + vrfOffset] else {
                throw CardanoCoreError.deserializeError(
                    "Invalid HeaderBody hot_vkey: expected bytes")
            }
            let hotVKey = KESVerificationKey(payload: hotVKeyBytes, type: nil, description: nil)

            let sequenceNumber: UInt64
            switch elements[9 + vrfOffset] {
            case .uint(let val): sequenceNumber = UInt64(val)
            case .int(let val): sequenceNumber = UInt64(val)
            default:
                throw CardanoCoreError.deserializeError("Invalid HeaderBody sequence_number type")
            }

            let kesPeriod: UInt64
            switch elements[10 + vrfOffset] {
            case .uint(let val): kesPeriod = UInt64(val)
            case .int(let val): kesPeriod = UInt64(val)
            default: throw CardanoCoreError.deserializeError("Invalid HeaderBody kes_period type")
            }

            guard case .bytes(let sigma) = elements[11 + vrfOffset] else {
                throw CardanoCoreError.deserializeError("Invalid HeaderBody sigma: expected bytes")
            }

            self.operationalCert = try OperationalCertificate(
                hotVKey: hotVKey,
                sequenceNumber: sequenceNumber,
                kesPeriod: kesPeriod,
                sigma: sigma
            )

            // protocol_version — 2 fields inlined flat
            let major: Int
            switch elements[12 + vrfOffset] {
            case .uint(let val): major = Int(val)
            case .int(let val): major = Int(val)
            default:
                throw CardanoCoreError.deserializeError("Invalid HeaderBody protocol major type")
            }

            let minor: Int
            switch elements[13 + vrfOffset] {
            case .uint(let val): minor = Int(val)
            case .int(let val): minor = Int(val)
            default:
                throw CardanoCoreError.deserializeError("Invalid HeaderBody protocol minor type")
            }

            self.protocolVersion = ProtocolVersion(major: major, minor: minor)
        }
    }

    public func toPrimitive() throws -> Primitive {
        var fields: [Primitive] = [
            .uint(UInt64(blockNumber)),
            .uint(UInt64(slot)),
            prevHash != nil ? prevHash!.toPrimitive() : .null,
            .bytes(issuerVKey),
            .bytes(vrfVKey),
        ]

        if let nonceVrf {
            fields.append(try nonceVrf.toPrimitive())
            fields.append(try vrfResult.toPrimitive())
        } else {
            fields.append(try vrfResult.toPrimitive())
        }

        fields += [
            .uint(UInt64(blockBodySize)),
            blockBodyHash.toPrimitive(),
            // operational_cert inlined
            .bytes(operationalCert.hotVKey.payload),
            .uint(UInt64(operationalCert.sequenceNumber)),
            .uint(UInt64(operationalCert.kesPeriod)),
            .bytes(operationalCert.sigma),
            // protocol_version inlined
            .uint(UInt64(protocolVersion.major ?? 0)),
            .uint(UInt64(protocolVersion.minor ?? 0)),
        ]

        return .list(fields)
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> HeaderBody {
        guard case .orderedDict(let dict) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid HeaderBody dict")
        }

        guard let blockNumberPrimitive = dict[.string(CodingKeys.blockNumber.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing blockNumber in HeaderBody")
        }
        let blockNumber: BlockNumber
        switch blockNumberPrimitive {
        case .uint(let val): blockNumber = BlockNumber(val)
        case .int(let val): blockNumber = BlockNumber(val)
        default: throw CardanoCoreError.deserializeError("Invalid blockNumber type in HeaderBody")
        }

        guard let slotPrimitive = dict[.string(CodingKeys.slot.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing slot in HeaderBody")
        }
        let slot: SlotNumber
        switch slotPrimitive {
        case .uint(let val): slot = SlotNumber(val)
        case .int(let val): slot = SlotNumber(val)
        default: throw CardanoCoreError.deserializeError("Invalid slot type in HeaderBody")
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
            case .bytes(let issuerVKey) = issuerVKeyPrimitive
        else {
            throw CardanoCoreError.deserializeError("Missing or invalid issuerVKey in HeaderBody")
        }

        guard let vrfVKeyPrimitive = dict[.string(CodingKeys.vrfVKey.rawValue)],
            case .bytes(let vrfVKey) = vrfVKeyPrimitive
        else {
            throw CardanoCoreError.deserializeError("Missing or invalid vrfVKey in HeaderBody")
        }

        guard let vrfResultPrimitive = dict[.string(CodingKeys.vrfResult.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing vrfResult in HeaderBody")
        }
        let vrfResult = try VRFCert.fromDict(vrfResultPrimitive)

        var nonceVrf: VRFCert? = nil
        if let nonceVrfPrimitive = dict[.string(CodingKeys.nonceVrf.rawValue)] {
            nonceVrf = try VRFCert.fromDict(nonceVrfPrimitive)
        }

        guard let blockBodySizePrimitive = dict[.string(CodingKeys.blockBodySize.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing blockBodySize in HeaderBody")
        }
        let blockBodySize: UInt32
        switch blockBodySizePrimitive {
        case .uint(let val): blockBodySize = UInt32(val)
        case .int(let val): blockBodySize = UInt32(val)
        default: throw CardanoCoreError.deserializeError("Invalid blockBodySize type in HeaderBody")
        }

        guard let blockBodyHashPrimitive = dict[.string(CodingKeys.blockBodyHash.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing blockBodyHash in HeaderBody")
        }
        let blockBodyHash = try BlockBodyHash.fromDict(blockBodyHashPrimitive)

        guard let operationalCertPrimitive = dict[.string(CodingKeys.operationalCert.rawValue)]
        else {
            throw CardanoCoreError.deserializeError("Missing operationalCert in HeaderBody")
        }
        let operationalCert = try OperationalCertificate.fromDict(operationalCertPrimitive)

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
            nonceVrf: nonceVrf,
            blockBodySize: blockBodySize,
            blockBodyHash: blockBodyHash,
            operationalCert: operationalCert,
            protocolVersion: protocolVersion
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.blockNumber.rawValue)] = .uint(UInt64(blockNumber))
        dict[.string(CodingKeys.slot.rawValue)] = .uint(UInt64(slot))
        if let prevHash {
            dict[.string(CodingKeys.prevHash.rawValue)] = try prevHash.toDict()
        } else {
            dict[.string(CodingKeys.prevHash.rawValue)] = .null
        }
        dict[.string(CodingKeys.issuerVKey.rawValue)] = .bytes(issuerVKey)
        dict[.string(CodingKeys.vrfVKey.rawValue)] = .bytes(vrfVKey)
        dict[.string(CodingKeys.vrfResult.rawValue)] = try vrfResult.toDict()
        if let nonceVrf {
            dict[.string(CodingKeys.nonceVrf.rawValue)] = try nonceVrf.toDict()
        }
        dict[.string(CodingKeys.blockBodySize.rawValue)] = .uint(UInt64(blockBodySize))
        dict[.string(CodingKeys.blockBodyHash.rawValue)] = try blockBodyHash.toDict()
        dict[.string(CodingKeys.operationalCert.rawValue)] = try operationalCert.toDict()
        dict[.string(CodingKeys.protocolVersion.rawValue)] = try protocolVersion.toPrimitive()
        return .orderedDict(dict)
    }

    // MARK: - Equatable

    public static func == (lhs: HeaderBody, rhs: HeaderBody) -> Bool {
        return lhs.blockNumber == rhs.blockNumber && lhs.slot == rhs.slot
            && lhs.prevHash == rhs.prevHash && lhs.issuerVKey == rhs.issuerVKey
            && lhs.vrfVKey == rhs.vrfVKey && lhs.vrfResult == rhs.vrfResult
            && lhs.nonceVrf == rhs.nonceVrf && lhs.blockBodySize == rhs.blockBodySize
            && lhs.blockBodyHash == rhs.blockBodyHash && lhs.operationalCert == rhs.operationalCert
            && lhs.protocolVersion == rhs.protocolVersion
    }

    // MARK: - Hashable
    
    public func hash() -> Data {
        return try! Hash().blake2b(
            data: try self.toCBORData(),
            digestSize: BLOCK_HEADER_HASH_SIZE,
            encoder: RawEncoder.self
        )
    }
}
