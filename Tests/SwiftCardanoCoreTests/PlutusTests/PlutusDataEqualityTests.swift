@preconcurrency import BigInt
import Foundation
import OrderedCollections
import Testing

@testable import SwiftCardanoCore

/// `PlutusData` equality has to follow the value, not whichever representation
/// the value happens to be held in. `PlutusData` is also used as a dictionary
/// key, so every pair that compares equal has to hash alike too.
@Suite("PlutusData value equality")
struct PlutusDataEqualityTests {

    private func expectSameValue(
        _ lhs: PlutusData,
        _ rhs: PlutusData,
        _ what: Comment,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(lhs == rhs, what, sourceLocation: sourceLocation)
        #expect(
            lhs.hashValue == rhs.hashValue,
            "\(what): equal values hash differently",
            sourceLocation: sourceLocation
        )
    }

    @Test("The representations that encode alike are held as separate cases")
    func representationsAreInterchangeable() throws {
        // Nothing below would be worth ignoring if these did not encode to the
        // same bytes, so the premise is checked rather than asserted.
        let raw = Data(repeating: 0xAB, count: 8)
        #expect(
            try PlutusData.bytes(.boundedBytes(BoundedBytes(bytes: raw))).toCBORHex()
                == PlutusData.bytes(.byteString(ByteString(bytes: raw))).toCBORHex()
        )
        #expect(
            try PlutusData.bigInt(.int(7)).toCBORHex()
                == PlutusData.bigInt(.bigUInt(BigUInt(7))).toCBORHex()
        )
        #expect(
            try PlutusData.bigInt(.int(-7)).toCBORHex()
                == PlutusData.bigInt(.bigNInt(BigInt(-7))).toCBORHex()
        )
    }

    /// An integer goes on the wire as a CBOR bignum only when it does not fit
    /// in 64 bits, so the case it is held in cannot decide the encoding.
    @Test(
        "An integer is written in the smallest form that holds it",
        arguments: [
            (BigInt(0), "00"),
            (BigInt(7), "07"),
            (BigInt(-7), "26"),
            (BigInt(Int64.max), "1b7fffffffffffffff"),
            (BigInt(Int64.min), "3b7fffffffffffffff"),
            (BigInt(UInt64.max), "1bffffffffffffffff"),
            // 2^70, and -2^70 as tag 3's -1 - n.
            (BigInt(1) << 70, "c249400000000000000000"),
            (-(BigInt(1) << 70), "c3493fffffffffffffffff"),
        ]
    )
    func integerEncoding(value: BigInt, expected: String) throws {
        let held: BigInteger = value.sign == .plus
            ? .bigUInt(value.magnitude)
            : .bigNInt(value)
        #expect(try PlutusData.bigInt(held).toCBORHex() == expected)

        let decoded = try PlutusData.fromCBORHex(expected)
        #expect(decoded == PlutusData.bigInt(held), "an integer survives the round trip")
        guard case .bigInt(let decodedInteger) = decoded else {
            Issue.record("expected an integer")
            return
        }
        #expect(decodedInteger.value == value)
    }

    @Test("A list is the same value whether it was written definite or indefinite")
    func listRepresentation() {
        let elements: [PlutusData] = [.bigInt(.int(1)), .bigInt(.int(2))]
        expectSameValue(
            .array(elements),
            .indefiniteArray(IndefiniteList(elements)),
            "a two-element list"
        )
        expectSameValue(.array([]), .indefiniteArray(IndefiniteList([])), "the empty list")
    }

    @Test("Bytes are the same value whether bounded or unbounded")
    func bytesRepresentation() throws {
        let raw = Data(repeating: 0xAB, count: 8)
        expectSameValue(
            .bytes(.boundedBytes(try BoundedBytes(bytes: raw))),
            .bytes(.byteString(ByteString(bytes: raw))),
            "eight bytes held two ways"
        )
        #expect(
            PlutusData.bytes(try Bytes(from: Data([0x01])))
                != PlutusData.bytes(try Bytes(from: Data([0x02])))
        )
    }

    @Test("Integers are compared by value across the small and big cases")
    func integerRepresentation() {
        expectSameValue(.bigInt(.int(7)), .bigInt(.bigUInt(BigUInt(7))), "a small positive integer")
        expectSameValue(.bigInt(.int(-7)), .bigInt(.bigNInt(BigInt(-7))), "a small negative integer")
        #expect(PlutusData.bigInt(.int(7)) != PlutusData.bigInt(.int(-7)))
        // `.bigNInt` holds the integer itself and not its magnitude. Negating
        // it on the way out — which is what the `intValue` accessor does —
        // would make -7 compare equal to 7.
        #expect(PlutusData.bigInt(.bigNInt(BigInt(-7))) != PlutusData.bigInt(.int(7)))
    }

    @Test("A constructor ignores how its fields were encoded")
    func constructorRepresentation() throws {
        let fields: [PlutusData] = [.bytes(try Bytes(from: Data([0x01])))]
        expectSameValue(
            .constructor(Constr(tag: 0, fields: fields, useIndefiniteList: true)),
            .constructor(Constr(tag: 0, fields: fields, useIndefiniteList: false)),
            "a constructor written both ways"
        )
        #expect(
            PlutusData.constructor(Constr(tag: 0, fields: fields))
                != PlutusData.constructor(Constr(tag: 1, fields: fields)),
            "constructors with different tags are different values"
        )
        #expect(
            PlutusData.constructor(Constr(tag: 0, fields: fields))
                != PlutusData.constructor(Constr(tag: 0, fields: [])),
            "constructors with different fields are different values"
        )
    }

    @Test("Nesting is compared all the way down")
    func nestedRepresentation() throws {
        let raw = Data(repeating: 0x2C, count: 4)
        let asDecoded = PlutusData.constructor(
            Constr(tag: 1, fields: [
                .array([.bytes(.boundedBytes(try BoundedBytes(bytes: raw)))])
            ])
        )
        let asRebuilt = PlutusData.constructor(
            Constr(tag: 1, fields: [
                .indefiniteArray(IndefiniteList([.bytes(.byteString(ByteString(bytes: raw)))]))
            ])
        )
        expectSameValue(asDecoded, asRebuilt, "a constructor around a list of bytes")
    }

    @Test("A map keeps its order, because a Plutus map is a list of pairs")
    func mapOrder() {
        let pairs = PlutusData.map(OrderedDictionary(uniqueKeysWithValues: [
            (PlutusData.bigInt(.int(1)), PlutusData.bigInt(.int(10))),
            (PlutusData.bigInt(.int(2)), PlutusData.bigInt(.int(20))),
        ]))
        let sameHeldDifferently = PlutusData.map(OrderedDictionary(uniqueKeysWithValues: [
            (PlutusData.bigInt(.bigUInt(BigUInt(1))), PlutusData.bigInt(.int(10))),
            (PlutusData.bigInt(.int(2)), PlutusData.bigInt(.bigUInt(BigUInt(20)))),
        ]))
        expectSameValue(pairs, sameHeldDifferently, "the same pairs in the same order")

        let reordered = PlutusData.map(OrderedDictionary(uniqueKeysWithValues: [
            (PlutusData.bigInt(.int(2)), PlutusData.bigInt(.int(20))),
            (PlutusData.bigInt(.int(1)), PlutusData.bigInt(.int(10))),
        ]))
        #expect(pairs != reordered)
    }

    @Test("Values of different shapes stay unequal")
    func differentShapes() throws {
        let bytes = PlutusData.bytes(try Bytes(from: Data([0x00])))
        let integer = PlutusData.bigInt(.int(0))
        let list = PlutusData.array([integer])
        let constructor = PlutusData.constructor(Constr(tag: 0, fields: [integer]))
        let map = PlutusData.map(OrderedDictionary(uniqueKeysWithValues: [(integer, integer)]))
        #expect(bytes != integer)
        #expect(list != constructor)
        #expect(list != integer)
        #expect(map != list)
    }

    @Test("A value equals the one it was encoded from")
    func roundTrip() throws {
        let original = PlutusData.constructor(
            Constr(tag: 2, fields: [
                .bigInt(.int(-42)),
                .bytes(try Bytes(from: Data(repeating: 0x7F, count: 70))),
                .array([]),
                .map(OrderedDictionary(uniqueKeysWithValues: [
                    (PlutusData.bytes(try Bytes(from: Data([0x01]))), PlutusData.bigInt(.int(1)))
                ])),
            ])
        )
        let decoded = try PlutusData.fromCBOR(data: try original.toCBORData())
        expectSameValue(decoded, original, "a value round-tripped through CBOR")
    }

    @Test("Keys that describe the same data land in the same slot of a map")
    func dictionaryKeys() throws {
        var map = OrderedDictionary<PlutusData, PlutusData>()
        map[.bigInt(.int(1))] = .bytes(try Bytes(from: Data([0xAA])))
        map[.bigInt(.bigUInt(BigUInt(1)))] = .bytes(try Bytes(from: Data([0xBB])))
        #expect(map.count == 1, "the two keys are the same key on chain")
        #expect(map[.bigInt(.int(1))] == .bytes(try Bytes(from: Data([0xBB]))))
    }
}
