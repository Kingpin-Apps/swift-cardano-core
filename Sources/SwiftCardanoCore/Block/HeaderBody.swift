import Foundation
import OrderedCollections
import SwiftNaCl

/// Block header body as defined in the Cardano CDDL.
///
/// Each era writes it in one of two layouts, and which one follows from
/// whether there is a ``nonceVrf``:
///
/// **Shelley to Alonzo (TPraos) — 15 elements, `operational_cert` and
/// `protocol_version` inlined as groups** (shelley.cddl to alonzo.cddl):
/// ```
///  [0]  block_number    : uint
///  [1]  slot            : uint
///  [2]  prev_hash       : hash32 / nil
///  [3]  issuer_vkey     : bytes (32)
///  [4]  vrf_vkey        : bytes (32)
///  [5]  nonce_vrf       : vrf_cert
///  [6]  leader_vrf      : vrf_cert
///  [7]  block_body_size : uint
///  [8]  block_body_hash : bytes (32)
///  [9]  hot_vkey        : bytes (32)   ← operational_cert inlined
/// [10]  sequence_number : uint
/// [11]  kes_period      : uint
/// [12]  sigma           : bytes (64)
/// [13]  major           : uint          ← protocol_version inlined
/// [14]  minor           : uint
/// ```
///
/// **Babbage and Conway (Praos) — 10 elements, `operational_cert` and
/// `protocol_version` nested as arrays** (babbage.cddl, conway.cddl):
/// ```
///  [0]  block_number    : uint
///  [1]  slot            : uint
///  [2]  prev_hash       : hash32 / nil
///  [3]  issuer_vkey     : bytes (32)
///  [4]  vrf_vkey        : bytes (32)
///  [5]  vrf_result      : vrf_cert
///  [6]  block_body_size : uint
///  [7]  block_body_hash : bytes (32)
///  [8]  operational_cert: [hot_vkey, sequence_number, kes_period, sigma]
///  [9]  protocol_version: [major, minor]
/// ```
///
/// No era writes 11 or 14 elements, and the ledger reads neither.
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
        guard let elements = primitive.arrayElements else {
            throw CardanoCoreError.deserializeError(
                "Invalid HeaderBody primitive: expected list"
            )
        }

        // 15 elements: Shelley to Alonzo (nonce_vrf + leader_vrf, flat op_cert + protocol_version)
        // 10 elements: Babbage and Conway (vrf_result, nested op_cert + protocol_version)
        guard elements.count == 10 || elements.count == 15 else {
            throw CardanoCoreError.deserializeError(
                "HeaderBody requires 10 or 15 elements on the wire, got \(elements.count)"
            )
        }

        let isTPraos = elements.count == 15

        // [0] block_number
        self.blockNumber = try elements[0].integer("HeaderBody block_number", as: BlockNumber.self)

        // [1] slot
        self.slot = try elements[1].integer("HeaderBody slot", as: SlotNumber.self)

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

        // [5] nonce_vrf and [6] leader_vrf (TPraos), or [5] vrf_result (Praos)
        let rest: ArraySlice<Primitive>
        if isTPraos {
            self.nonceVrf = try VRFCert(from: elements[5])
            self.vrfResult = try VRFCert(from: elements[6])
            rest = elements[7...]
        } else {
            self.nonceVrf = nil
            self.vrfResult = try VRFCert(from: elements[5])
            rest = elements[6...]
        }

        // block_body_size, block_body_hash
        self.blockBodySize = try rest[rest.startIndex].integer(
            "HeaderBody block_body_size", as: UInt32.self)
        self.blockBodyHash = try BlockBodyHash(from: rest[rest.startIndex + 1])

        // operational_cert and protocol_version: inlined in TPraos, nested in Praos
        let certElems: [Primitive]
        let pvElems: [Primitive]
        if isTPraos {
            certElems = Array(rest[(rest.startIndex + 2)..<(rest.startIndex + 6)])
            pvElems = Array(rest[(rest.startIndex + 6)...])
        } else {
            guard let cert = rest[rest.startIndex + 2].arrayElements, cert.count == 4 else {
                throw CardanoCoreError.deserializeError(
                    "Invalid HeaderBody operational_cert: expected 4-element array")
            }
            guard let version = rest[rest.startIndex + 3].arrayElements, version.count == 2 else {
                throw CardanoCoreError.deserializeError(
                    "Invalid HeaderBody protocol_version: expected 2-element array")
            }
            certElems = cert
            pvElems = version
        }

        guard case .bytes(let hotVKeyBytes) = certElems[0] else {
            throw CardanoCoreError.deserializeError(
                "Invalid HeaderBody hot_vkey: expected bytes")
        }
        let hotVKey = KESVerificationKey(payload: hotVKeyBytes, type: nil, description: nil)
        let sequenceNumber = try certElems[1].integer(
            "HeaderBody sequence_number", as: UInt64.self)
        let kesPeriod = try certElems[2].integer("HeaderBody kes_period", as: UInt64.self)
        guard case .bytes(let sigma) = certElems[3] else {
            throw CardanoCoreError.deserializeError("Invalid HeaderBody sigma: expected bytes")
        }
        self.operationalCert = try OperationalCertificate(
            hotVKey: hotVKey,
            sequenceNumber: sequenceNumber,
            kesPeriod: kesPeriod,
            sigma: sigma
        )

        let major = try Self.versionNumber(pvElems[0], "HeaderBody protocol major")
        let minor = try Self.versionNumber(pvElems[1], "HeaderBody protocol minor")
        self.protocolVersion = ProtocolVersion(major: major, minor: minor)
    }

    /// A protocol version number: a `uint` on the wire, held as a non-negative `Int`.
    private static func versionNumber(_ primitive: Primitive, _ what: String) throws -> Int {
        let value = try primitive.integer(what, as: UInt64.self)
        guard let number = Int(exactly: value) else {
            throw CardanoCoreError.deserializeError("\(what): \(value) is out of range for Int")
        }
        return number
    }

    /// The layout of the era: 15 flat elements with a ``nonceVrf``
    /// (Shelley to Alonzo), 10 with the operational certificate and protocol
    /// version nested without one (Babbage and Conway).
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
        }
        fields += [
            try vrfResult.toPrimitive(),
            .uint(UInt64(blockBodySize)),
            blockBodyHash.toPrimitive(),
        ]

        let operationalCert: [Primitive] = [
            .bytes(operationalCert.hotVKey.payload),
            .uint(UInt64(operationalCert.sequenceNumber)),
            .uint(UInt64(operationalCert.kesPeriod)),
            .bytes(operationalCert.sigma),
        ]
        let protocolVersion: [Primitive] = [
            .integer(protocolVersion.major ?? 0),
            .integer(protocolVersion.minor ?? 0),
        ]
        if nonceVrf != nil {
            fields += operationalCert + protocolVersion
        } else {
            fields += [.list(operationalCert), .list(protocolVersion)]
        }

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
        let blockNumber = try blockNumberPrimitive.integer(
            "HeaderBody blockNumber", as: BlockNumber.self)

        guard let slotPrimitive = dict[.string(CodingKeys.slot.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing slot in HeaderBody")
        }
        let slot = try slotPrimitive.integer("HeaderBody slot", as: SlotNumber.self)

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
        let blockBodySize = try blockBodySizePrimitive.integer(
            "HeaderBody blockBodySize", as: UInt32.self)

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
    
    /// The Blake2b-256 hash of this header body's encoding.
    ///
    /// - Throws: When it cannot be encoded.
    public func hash() throws -> Data {
        return try Hash().blake2b(
            data: try self.toCBORData(),
            digestSize: BLOCK_HEADER_HASH_SIZE,
            encoder: RawEncoder.self
        )
    }
}
