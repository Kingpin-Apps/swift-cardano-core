import Foundation
import OrderedCollections
import CBORCodable

/// A Byron era block — either an Epoch Boundary Block or a regular BFT block.
///
/// Byron uses a completely different CDDL from Shelley+. Two variants exist:
///
/// **EBB (Epoch Boundary Block)** — marks the transition between epochs, no transactions:
/// ```
/// ebb_head = [protocolMagic, prevBlock, bodyProof, consensusData]
///   consensusData = [epoch : uint, chainDifficulty : [uint]]
/// ```
///
/// **BFT (Byzantine Fault Tolerant) block** — regular block with transactions:
/// ```
/// blockhead = [protocolMagic, prevBlock, bodyProof, consensusData, extraData]
///   consensusData = [slotId, issuer, chainDifficulty, signature]
///   slotId        = [epoch : uint, slotWithinEpoch : uint]
///   issuer        = bytes .size 64   ; extended Ed25519 verification key
///   chainDifficulty = [uint]
///   extraData     = [blockVersion, softwareVersion, attributes, extraProof]
///   blockVersion  = [major : uint, minor : uint, alt : uint]
///   softwareVersion = [appName : text, number : uint]
/// ```
public enum ByronBlock: Sendable {
    case ebb(EBB)
    case bft(BFT)

    // MARK: - EBB

    /// Epoch Boundary Block — marks transitions between Byron epochs.
    /// EBBs carry no transactions; their body is empty.
    public struct EBB: Sendable {
        /// Network protocol magic.
        public let protocolMagic: UInt32
        /// Hash of the previous block header. `nil` at the genesis EBB.
        public let prevHash: Data?
        /// Epoch number.
        public let epoch: UInt64
        /// Chain difficulty, equal to the block height at this point.
        public let difficulty: UInt64

        public init(
            protocolMagic: UInt32,
            prevHash: Data?,
            epoch: UInt64,
            difficulty: UInt64
        ) {
            self.protocolMagic = protocolMagic
            self.prevHash = prevHash
            self.epoch = epoch
            self.difficulty = difficulty
        }
    }

    // MARK: - BFT

    /// Regular Byron BFT (Byzantine Fault Tolerant) block.
    public struct BFT: Sendable {
        /// Network protocol magic.
        public let protocolMagic: UInt32
        /// Hash of the previous block header. `nil` at genesis.
        public let prevHash: Data?
        /// Epoch number from the block's `slotId`.
        public let epoch: UInt64
        /// Slot within the epoch from the block's `slotId`.
        public let slotWithinEpoch: UInt64
        /// Absolute slot number.
        /// Populated from the NtN protocol framing (`[[1, absoluteSlot], ...]`).
        /// `nil` when decoded from an NtC full block — computing it requires the
        /// genesis epoch length which is not encoded in the block itself.
        public let absoluteSlot: UInt64?
        /// 64-byte extended Ed25519 block issuer (delegate) verification key.
        public let issuerVKey: Data
        /// Chain difficulty, equal to the block height at this point.
        public let difficulty: UInt64
        /// Byron protocol version from `extraData`.
        public let protocolVersion: ByronProtocolVersion
        /// Byron software version from `extraData`.
        public let softwareVersion: ByronSoftwareVersion
        /// Number of transactions in the block body.
        /// Zero when decoded from an NtN header (body not available over NtN).
        public let transactionCount: Int

        public init(
            protocolMagic: UInt32,
            prevHash: Data?,
            epoch: UInt64,
            slotWithinEpoch: UInt64,
            absoluteSlot: UInt64?,
            issuerVKey: Data,
            difficulty: UInt64,
            protocolVersion: ByronProtocolVersion,
            softwareVersion: ByronSoftwareVersion,
            transactionCount: Int
        ) {
            self.protocolMagic = protocolMagic
            self.prevHash = prevHash
            self.epoch = epoch
            self.slotWithinEpoch = slotWithinEpoch
            self.absoluteSlot = absoluteSlot
            self.issuerVKey = issuerVKey
            self.difficulty = difficulty
            self.protocolVersion = protocolVersion
            self.softwareVersion = softwareVersion
            self.transactionCount = transactionCount
        }
    }

    // MARK: - Supporting types

    /// Byron protocol version from the block's `extraData`.
    public struct ByronProtocolVersion: Sendable {
        public let major: UInt16
        public let minor: UInt16
        public let alt: UInt16

        public init(major: UInt16, minor: UInt16, alt: UInt16) {
            self.major = major
            self.minor = minor
            self.alt = alt
        }

        public static let zero = ByronProtocolVersion(major: 0, minor: 0, alt: 0)
    }

    /// Byron software version from the block's `extraData`.
    public struct ByronSoftwareVersion: Sendable {
        public let appName: String
        public let number: UInt32

