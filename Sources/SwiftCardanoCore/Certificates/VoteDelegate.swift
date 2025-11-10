import Foundation
import OrderedCollections
import PotentCBOR

/// Delegate stake to a `DRep`
public struct VoteDelegate: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { return VoteDelegate.TYPE }
    public var description: String { return VoteDelegate.DESCRIPTION }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.voteDelegate.rawValue }
    public static var CODE: CertificateCode { return .voteDelegate }

    public let stakeCredential: StakeCredential
    public let drep: DRep

    public enum CodingKeys: String, CodingKey {
        case stakeCredential
        case drep
    }

    /// Initialize a new `VoteDelegate` certificate
    /// - Parameters:
    ///   - stakeCredential: The stake credential
    ///   - drep: The DRep
    public init(stakeCredential: StakeCredential, drep: DRep) {
        self.stakeCredential = stakeCredential
        self.drep = drep

        self._payload = try! CBORSerialization.data(
            from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(stakeCredential).toCBOR,
                        try! CBOREncoder().encode(drep).toCBOR,
                    ]
                )
        )

        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }

    /// Initialize `VoteDelegate` certificate from payload, type, and description
    /// - Parameters:
    ///   - payload: The payload of the certificate
    ///   - type: The type of the certificate
    ///   - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION

        let cbor = try! CBORDecoder().decode(VoteDelegate.self, from: payload)

        self.stakeCredential = cbor.stakeCredential
        self.drep = cbor.drep
    }
    
    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case .list(let primitive) = primitive,
            primitive.count == 3,
            case .uint(let code) = primitive[0],
            code == Self.CODE.rawValue
        else {
            throw CardanoCoreError.deserializeError("Invalid VoteDelegate type: \(primitive)")
        }

        let stakeCredential = try StakeCredential(from: primitive[1])
        let drep = try DRep(from: primitive[2])

        self.init(stakeCredential: stakeCredential, drep: drep)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.CODE.rawValue)),
            try stakeCredential.toPrimitive(),
            try drep.toPrimitive(),
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws
        -> VoteDelegate
    {
        guard case let .orderedDict(dictValue) = dict,
              let stakeCredentialPrimitive = dictValue[.string(CodingKeys.stakeCredential.rawValue)],
              case .string(let stakeCredentialHex) = stakeCredentialPrimitive
        else {
            throw CardanoCoreError.deserializeError(
                "Invalid or missing stakeCredential in VoteDelegate dict")
        }

        let stakeCredentialData = Data(hex: stakeCredentialHex)
        let stakeCredential = try StakeCredential(from: .bytes(stakeCredentialData))

        guard case .string(let drepId) = dictValue[.string(CodingKeys.drep.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing drep in VoteDelegate dict")
        }

        let drep = try DRep(from: drepId)

        return VoteDelegate(stakeCredential: stakeCredential, drep: drep)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.stakeCredential.rawValue)] = .string(
            stakeCredential.credential.payload.toHex)
        dict[.string(CodingKeys.drep.rawValue)] = .string(try drep.id())
        return .orderedDict(dict)
    }
}
