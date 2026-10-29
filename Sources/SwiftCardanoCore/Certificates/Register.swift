import Foundation
import CBORCodable
import OrderedCollections

/// Stake registration with a deposit: `account_registration_deposit_cert = (7, stake_credential, coin)`.
public struct Register: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { Register.TYPE }
    public var description: String { Register.DESCRIPTION }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.stakeRegistration.rawValue }
    public static var CODE: CertificateCode { .register }

    public let stakeCredential: StakeCredential
    public let coin: Coin

    public enum CodingKeys: String, CodingKey {
        case stakeCredential
        case coin
    }

    /// Creates the certificate.
    ///
    /// - Throws: When the certificate cannot be encoded for its payload.
    public init(stakeCredential: StakeCredential, coin: Coin) throws {
        self.stakeCredential = stakeCredential
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
        let decoded = try CBORDecoder.ledger().decode(Self.self, from: payload)
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
            coin: try fields[1].integer("Register coin", as: Coin.self)
        )
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            Self.codePrimitive,
            try stakeCredential.toPrimitive(),
            .integer(coin)
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> Register {
        return try Register(
            stakeCredential: try StakeCredential.fromCertificateDict(try dictField(dict, CodingKeys.stakeCredential.rawValue, in: "Register")),
            coin: try dictField(dict, CodingKeys.coin.rawValue, in: "Register").integer("Register coin", as: Coin.self)
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.stakeCredential.rawValue)] = stakeCredential.certificateDict()
        dict[.string(CodingKeys.coin.rawValue)] = .integer(coin)
        return .orderedDict(dict)
    }
}
