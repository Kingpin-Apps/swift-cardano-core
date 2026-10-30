import Foundation
import OrderedCollections

/// MultiHostName structure representing a multi-host name with DNS name.
public struct MultiHostName: Serializable, Sendable {
    public static var code: Int { get { return 2 } }
    public let dnsName: String?
    
    /// - Throws: When `dnsName` is longer than
    ///   ``SingleHostName/maxDnsNameSize`` bytes of UTF-8.
    public init(dnsName: String?) throws {
        self.dnsName = try SingleHostName.checkedDnsName(dnsName)
    }

    // Codable is the `Serializable` default: CBOR through `toPrimitive()`
    // and `init(from: Primitive)`, so `toCBORData()` writes the CDDL's form.
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard let elements = primitive.arrayElements else {
            throw CardanoCoreError.deserializeError("Invalid MultiHostName primitive")
        }
        // multi_host_name = (2, dns_name)
        guard elements.count == 2 else {
            throw CardanoCoreError.deserializeError("MultiHostName requires 2 elements, got \(elements.count)")
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
                    self.dnsName = try SingleHostName.checkedDnsName(dnsNameValue)
                default:
                    // dns_name is text: it has no null.
                    throw CardanoCoreError.deserializeError("Invalid dnsName value in MultiHostName")
            }
        } else {
            self.dnsName = nil
        }
    }
    
    public func toPrimitive() throws -> Primitive {
        var elements: [Primitive] = []
        elements.append(.uint(UInt64(Self.code)))
        
        // dns_name is text, which has no null.
        guard let dnsName = self.dnsName else {
            throw CardanoCoreError.serializeError("MultiHostName requires a dnsName")
        }
        elements.append(.string(dnsName))
        
        return .list(elements)
        
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> MultiHostName {
        guard case let .orderedDict(dictValue) = dict,
              try dictValue[.string("type")]?.integer("MultiHostName type", as: Int.self) == Self.code else {
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
        
        return try MultiHostName(dnsName: dnsName)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .uint(UInt64(Self.code))
        if let dnsName = self.dnsName {
            dict[.string("dnsName")] = .string(dnsName)
        } else {
            dict[.string("dnsName")] = .null
        }
        return .orderedDict(dict)
    }
}
