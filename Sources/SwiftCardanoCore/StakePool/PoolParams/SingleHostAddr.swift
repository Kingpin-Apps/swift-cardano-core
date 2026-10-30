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
        guard let elements = primitive.arrayElements else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostAddr primitive")
        }
        // single_host_addr = (0, port / nil, ipv4 / nil, ipv6 / nil)
        guard elements.count == 4 else {
            throw CardanoCoreError.deserializeError("SingleHostAddr requires 4 elements, got \(elements.count)")
        }
        var iterator = elements.makeIterator()
        guard let codeElement = iterator.next(),
              case let .uint(code) = codeElement,
              code == Self.code else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostAddr type")
        }
        
        if let portElement = iterator.next() {
            switch portElement {
                case .null:
                    self.port = nil
                default:
                    // port = uint .size 2
                    self.port = Int(try portElement.integer("SingleHostAddr port", as: UInt16.self))
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
        elements.append(.uint(UInt64(Self.code)))

        if let port = self.port {
            elements.append(.integer(port))
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
    
    /// Reads ``toDict()``'s form.
    public static func fromDict(_ dict: Primitive) throws -> SingleHostAddr {
        guard case let .orderedDict(dictValue) = dict,
              try dictValue[.string("type")]?.integer("SingleHostAddr type", as: Int.self) == Self.code else {
            throw CardanoCoreError.deserializeError("Invalid SingleHostAddr type in dict")
        }
        func field(_ name: String) -> Primitive? {
            guard let value = dictValue[.string(name)], value != .null else { return nil }
            return value
        }
        // port = uint .size 2
        let port = try field("port").map { Int(try $0.integer("SingleHostAddr port", as: UInt16.self)) }
        let ipv4 = try field("ipv4").map { value -> IPv4Address in
            guard case .string(let text) = value, let address = IPv4Address(text) else {
                throw CardanoCoreError.deserializeError("Invalid ipv4 value in SingleHostAddr dict: \(value)")
            }
            return address
        }
        let ipv6 = try field("ipv6").map { value -> IPv6Address in
            guard case .string(let text) = value, let address = IPv6Address(text) else {
                throw CardanoCoreError.deserializeError("Invalid ipv6 value in SingleHostAddr dict: \(value)")
            }
            return address
        }
        return SingleHostAddr(port: port, ipv4: ipv4, ipv6: ipv6)
    }

    /// `{"type": 0, "port": …, "ipv4": "192.0.2.1", "ipv6": "2001:db8::1"}`,
    /// an absent field as `null`.
    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .integer(Self.code)
        dict[.string("port")] = port.map { .integer($0) } ?? .null
        dict[.string("ipv4")] = ipv4.map { .string($0.description) } ?? .null
        dict[.string("ipv6")] = ipv6.map { .string($0.description) } ?? .null
        return .orderedDict(dict)
    }
    
}

