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
        // single_host_name = (1, port / nil, dns_name)
        guard elements.count == 3 else {
            throw CardanoCoreError.deserializeError("SingleHostName requires 3 elements, got \(elements.count)")
        }
        
        var iterator = elements.makeIterator()
        guard let codeElement = iterator.next(),
              case let .uint(code) = codeElement,
              code == UInt64(Self.code) else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostName type")
        }
        
        if let portElement = iterator.next() {
            switch portElement {
                case .null:
                    self.port = nil
                default:
                    // port = uint .size 2
                    self.port = Int(try portElement.integer("SingleHostName port", as: UInt16.self))
            }
        } else {
            self.port = nil
        }
        
        if let dnsNameElement = iterator.next() {
            switch dnsNameElement {
                case .string(let dnsNameValue):
                    self.dnsName = dnsNameValue
                default:
                    // dns_name is text: it has no null.
                    throw CardanoCoreError.deserializeError("Invalid dnsName value in SingleHostName")
            }
        } else {
            self.dnsName = nil
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.uint(UInt64(Self.code)))

        if let port = self.port {
            elements.append(.integer(port))
        } else {
            elements.append(.null)
        }
        
        // dns_name is text, which has no null.
        guard let dnsName = self.dnsName else {
            throw CardanoCoreError.serializeError("SingleHostName requires a dnsName")
        }
        elements.append(.string(dnsName))
        
        return .list(elements)
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> SingleHostName {
        guard case let .orderedDict(dictValue) = dict,
              let codePrimitive = dictValue[.string("code")],
              case let .uint(codeValue) = codePrimitive,
              codeValue == UInt64(Self.code) else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostName code")
        }
        
        var port: Int? = nil
        if let portPrimitive = dictValue[.string("port")] {
            switch portPrimitive {
                case .null:
                    port = nil
                default:
                    // port = uint .size 2
                    port = Int(try portPrimitive.integer("SingleHostName port", as: UInt16.self))
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
        dict[.string("code")] = .uint(UInt64(Self.code))
        if let port = self.port {
            dict[.string("port")] = .integer(port)
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
