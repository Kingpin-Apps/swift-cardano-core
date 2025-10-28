import Foundation
import OrderedCollections
import PotentCBOR

public struct VoteRegisterDelegate: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { return VoteRegisterDelegate.TYPE }
    public var description: String { return VoteRegisterDelegate.DESCRIPTION }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.voteRegisterDelegate.rawValue }
    public static var CODE: CertificateCode { return .voteRegisterDelegate }

    public let stakeCredential: StakeCredential
    public let drep: DRep
    public let coin: Coin

    public enum CodingKeys: String, CodingKey {
        case stakeCredential
        case drep
        case coin
    }

    /// Initialize a new `VoteRegisterDelegate` certificate
    /// - Parameters:
    ///  - stakeCredential: The stake credential
    ///  - drep: The DRep
    ///  - coin: The coin
    public init(stakeCredential: StakeCredential, drep: DRep, coin: Coin) {
        self.stakeCredential = stakeCredential
        self.drep = drep
        self.coin = coin

        self._payload = try! CBORSerialization.data(
            from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(stakeCredential).toCBOR,
                        try! CBOREncoder().encode(drep).toCBOR,
                        try! CBOREncoder().encode(coin).toCBOR,
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }

    /// Initialize a new `VoteRegisterDelegate` certificate from its Text Envelope representation
    /// - Parameters:
    ///  - payload: The CBOR representation of the certificate
    ///  - type: The type of the certificate
    ///  - description: The description of the certificate
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION

        let cbor = try! CBORDecoder().decode(VoteRegisterDelegate.self, from: payload)

        self.stakeCredential = cbor.stakeCredential
        self.drep = cbor.drep
        self.coin = cbor.coin
    }
    
    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case .list(let primitive) = primitive,
            primitive.count == 4,
            case .uint(let code) = primitive[0],
            case .uint(let coin) = primitive[3],
            code == Self.CODE.rawValue
        else {
            throw CardanoCoreError.deserializeError("Invalid VoteRegisterDelegate type")
        }

        let stakeCredential = try StakeCredential(from: primitive[1])
        let drep = try DRep(from: primitive[2])

        self.init(stakeCredential: stakeCredential, drep: drep, coin: Coin(coin))
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt(Self.CODE.rawValue)),
            try stakeCredential.toPrimitive(),
            try drep.toPrimitive(),
            .int(Int(coin)),
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws
        -> VoteRegisterDelegate
    {
        guard case let .orderedDict(dictValue) = dict,
              let stakeCredentialPrimitive = dictValue[.string(CodingKeys.stakeCredential.rawValue)],
              case .string(let stakeCredentialHex) = stakeCredentialPrimitive
        else {
            throw CardanoCoreError.deserializeError(
                "Invalid or missing stakeCredential in VoteRegisterDelegate dict")
        }

        let stakeCredentialData = Data(hex: stakeCredentialHex)
        let stakeCredential = try StakeCredential(from: .bytes(stakeCredentialData))

        guard case .string(let drepId) = dictValue[.string(CodingKeys.drep.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing drep in VoteRegisterDelegate dict")
        }

        let drep = try DRep(from: drepId)

        guard let coinPrimitive = dictValue[.string(CodingKeys.coin.rawValue)],
            case .int(let coinValue) = coinPrimitive
        else {
            throw CardanoCoreError.deserializeError(
                "Invalid or missing coin in VoteRegisterDelegate dict")
        }
        let coin = Coin(coinValue)

        return VoteRegisterDelegate(
            stakeCredential: stakeCredential,
            drep: drep,
            coin: coin
        )
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.stakeCredential.rawValue)] = .string(
            stakeCredential.credential.payload.toHex)
        dict[.string(CodingKeys.drep.rawValue)] = .string(try drep.id())
        dict[.string(CodingKeys.coin.rawValue)] = .int(Int(coin))
        return .orderedDict(dict)
    }
}
