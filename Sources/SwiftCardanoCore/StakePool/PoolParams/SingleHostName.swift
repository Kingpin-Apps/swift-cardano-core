import Foundation
import OrderedCollections

/// Represents a single host name with optional port and DNS name.
public struct SingleHostName: Serializable, Sendable {
    public static var code: Int { get { return 1 } }
    
    public let port: Int?
    public let dnsName: String?
    
    public init(port: Int?, dnsName: String?) {
        self.port = port
        self.dnsName = dnsName
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostName primitive")
        }
        
        var iterator = elements.makeIterator()
        guard let codeElement = iterator.next(),
              case let .uint(code) = codeElement,
              code == Self.code else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostName type")
        }
        
        if let portElement = iterator.next() {
            switch portElement {
                case .uint(let portValue):
                    self.port = Int(portValue)
                case .null:
                    self.port = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid port value in SingleHostName")
            }
        } else {
            self.port = nil
        }
        
        if let dnsNameElement = iterator.next() {
            switch dnsNameElement {
                case .string(let dnsNameValue):
                    self.dnsName = dnsNameValue
                case .null:
                    self.dnsName = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid dnsName value in SingleHostName")
            }
        } else {
            self.dnsName = nil
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.uint(UInt(Self.code)))
        
        if let port = self.port {
            elements.append(.uint(UInt(port)))
        } else {
            elements.append(.null)
        }
        
        if let dnsName = self.dnsName {
            elements.append(.string(dnsName))
        } else {
            elements.append(.null)
        }
        
        return .list(elements)
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> SingleHostName {
        guard case let .orderedDict(dictValue) = dict,
              let codePrimitive = dictValue[.string("code")],
              case let .uint(codeValue) = codePrimitive,
              codeValue == UInt(Self.code) else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostName code")
        }
        
        var port: Int? = nil
        if let portPrimitive = dictValue[.string("port")] {
            switch portPrimitive {
                case .uint(let portValue):
                    port = Int(portValue)
                case .null:
                    port = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid port value in SingleHostName")
            }
        }
        
        var dnsName: String? = nil
        if let dnsNamePrimitive = dictValue[.string("dnsName")] {
            switch dnsNamePrimitive {
                case .string(let dnsNameValue):
                    dnsName = dnsNameValue
                case .null:
                    dnsName = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid dnsName value in SingleHostName")
            }
        }
        
        return SingleHostName(port: port, dnsName: dnsName)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("code")] = .uint(UInt(Self.code))
        if let port = self.port {
            dict[.string("port")] = .uint(UInt(port))
        } else {
            dict[.string("port")] = .null
        }
        if let dnsName = self.dnsName {
            dict[.string("dnsName")] = .string(dnsName)
        } else {
            dict[.string("dnsName")] = .null
        }
        return .orderedDict(dict)
    }
    

}
