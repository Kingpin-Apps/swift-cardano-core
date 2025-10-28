import Foundation
import OrderedCollections

/// Represents a single host address with optional port, IPv4, and IPv6 addresses.
public struct SingleHostAddr: Serializable, Sendable {
    public static var code: Int { get { return 0 } }
    
    public let port: Int?
    public let ipv4: IPv4Address?
    public let ipv6: IPv6Address?
    
    public init(port: Int?, ipv4: IPv4Address?, ipv6: IPv6Address?) {
        self.port = port
        self.ipv4 = ipv4
        self.ipv6 = ipv6
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostAddr primitive")
        }
        var iterator = elements.makeIterator()
        guard let codeElement = iterator.next(),
              case let .uint(code) = codeElement,
              code == Self.code else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostAddr type")
        }
        
        if let portElement = iterator.next() {
            switch portElement {
                case .uint(let portValue):
                    self.port = Int(portValue)
                case .null:
                    self.port = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid port value in SingleHostAddr")
            }
        } else {
            self.port = nil
        }
        
        if let ipv4Element = iterator.next() {
            switch ipv4Element {
                case .bytes(let ipv4Data):
                    if ipv4Data.count == 4 {
                        self.ipv4 = try IPv4Address(ipv4Data)
                    } else {
                        throw CardanoCoreError.deserializeError("Invalid IPv4 address length in SingleHostAddr")
                    }
                case .null:
                    self.ipv4 = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid ipv4 value in SingleHostAddr")
            }
        } else {
            self.ipv4 = nil
        }
        
        if let ipv6Element = iterator.next() {
            switch ipv6Element {
                case .bytes(let ipv6Data):
                    if ipv6Data.count == 16 {
                        self.ipv6 = try IPv6Address(ipv6Data)
                    } else {
                        throw CardanoCoreError.deserializeError("Invalid IPv6 address length in SingleHostAddr")
                    }
                case .null:
                    self.ipv6 = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid ipv6 value in SingleHostAddr")
            }
        } else {
            self.ipv6 = nil
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
        
        if let ipv4 = self.ipv4 {
            elements.append(.bytes(ipv4.rawValue))
        } else {
            elements.append(.null)
        }
        
        if let ipv6 = self.ipv6 {
            elements.append(.bytes(ipv6.rawValue))
        } else {
            elements.append(.null)
        }
        
        return .list(elements)
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> SingleHostAddr {
        guard case let .orderedDict(dictValue) = dict,
              let codePrimitive = dictValue[.uint(UInt(0))],
              case let .uint(code) = codePrimitive,
              code == Self.code else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostAddr type in dict")
        }
        
        var port: Int? = nil
        if let portPrimitive = dictValue[.uint(UInt(1))] {
            switch portPrimitive {
                case .uint(let portValue):
                    port = Int(portValue)
                case .null:
                    port = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid port value in SingleHostAddr dict")
            }
        }
        
        var ipv4: IPv4Address? = nil
        if let ipv4Primitive = dictValue[.uint(UInt(2))] {
            switch ipv4Primitive {
                case .bytes(let ipv4Data):
                    if ipv4Data.count == 4 {
                        ipv4 = try IPv4Address(ipv4Data)
                    } else {
                        throw CardanoCoreError.deserializeError("Invalid IPv4 address length in SingleHostAddr dict")
                    }
                case .null:
                    ipv4 = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid ipv4 value in SingleHostAddr dict")
            }
        }
        
        var ipv6: IPv6Address? = nil
        if let ipv6Primitive = dictValue[.uint(UInt(3))] {
            switch ipv6Primitive {
                case .bytes(let ipv6Data):
                    if ipv6Data.count == 16 {
                        ipv6 = try IPv6Address(ipv6Data)
                    } else {
                        throw CardanoCoreError.deserializeError("Invalid IPv6 address length in SingleHostAddr dict")
                    }
                case .null:
                    ipv6 = nil
                default:
                    throw CardanoCoreError.deserializeError("Invalid ipv6 value in SingleHostAddr dict")
            }
        }
        
        return SingleHostAddr(port: port, ipv4: ipv4, ipv6: ipv6)
    }
    
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.uint(UInt(0))] = .uint(UInt(Self.code))
        if let port = self.port {
            dict[.uint(UInt(1))] = .uint(UInt(port))
        } else {
            dict[.uint(UInt(1))] = .null
        }
        if let ipv4 = self.ipv4 {
            dict[.uint(UInt(2))] = .bytes(ipv4.rawValue)
        } else {
            dict[.uint(UInt(2))] = .null
        }
        if let ipv6 = self.ipv6 {
            dict[.uint(UInt(3))] = .bytes(ipv6.rawValue)
        } else {
            dict[.uint(UInt(3))] = .null
        }
        return .orderedDict(dict)
    }
    
}