        public init(appName: String, number: UInt32) {
            self.appName = appName
            self.number = number
        }

        public static let unknown = ByronSoftwareVersion(appName: "", number: 0)
    }

    // MARK: - Convenience accessors

    /// The previous block hash regardless of variant.
    public var prevHash: Data? {
        switch self {
        case .ebb(let e): return e.prevHash
        case .bft(let b): return b.prevHash
        }
    }

    /// Chain difficulty (block height) regardless of variant.
    public var difficulty: UInt64 {
        switch self {
        case .ebb(let e): return e.difficulty
        case .bft(let b): return b.difficulty
        }
    }
}

// MARK: - Equatable & Hashable

extension ByronBlock.ByronProtocolVersion: Equatable, Hashable {}
extension ByronBlock.ByronSoftwareVersion: Equatable, Hashable {}
extension ByronBlock.EBB: Equatable, Hashable {}
extension ByronBlock.BFT: Equatable, Hashable {}
extension ByronBlock: Equatable, Hashable {}

// MARK: - Serializable

extension ByronBlock: Serializable {

    // MARK: CBORSerializable

    /// Decode from the NtC wire format: `[discriminant, [head, body, extra]]`.
    public init(from primitive: Primitive) throws {
        guard case .list(let elements) = primitive, elements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock: expected [discriminant, block_content] 2-element array"
            )
        }
        let discriminant = try Self.uintFrom(elements[0])

        guard case .list(let blockElements) = elements[1], !blockElements.isEmpty,
            case .list(let headElements) = blockElements[0]
        else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock: block_content must be an array whose first element is the head array"
            )
        }

        if discriminant == 0 {
            // EBB
            guard headElements.count >= 5 else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlock EBB: head requires ≥5 elements, got \(headElements.count)"
                )
            }
            let protocolMagic = UInt32(try Self.uintFrom(headElements[0]))
            let prevHash = Self.bytesOrNil(headElements[1])
            guard case .list(let cons) = headElements[3], cons.count >= 2 else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlock EBB: consensusData must be [epoch, [difficulty]]"
                )
            }
            let epoch = try Self.uintFrom(cons[0])
            let difficulty = try Self.difficultyFrom(cons[1])
            self = .ebb(
                EBB(
                    protocolMagic: protocolMagic, prevHash: prevHash, epoch: epoch,
                    difficulty: difficulty))
        } else {
            // BFT
            guard headElements.count >= 5 else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlock BFT: head requires ≥5 elements, got \(headElements.count)"
                )
            }
            let txCount = blockElements.count >= 2 ? Self.txCountFrom(blockElements[1]) : 0
            let protocolMagic = UInt32(try Self.uintFrom(headElements[0]))
            let prevHash = Self.bytesOrNil(headElements[1])
            guard case .list(let cons) = headElements[3], cons.count >= 3 else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlock BFT: consensusData must have ≥3 elements"
                )
            }
            guard case .list(let slotEl) = cons[0], slotEl.count >= 2 else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlock BFT: slotId must be [epoch, slot]"
                )
            }
            let epoch = try Self.uintFrom(slotEl[0])
            let slotWithinEpoch = try Self.uintFrom(slotEl[1])
            guard case .bytes(let issuerVKey) = cons[1] else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlock BFT: issuer must be bytes"
                )
            }
            let difficulty = try Self.difficultyFrom(cons[2])

            var protocolVersion = ByronProtocolVersion.zero
            var softwareVersion = ByronSoftwareVersion.unknown
            if case .list(let extra) = headElements[4], extra.count >= 2 {
                if case .list(let bv) = extra[0], bv.count >= 3,
                    let maj = try? Self.uintFrom(bv[0]),
                    let min = try? Self.uintFrom(bv[1]),
                    let alt = try? Self.uintFrom(bv[2])
                {
                    protocolVersion = ByronProtocolVersion(
                        major: UInt16(maj), minor: UInt16(min), alt: UInt16(alt)
                    )
                }
                if case .list(let sv) = extra[1], sv.count >= 2,
                    case .string(let appName) = sv[0],
                    let num = try? Self.uintFrom(sv[1])
                {
                    softwareVersion = ByronSoftwareVersion(appName: appName, number: UInt32(num))
                }
            }

            self = .bft(
                BFT(
                    protocolMagic: protocolMagic,
                    prevHash: prevHash,
                    epoch: epoch,
                    slotWithinEpoch: slotWithinEpoch,
                    absoluteSlot: nil,
                    issuerVKey: issuerVKey,
                    difficulty: difficulty,
                    protocolVersion: protocolVersion,
                    softwareVersion: softwareVersion,
                    transactionCount: txCount
                ))
        }
    }

    /// Encode to the NtC wire format: `[discriminant, [head, [], []]]`.
    ///
    /// - Note: Fields not stored in the parsed structs (`bodyProof`, `signature`) are
    ///   represented as empty placeholders, so the resulting CBOR is not byte-identical
    ///   to the original wire data.
    public func toPrimitive() throws -> Primitive {
        switch self {
        case .ebb(let ebb):
            // ebbhead = [protocolMagic, prevBlock, bodyProof, [epoch, [difficulty]], []]
            let ebbhead: Primitive = .list([
                .uint(UInt64(ebb.protocolMagic)),
                ebb.prevHash.map { .bytes($0) } ?? .bytes(Data()),
                .bytes(Data()),  // bodyProof — not stored
                .list([
                    .uint(ebb.epoch),
                    .list([.uint(ebb.difficulty)]),
                ]),
                .list([]),  // extraData
            ])
            return .list([.uint(0), .list([ebbhead, .list([]), .list([])])])

        case .bft(let bft):
            // blockhead = [protocolMagic, prevBlock, bodyProof, consensusData, extraData]
            let blockhead: Primitive = .list([
                .uint(UInt64(bft.protocolMagic)),
                bft.prevHash.map { .bytes($0) } ?? .bytes(Data()),
                .bytes(Data()),  // bodyProof — not stored
                .list([
                    .list([.uint(bft.epoch), .uint(bft.slotWithinEpoch)]),
                    .bytes(bft.issuerVKey),
                    .list([.uint(bft.difficulty)]),
                    .list([.uint(0), .bytes(Data())]),  // signature placeholder
                ]),
                .list([
                    .list([
                        .uint(UInt64(bft.protocolVersion.major)),
                        .uint(UInt64(bft.protocolVersion.minor)),
                        .uint(UInt64(bft.protocolVersion.alt)),
                    ]),
                    .list([
                        .string(bft.softwareVersion.appName),
                        .uint(UInt64(bft.softwareVersion.number)),
                    ]),
                    .orderedDict([:]),  // attributes
                    .bytes(Data()),  // extraProof
                ]),
            ])
            return .list([.uint(1), .list([blockhead, .list([]), .list([])])])
        }
    }

    // MARK: JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> ByronBlock {
        guard case .orderedDict(let dict) = primitive else {
            throw CardanoCoreError.deserializeError("ByronBlock.fromDict: expected dict")
        }
        guard let typeP = dict[.string("type")], case .string(let type_) = typeP else {
            throw CardanoCoreError.deserializeError("ByronBlock.fromDict: missing 'type' field")
        }

        switch type_ {
        case "ebb":
            guard let pmP = dict[.string("protocolMagic")],
                let epochP = dict[.string("epoch")],
                let diffP = dict[.string("difficulty")]
            else {
                throw CardanoCoreError.deserializeError("ByronBlock EBB: missing required fields")
            }
            let protocolMagic = UInt32(try uintFrom(pmP))
            let prevHash: Data? = try hexDataOrNil(dict[.string("prevHash")])
            let epoch = try uintFrom(epochP)
            let difficulty = try uintFrom(diffP)
            return .ebb(
                EBB(
                    protocolMagic: protocolMagic, prevHash: prevHash, epoch: epoch,
                    difficulty: difficulty))

        case "bft":
            guard let pmP = dict[.string("protocolMagic")],
                let epochP = dict[.string("epoch")],
                let slotP = dict[.string("slotWithinEpoch")],
                let ivkP = dict[.string("issuerVKey")],
                let diffP = dict[.string("difficulty")]
            else {
                throw CardanoCoreError.deserializeError("ByronBlock BFT: missing required fields")
            }
            let protocolMagic = UInt32(try uintFrom(pmP))
            let prevHash: Data? = try hexDataOrNil(dict[.string("prevHash")])
            let epoch = try uintFrom(epochP)
            let slot = try uintFrom(slotP)
            let absoluteSlot: UInt64?
            if let asp = dict[.string("absoluteSlot")] {
                absoluteSlot = try? uintFrom(asp)
            } else {
                absoluteSlot = nil
            }
            guard case .string(let ivkHex) = ivkP,
                let issuerVKey = Data(hexString: ivkHex)
            else {
                throw CardanoCoreError.deserializeError(
                    "ByronBlock BFT: issuerVKey must be a hex string")
            }
            let difficulty = try uintFrom(diffP)

            var protocolVersion = ByronProtocolVersion.zero
            if let pvP = dict[.string("protocolVersion")],
                case .orderedDict(let pvDict) = pvP,
                let majP = pvDict[.string("major")],
                let minP = pvDict[.string("minor")],
                let altP = pvDict[.string("alt")]
            {
                protocolVersion = ByronProtocolVersion(
                    major: UInt16(try uintFrom(majP)),
                    minor: UInt16(try uintFrom(minP)),
                    alt: UInt16(try uintFrom(altP))
                )
            }

            var softwareVersion = ByronSoftwareVersion.unknown
            if let svP = dict[.string("softwareVersion")],
                case .orderedDict(let svDict) = svP,
                case .string(let appName) = svDict[.string("appName")],
                let numP = svDict[.string("number")]
            {
                softwareVersion = ByronSoftwareVersion(
                    appName: appName, number: UInt32(try uintFrom(numP))
                )
            }

            let txCount: Int
            if let tcp = dict[.string("transactionCount")] {
                txCount = Int(try uintFrom(tcp))
            } else {
                txCount = 0
            }

            return .bft(
                BFT(
                    protocolMagic: protocolMagic,
                    prevHash: prevHash,
                    epoch: epoch,
                    slotWithinEpoch: slot,
                    absoluteSlot: absoluteSlot,
                    issuerVKey: issuerVKey,
                    difficulty: difficulty,
                    protocolVersion: protocolVersion,
                    softwareVersion: softwareVersion,
                    transactionCount: txCount
                ))

        default:
            throw CardanoCoreError.deserializeError("ByronBlock.fromDict: unknown type '\(type_)'")
        }
    }

    public func toDict() throws -> Primitive {
        switch self {
        case .ebb(let ebb):
            var dict = OrderedDictionary<Primitive, Primitive>()
            dict[.string("type")] = .string("ebb")
            dict[.string("protocolMagic")] = .uint(UInt64(ebb.protocolMagic))
            dict[.string("prevHash")] = ebb.prevHash.map { .string($0.toHex) } ?? .null
            dict[.string("epoch")] = .uint(ebb.epoch)
            dict[.string("difficulty")] = .uint(ebb.difficulty)
            return .orderedDict(dict)

        case .bft(let bft):
            var dict = OrderedDictionary<Primitive, Primitive>()
            dict[.string("type")] = .string("bft")
            dict[.string("protocolMagic")] = .uint(UInt64(bft.protocolMagic))
            dict[.string("prevHash")] = bft.prevHash.map { .string($0.toHex) } ?? .null
            dict[.string("epoch")] = .uint(bft.epoch)
            dict[.string("slotWithinEpoch")] = .uint(bft.slotWithinEpoch)
            if let abs = bft.absoluteSlot {
                dict[.string("absoluteSlot")] = .uint(abs)
            }
            dict[.string("issuerVKey")] = .string(bft.issuerVKey.toHex)
            dict[.string("difficulty")] = .uint(bft.difficulty)

            var pvDict = OrderedDictionary<Primitive, Primitive>()
            pvDict[.string("major")] = .uint(UInt64(bft.protocolVersion.major))
            pvDict[.string("minor")] = .uint(UInt64(bft.protocolVersion.minor))
            pvDict[.string("alt")] = .uint(UInt64(bft.protocolVersion.alt))
            dict[.string("protocolVersion")] = .orderedDict(pvDict)

            var svDict = OrderedDictionary<Primitive, Primitive>()
            svDict[.string("appName")] = .string(bft.softwareVersion.appName)
            svDict[.string("number")] = .uint(UInt64(bft.softwareVersion.number))
            dict[.string("softwareVersion")] = .orderedDict(svDict)

            dict[.string("transactionCount")] = .uint(UInt64(bft.transactionCount))
            return .orderedDict(dict)
        }
    }

    // MARK: Private helpers

    private static func uintFrom(_ p: Primitive) throws -> UInt64 {
        switch p {
        case .uint(let v): return UInt64(v)
        case .int(let v): return UInt64(v)
        default:
            throw CardanoCoreError.deserializeError("ByronBlock: expected uint, got \(p)")
        }
    }

    private static func bytesOrNil(_ p: Primitive) -> Data? {
        guard case .bytes(let d) = p, !d.isEmpty else { return nil }
        return d
    }

    private static func difficultyFrom(_ p: Primitive) throws -> UInt64 {
        guard case .list(let elements) = p, let first = elements.first else {
            throw CardanoCoreError.deserializeError(
                "ByronBlock: chainDifficulty must be a single-element array [uint]"
            )
        }
        return try uintFrom(first)
    }

    private static func txCountFrom(_ bodyPrimitive: Primitive) -> Int {
        guard case .list(let bodyElements) = bodyPrimitive,
            let txPayload = bodyElements.first,
            case .list(let txs) = txPayload
        else { return 0 }
        return txs.count
    }

    private static func hexDataOrNil(_ p: Primitive?) throws -> Data? {
        guard let p = p else { return nil }
        switch p {
        case .null: return nil
        case .string(let hex): return Data(hexString: hex)
        default: return nil
        }
    }
}
