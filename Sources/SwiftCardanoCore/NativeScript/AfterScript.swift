import Foundation
import OrderedCollections

public struct AfterScript: NativeScriptable {
    public static let TYPE = NativeScriptType.invalidHereAfter
    public let slot: SlotNumber

    public init (slot: SlotNumber) {
        self.slot = slot
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case let .list(primitiveArray) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid AfterScript type: \(primitive)")
        }

        guard case let .uint(code) = primitiveArray[0],
              code == Self.TYPE.rawValue else {
            throw CardanoCoreError.deserializeError("Invalid AfterScript type: \(primitiveArray[0])")
            }

        guard case let .uint(slot) = primitiveArray[1] else {
            throw CardanoCoreError.deserializeError("Invalid AfterScript slot: \(primitiveArray[1])")
        }

        self.slot = SlotNumber(slot)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(UInt64(Self.TYPE.rawValue)),
            .uint(slot)
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ dict: Primitive) throws -> AfterScript {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.decodingError("Invalid AfterScript dict format")
        }

        guard let slotPrimitive = dictValue[.string("slot")] else {
            throw CardanoCoreError.decodingError("Missing slot in AfterScript")
        }

        let slot: SlotNumber
        switch slotPrimitive {
        case .int(let intValue):
            slot = SlotNumber(intValue)
        case .uint(let uintValue):
            slot = uintValue
        default:
            throw CardanoCoreError.decodingError("Invalid AfterScript slot type: \(slotPrimitive)")
        }

        return AfterScript(slot: slot)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .string(Self.TYPE.description())
        dict[.string("slot")] = .uint(slot)
        return .orderedDict(dict)
    }

}
