import Foundation
import CBORCodable
import OrderedCollections

/// Vote delegation certificate: `delegation_to_drep_cert = (9, stake_credential, drep)`.
public struct VoteDelegate: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { VoteDelegate.TYPE }
    public var description: String { VoteDelegate.DESCRIPTION }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.voteDelegate.rawValue }
    public static var CODE: CertificateCode { .voteDelegate }

    public let stakeCredential: StakeCredential
    public let drep: DRep

    public enum CodingKeys: String, CodingKey {
        case stakeCredential
        case drep
    }

    /// Creates the certificate.
    ///
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(stakeCredential: StakeCredential, drep: DRep) throws {
        self.stakeCredential = stakeCredential
        self.drep = drep
        self._payload = Data()
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
        self._payload = try encodedPayload()
    }

    /// Initialize the certificate from its text-envelope payload.
    /// - Parameters:
    ///   - payload: The CBOR of the certificate
    ///   - type: The text-envelope type
    ///   - description: The text-envelope description
    public init(payload: Data, type: String?, description: String?) throws {
        let decoded = try CBORDecoder().decode(Self.self, from: payload)
        self = decoded
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        let fields = try Self.certificateFields(primitive, count: 3)
        try self.init(
            stakeCredential: try StakeCredential(from: fields[0]),
            drep: try DRep(from: fields[1])
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            try stakeCredential.toPrimitive(),
            try drep.toPrimitive()
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> VoteDelegate {
        return try VoteDelegate(
            stakeCredential: try StakeCredential.fromCertificateDict(try dictField(dict, CodingKeys.stakeCredential.rawValue, in: "VoteDelegate")),
            drep: try DRep(from: try dictString(dict, CodingKeys.drep.rawValue, in: "VoteDelegate"))
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.stakeCredential.rawValue)] = stakeCredential.certificateDict()
        dict[.string(CodingKeys.drep.rawValue)] = .string(try drep.id((.bech32, .cip129)))
        return .orderedDict(dict)
    }
}
