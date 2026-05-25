import Foundation
import OrderedCollections

public struct BeforeScript: NativeScriptable {
    public static let TYPE = NativeScriptType.invalidBefore
    public let slot: SlotNumber

    public init (slot: SlotNumber) {
        self.slot = slot
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case let .list(primitive) = primitive,
                primitive.count == 2,
                case let .uint(code) = primitive[0],
                code == Self.TYPE.rawValue,
              case let .uint(slot) = primitive[1] else {
            throw CardanoCoreError.deserializeError("Invalid BeforeScript type")
        }
        self.slot = SlotNumber(slot)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([.uint(UInt64(Self.TYPE.rawValue)), .uint(slot)])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> BeforeScript {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.decodingError("Invalid BeforeScript dict format")
        }

        guard let slotPrimitive = dictValue[.string("slot")] else {
            throw CardanoCoreError.decodingError("Missing slot in BeforeScript")
        }

        let slot: SlotNumber
        switch slotPrimitive {
        case .int(let intValue):
            slot = SlotNumber(intValue)
        case .uint(let uintValue):
            slot = uintValue
        default:
            throw CardanoCoreError.decodingError("Invalid BeforeScript slot type: \(slotPrimitive)")
        }

        return BeforeScript(slot: slot)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .string(Self.TYPE.description())
        dict[.string("slot")] = .uint(slot)
        return .orderedDict(dict)
    }
}
