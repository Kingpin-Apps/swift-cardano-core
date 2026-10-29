import Foundation
import CBORCodable
import OrderedCollections

/// Stake registration and vote delegation: `account_registration_delegation_to_drep_cert = (12, stake_credential, drep, coin)`.
public struct VoteRegisterDelegate: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { VoteRegisterDelegate.TYPE }
    public var description: String { VoteRegisterDelegate.DESCRIPTION }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.voteRegisterDelegate.rawValue }
    public static var CODE: CertificateCode { .voteRegisterDelegate }

    public let stakeCredential: StakeCredential
    public let drep: DRep
    public let coin: Coin

    public enum CodingKeys: String, CodingKey {
        case stakeCredential
        case drep
        case coin
    }

    /// Creates the certificate.
    ///
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(stakeCredential: StakeCredential, drep: DRep, coin: Coin) throws {
        self.stakeCredential = stakeCredential
        self.drep = drep
        self.coin = coin
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
        let fields = try Self.certificateFields(primitive, count: 4)
        try self.init(
            stakeCredential: try StakeCredential(from: fields[0]),
            drep: try DRep(from: fields[1]),
            coin: try fields[2].integer("VoteRegisterDelegate coin", as: Coin.self)
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            try stakeCredential.toPrimitive(),
            try drep.toPrimitive(),
            .integer(coin)
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> VoteRegisterDelegate {
        return try VoteRegisterDelegate(
            stakeCredential: try StakeCredential.fromCertificateDict(try dictField(dict, CodingKeys.stakeCredential.rawValue, in: "VoteRegisterDelegate")),
            drep: try DRep(from: try dictString(dict, CodingKeys.drep.rawValue, in: "VoteRegisterDelegate")),
            coin: try dictField(dict, CodingKeys.coin.rawValue, in: "VoteRegisterDelegate").integer("VoteRegisterDelegate coin", as: Coin.self)
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.stakeCredential.rawValue)] = stakeCredential.certificateDict()
        dict[.string(CodingKeys.drep.rawValue)] = .string(try drep.id((.bech32, .cip129)))
        dict[.string(CodingKeys.coin.rawValue)] = .integer(coin)
        return .orderedDict(dict)
    }
}
