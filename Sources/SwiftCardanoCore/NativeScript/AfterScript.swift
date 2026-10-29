import Foundation
import OrderedCollections

/// `invalid_hereafter` (code 5): valid only before `slot`. cardano-cli JSON type `"before"`.
public struct AfterScript: NativeScriptable {
    public static let TYPE = NativeScriptType.invalidHereAfter
    public let slot: SlotNumber

    /// The bytes this script was decoded from, when it was decoded on its
    /// own or as a whole script of a transaction; its encoding and hash are
    /// taken over them, as the ledger takes them, while they are kept.
    public internal(set) var originalCBOR: Data? = nil

    public init (slot: SlotNumber) {
        self.slot = slot
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard let primitiveArray = primitive.arrayElements, primitiveArray.count == 2 else {
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
        if let originalCBOR { return .cborSimpleValue(.encoded(originalCBOR)) }
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

        if let typePrimitive = dictValue[.string("type")] {
            guard case let .string(type) = typePrimitive, type == Self.TYPE.description() else {
                throw CardanoCoreError.decodingError("Invalid AfterScript type: \(typePrimitive)")
            }
        }

        guard let slotPrimitive = dictValue[.string("slot")] else {
            throw CardanoCoreError.decodingError("Missing slot in AfterScript")
        }

        let slot = try slotPrimitive.integer("AfterScript slot", as: SlotNumber.self)

        return AfterScript(slot: slot)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string("type")] = .string(Self.TYPE.description())
        dict[.string("slot")] = .uint(slot)
        return .orderedDict(dict)
    }

}

extension AfterScript {
    /// Equal when they are the same script, however each was written.
    public static func == (lhs: AfterScript, rhs: AfterScript) -> Bool {
        lhs.slot == rhs.slot
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(slot)
    }
}
