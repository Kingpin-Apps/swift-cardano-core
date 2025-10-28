import Foundation
import OrderedCollections

/// MultiHostName structure representing a multi-host name with DNS name.
public struct MultiHostName: Serializable, Sendable {
    public static var code: Int { get { return 2 } }
    public let dnsName: String?
    
    public init(dnsName: String?) {
        self.dnsName = dnsName
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let code = try container.decode(Int.self)
        
        guard code == 2 else {
            throw CardanoCoreError.deserializeError("Invalid MultiHostName type: \(code)")
        }
        
        dnsName = try container.decodeIfPresent(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Self.code)
        try container.encode(dnsName)
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid MultiHostName primitive")
        }
        var iterator = elements.makeIterator()
        guard let codeElement = iterator.next(),
              case let .uint(code) = codeElement,
              code == Self.code else {
            throw CardanoCoreError.deserializeError("Invalid MultiHostName type")
        }
        if let dnsNameElement = iterator.next() {
            switch dnsNameElement {
                case .string(let dnsNameValue):
                    self.dnsName = dnsNameValue
                case .null:
                    self.dnsName = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid dnsName value in MultiHostName")
            }
        } else {
            self.dnsName = nil
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.uint(UInt(Self.code)))
        
        if let dnsName = self.dnsName {
            elements.append(.string(dnsName))
        } else {
            elements.append(.null)
        }
        
        return .list(elements)
        
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> MultiHostName {
        guard case let .orderedDict(dictValue) = dict,
              let typePrimitive = dictValue[.string("type")],
              case let .uint(typeValue) = typePrimitive,
              typeValue == UInt(Self.code) else {
            throw CardanoCoreError.deserializeError("Invalid MultiHostName type in dict")
        }
        
        let dnsNamePrimitive = dictValue[.string("dnsName")]
        let dnsName: String?
        
        if let dnsNamePrimitive = dnsNamePrimitive {
            switch dnsNamePrimitive {
                case .string(let dnsNameValue):
                    dnsName = dnsNameValue
                case .null:
                    dnsName = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid dnsName value in MultiHostName dict")
            }
        } else {
            dnsName = nil
        }
        
        return MultiHostName(dnsName: dnsName)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .uint(UInt(Self.code))
        if let dnsName = self.dnsName {
            dict[.string("dnsName")] = .string(dnsName)
        } else {
            dict[.string("dnsName")] = .null
        }
        return .orderedDict(dict)
    }
}
