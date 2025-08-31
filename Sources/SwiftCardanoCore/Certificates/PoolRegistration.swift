import Foundation
import PotentCBOR
import FractionNumber

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
    
    /// Initialize a new PoolRegistration certificate
    /// - Parameter poolParams: The pool parameters
    public init(poolParams: PoolParams) {
        self.poolParams = poolParams
        
        self._payload =  try! CBORSerialization.data(from:
                .array(
                    [
                        CBOR(integerLiteral: Self.CODE.rawValue),
                        try! CBOREncoder().encode(poolParams).toCBOR
                    ]
                )
        )
        self._type = Self.TYPE
        self._description = Self.DESCRIPTION
    }
    
    /// Initialize a new PoolRegistration certificate from a payload
    /// - Parameters:
    ///   - payload: The payload
    ///   - type: The type
    ///   - description: The description
    public init(payload: Data, type: String?, description: String?) {
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? Self.DESCRIPTION
        
//        let cbor = try! CBORDecoder().decode(Self.self, from: payload)
        do {
            let cbor = try PoolRegistration(from: payload)
            self.poolParams = cbor.poolParams
        } catch {
            fatalError("Failed to decode PoolRegistration from payload: \(error)")
        }
    }
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive, elements.count >= 1 else {
            throw CardanoCoreError.deserializeError("Invalid PoolRegistration primitive")
        }
        
        // Verify the certificate code
        guard case let .int(code) = elements[0], code == Self.CODE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid PoolRegistration type")
        }
        
        // Extract the pool parameters elements
        let poolParamsElements = Array(elements.dropFirst())
        
        // Create a list primitive with just the pool parameters elements
        let poolParamsList: Primitive = .list(poolParamsElements)
        
        // Parse the pool parameters
        let poolParams = try PoolParams(from: poolParamsList)
        
        self.init(poolParams: poolParams)
    }

    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.int(Self.CODE.rawValue))
        
        let poolParamList = try poolParams.toPrimitive()
        if case let .list(poolParamsElements) = poolParamList {
            elements.append(contentsOf: poolParamsElements)
        } else {
            throw CardanoCoreError.serializeError("PoolParams did not serialize to a list")
        }
        
        return .list(elements)
    }

}
