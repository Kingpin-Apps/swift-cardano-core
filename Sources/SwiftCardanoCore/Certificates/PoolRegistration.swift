import Foundation
import PotentCBOR
import FractionNumber
import OrderedCollections

/// Stake Pool Registration Certificate
public struct PoolRegistration: CertificateSerializable {
    public var _payload: Data
    public var _type: String
    public var _description: String

    public var type: String { get { return PoolRegistration.TYPE } }
    public  var description: String { get { return PoolRegistration.DESCRIPTION } }

    public static var TYPE: String { CertificateType.conway.rawValue }
    public static var DESCRIPTION: String { CertificateDescription.poolRegistration.rawValue }
    public static var CODE: CertificateCode { get { return .poolRegistration } }
    
    public let poolParams: PoolParams
    
    public enum CodingKeys: String, CodingKey {
        case poolParams = "poolParams"
    }
    
    /// Initialize a new PoolRegistration certificate
    /// - Parameter poolParams: The pool parameters
    public init(poolParams: PoolParams) {
        self.poolParams = poolParams
        
        var cbor: [CBOR] = [CBOR(integerLiteral: Self.CODE.rawValue)]
        cbor.append(
            contentsOf: try! CBOREncoder().encode(poolParams).toCBOR.arrayValue!
        )
            
        self._payload =  try! CBORSerialization.data(from: .array(cbor))
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize a new PoolRegistration certificate from a payload
    /// - Parameters:
    ///   - payload: The payload
    ///   - type: The type
    ///   - description: The description
    public init(payload: Data, type: String?, description: String?) throws {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
        do {
            let primitives = try payload.toCBOR.toPrimitive()
            if case let .list(primitivesList) = primitives {
                let poolParamsElements = Array(primitivesList.dropFirst())
                self.poolParams = try PoolParams(from: .list(poolParamsElements))
            } else {
                throw CardanoCoreError.deserializeError("Failed to decode PoolRegistration from payload: Not a list.")
            }
        } catch {
            throw CardanoCoreError.deserializeError("Failed to decode PoolRegistration from payload: \(error)")
        }
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive, elements.count >= 1 else {
            throw CardanoCoreError.deserializeError("Invalid PoolRegistration primitive")
        }
        
        // Verify the certificate code
        guard case let .uint(code) = elements[0], code == Self.CODE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid PoolRegistration type")
        }
        
        // Handle pool params as list or as the rest of the elements in the main list
        let poolParams: PoolParams
        if elements.count == 2, case let .list(poolParamsElements) = elements[1] {
            // If pool params are in a single list element, use that list
            let poolParamsList: Primitive = .list(poolParamsElements)
            poolParams = try PoolParams(from: poolParamsList)
        } else if elements.count == 10 {
            let poolParamsElements = Array(elements.dropFirst())
            poolParams = try PoolParams(from: .list(poolParamsElements))
        } else {
            throw CardanoCoreError.deserializeError("Invalid PoolRegistration primitive structure")
        }
        
        self.init(poolParams: poolParams)
    }

    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.uint(UInt(Self.CODE.rawValue)))
        
        let poolParamList = try poolParams.toPrimitive()
        if case let .list(poolParamsElements) = poolParamList {
            elements.append(contentsOf: poolParamsElements)
        } else {
            throw CardanoCoreError.serializeError("PoolParams did not serialize to a list")
        }
        
        return .list(elements)
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
        
        return PoolRegistration(poolParams: poolParams)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.poolParams.rawValue)] = try self.poolParams.toDict()
        return .orderedDict(dict)
    }

}
