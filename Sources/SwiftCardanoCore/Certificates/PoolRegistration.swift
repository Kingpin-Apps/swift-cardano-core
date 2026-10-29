import Foundation
import CBORCodable
import FractionNumber
import OrderedCollections

/// Stake Pool Registration Certificate
public struct PoolRegistration: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { get { return PoolRegistration.TYPE } }
    public var description: String { get { return PoolRegistration.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.poolRegistration.rawValue }
    public static var CODE: CertificateCode { get { return .poolRegistration } }
    
    public let poolParams: PoolParams
    
    public enum CodingKeys: String, CodingKey {
        case poolParams = "poolParams"
    }
    
    /// Initialize a new PoolRegistration certificate
    /// - Parameter poolParams: The pool parameters
    /// - Throws: When the pool parameters cannot be encoded for the payload.
    public init(poolParams: PoolParams) throws {
        self.poolParams = poolParams
        self._payload = Data()
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
        self._payload = try encodedPayload()
    }

    /// Initialize a new PoolRegistration certificate from a payload
    /// - Parameters:
    ///   - payload: The payload
    ///   - type: The type
    ///   - description: The description
    public init(payload: Data, type: String?, description: String?) throws {
        let decoded = try CBORDecoder().decode(Self.self, from: payload)
        self = decoded
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
    }

    // MARK: - CBORSerializable

    /// `pool_registration_cert = (3, pool_params)`: `pool_params` is a group,
    /// so its nine fields follow the code in the same array.
    public init(from primitive: Primitive) throws {
        let fields = try Self.certificateFields(primitive, count: 10)
        try self.init(poolParams: try PoolParams(from: .list(fields)))
    }

    public func toPrimitive() throws -> Primitive {
        guard case let .list(poolParamsElements) = try poolParams.toPrimitive() else {
            throw CardanoCoreError.serializeError("PoolParams did not serialize to a list")
        }
        return .list([Self.codePrimitive] + poolParamsElements)
    }

    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> PoolRegistration {
        guard case let .orderedDict(orderedDict) = dict else {
            throw CardanoCoreError.deserializeError("Invalid PoolRegistration dict format")
        }
        guard case let .orderedDict(poolParamsPrimitive) = orderedDict[.string(CodingKeys.poolParams.rawValue)] else {
            throw CardanoCoreError.deserializeError("Missing poolParams in PoolRegistration dict")
        }
        
        let poolParams = try PoolParams.fromDict(.orderedDict(poolParamsPrimitive))
        
        return try PoolRegistration(poolParams: poolParams)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.poolParams.rawValue)] = try self.poolParams.toDict()
        return .orderedDict(dict)
    }

}
