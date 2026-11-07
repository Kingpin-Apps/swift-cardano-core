import Testing
import Foundation
import BigInt
import OrderedCollections

import CBORCodable
@testable import SwiftCardanoCore

// MARK: - Helpers

private final class ResultBox: @unchecked Sendable {
    var outcome: Result<Void, any Error> = .success(())
}

/// Runs `body` on a thread with a 512 KB stack, the size of a Swift
/// concurrency cooperative thread, or another size, and returns how it ended.
private func onSmallStack(
    stackSize: Int = 512 * 1024, _ body: @escaping @Sendable () throws -> Void
) -> Result<Void, any Error> {
    let box = ResultBox()
    let done = DispatchSemaphore(value: 0)
    let thread = Thread {
        do {
            try body()
            box.outcome = .success(())
        } catch {
            box.outcome = .failure(error)
        }
        done.signal()
    }
    thread.stackSize = stackSize
    thread.start()
    done.wait()
    return box.outcome
}

/// Expects `body` to throw a `CardanoCoreError` on a 512 KB stack.
private func expectThrowsOnSmallStack(
    _ body: @escaping @Sendable () throws -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    switch onSmallStack(body) {
    case .success:
        Issue.record("Expected a CardanoCoreError, but the decode succeeded", sourceLocation: sourceLocation)
    case .failure(let error):
        #expect(error is CardanoCoreError, "Unexpected error: \(error)", sourceLocation: sourceLocation)
    }
}

/// Expects `body` to succeed on a 512 KB stack.
private func expectSucceedsOnSmallStack(
    _ body: @escaping @Sendable () throws -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    if case .failure(let error) = onSmallStack(body) {
        Issue.record("Expected success, got \(error)", sourceLocation: sourceLocation)
    }
}

private func nestedPlutusList(_ depth: Int) -> String {
    String(repeating: "{\"list\":[", count: depth) + "{\"int\":1}" + String(repeating: "]}", count: depth)
}

private func nestedConstr(_ depth: Int) -> String {
    String(repeating: "{\"constructor\":0,\"fields\":[", count: depth) + "{\"int\":1}"
        + String(repeating: "]}", count: depth)
}

private func nestedArrays(_ depth: Int) -> String {
    String(repeating: "[", count: depth) + "1" + String(repeating: "]", count: depth)
}

private func nestedNativeScript(_ type: String, _ depth: Int) -> String {
    let open = type == "atLeast"
        ? "{\"type\":\"atLeast\",\"required\":1,\"scripts\":["
        : "{\"type\":\"\(type)\",\"scripts\":["
    return String(repeating: open, count: depth) + "{\"type\":\"after\",\"slot\":1}"
        + String(repeating: "]}", count: depth)
}

private func poolMetadataJSON(extraDepth: Int) -> String {
    "{\"name\":\"a\",\"description\":\"b\",\"ticker\":\"ABC\",\"homepage\":\"https://x.example\",\"x\":"
        + String(repeating: "[", count: extraDepth) + String(repeating: "]", count: extraDepth) + "}"
}

// MARK: - NaN map keys

@Suite struct AuditNaNMapKeyTests {
    /// A transaction whose metadata nests 40 levels (past the decoder's raw
    /// depth) under a map with a float32 NaN key and a double NaN key.
    static let nanTransaction = Data(
        hexString: "84a3008001800200a0f5a100a2fa7fc0000000fb7ff8000000000000"
            + String(repeating: "81", count: 40) + "00")!

    @Test("Transaction.fromCBOR throws on NaN-duplicate metadata keys instead of trapping")
    func transactionWithNaNKeysThrows() {
        #expect(Self.nanTransaction.count == 69)
        #expect(throws: CardanoCoreError.self) {
            _ = try Transaction.fromCBOR(data: Self.nanTransaction)
        }
    }

    @Test("The same transaction with ordinary keys still decodes")
    func transactionControlDecodes() throws {
        let control = Data(
            hexString: "84a3008001800200a0f5a100a2" + "0100" + "03"
                + String(repeating: "81", count: 40) + "00")!
        _ = try Transaction.fromCBOR(data: control)
    }

    @Test("OperationalCertificate.fromCBOR throws on NaN-duplicate keys instead of trapping")
    func operationalCertificateWithNaNKeysThrows() {
        let data = Data(hexString: "8281a2fa7fc0000000fb7ff80000000000000040")!
        #expect(throws: CardanoCoreError.self) {
            _ = try OperationalCertificate.fromCBOR(data: data)
        }
    }

    @Test("A Primitive map with a float32 NaN and a double NaN key throws instead of trapping")
    func primitiveRoundTripThrows() {
        let data = Data(hexString: "a2fa7fc0000000fb7ff800000000000000")!
        #expect(throws: CardanoCoreError.self) {
            _ = try Primitive.fromCBOR(data: data).toCBORData()
        }
    }

    @Test("A map with one NaN key round-trips")
    func singleNaNKeyRoundTrips() throws {
        let data = Data(hexString: "a1fb7ff800000000000000")!
        let primitive = try Primitive.fromCBOR(data: data)
        #expect(try primitive.toCBORData() == data)
    }

    @Test("Float primitives compare and hash by bit pattern")
    func floatEqualityIsBitwise() {
        #expect(Primitive.float(.nan) == Primitive.float(.nan))
        #expect(Primitive.float(.nan).hashValue == Primitive.float(.nan).hashValue)
        #expect(Primitive.float(0.0) != Primitive.float(-0.0))
        #expect(Primitive.float(1.5) == Primitive.float(1.5))
        #expect(Set<Primitive>([.float(.nan), .float(.nan)]).count == 1)
    }

    @Test("Map keys that collide once written as CBOR throw instead of trapping")
    func collidingKeysThrow() {
        // .int(1) and .uint(1) are different primitives but the same CBOR key.
        var ordered = OrderedDictionary<Primitive, Primitive>()
        ordered[.int(1)] = .null
        ordered[.uint(1)] = .null
        #expect(throws: CardanoCoreError.self) { _ = try Primitive.orderedDict(ordered).toCBOR() }
        #expect(throws: CardanoCoreError.self) {
            _ = try Primitive.indefiniteDictionary(ordered).toCBOR()
        }
        #expect(throws: CardanoCoreError.self) {
            _ = try Primitive.dict([.int(1): .null, .uint(1): .null]).toCBOR()
        }
        #expect(throws: CardanoCoreError.self) {
            _ = try CBORTag(tag: 121, value: .orderedDict(ordered)).taggedCBOR()
        }
    }
}

// MARK: - JSON nesting depth

@Suite struct AuditJSONDepthTests {
    @Test("PlutusData JSON nested past the limit throws on a 512 KB stack")
    func plutusDataTooDeep() {
        expectThrowsOnSmallStack { _ = try PlutusData.fromJSON(nestedPlutusList(255)) }
        expectThrowsOnSmallStack { _ = try PlutusData.fromJSON(nestedPlutusList(PlutusData.maxConversionDepth)) }
        expectThrowsOnSmallStack { _ = try PlutusData.fromJSON(nestedConstr(255)) }
        expectThrowsOnSmallStack { _ = try Constr.fromJSON(nestedConstr(255)) }
    }

    @Test("PlutusData JSON within the limit still decodes on a 512 KB stack")
    func plutusDataModerate() {
        expectSucceedsOnSmallStack { _ = try PlutusData.fromJSON(nestedPlutusList(100)) }
        // 127 lists around an integer: 128 levels, the most toDict() writes.
        let deepest = PlutusData.maxConversionDepth - 1
        expectSucceedsOnSmallStack { _ = try PlutusData.fromJSON(nestedPlutusList(deepest)) }
        expectSucceedsOnSmallStack { _ = try Constr.fromJSON(nestedConstr(deepest)) }
        expectSucceedsOnSmallStack { _ = try RawPlutusData.fromJSON(nestedConstr(deepest)) }
        expectSucceedsOnSmallStack {
            let map = String(repeating: "{\"map\":[{\"k\":{\"int\":1},\"v\":", count: deepest)
                + "{\"int\":1}" + String(repeating: "}]}", count: deepest)
            _ = try PlutusData.fromJSON(map)
        }
    }

    @Test("PlutusData written to JSON within the limit reads back")
    func plutusDataRoundTrip() throws {
        // Writing the JSON runs on an 8 MB stack: only reading is under test.
        let outcome = onSmallStack(stackSize: 8 * 1024 * 1024) {
            var built = PlutusData.bigInt(.int(1))
            for _ in 0..<(PlutusData.maxConversionDepth - 1) { built = .array([built]) }
            let data = built
            let json = try #require(try data.toJSON())
            let deeper = try PlutusData.array([data]).dict()
            expectSucceedsOnSmallStack {
                let decoded = try PlutusData.fromJSON(json)
                #expect(decoded == data)
            }
            expectThrowsOnSmallStack { _ = try PlutusData.fromDict(deeper) }
        }
        if case .failure(let error) = outcome { Issue.record(error) }
    }

    @Test("Metadata JSON nested past the limit throws on a 512 KB stack")
    func metadatumTooDeep() {
        expectThrowsOnSmallStack { _ = try TransactionMetadatum.fromJSON(nestedArrays(500)) }
        expectThrowsOnSmallStack {
            _ = try TransactionMetadatum.fromJSON(nestedArrays(TransactionMetadatum.maxConversionDepth))
        }
    }

    @Test("Metadata JSON within the limit still decodes on a 512 KB stack")
    func metadatumModerate() {
        expectSucceedsOnSmallStack { _ = try TransactionMetadatum.fromJSON(nestedArrays(100)) }
        let deepest = TransactionMetadatum.maxConversionDepth - 1
        expectSucceedsOnSmallStack { _ = try TransactionMetadatum.fromJSON(nestedArrays(deepest)) }
        expectSucceedsOnSmallStack { _ = try TransactionMetadatum.fromJSON(nestedPlutusList(deepest)) }
    }

    @Test("Metadata nested under {\"int\": …} cannot recurse without bound")
    func metadatumNestedIntWrappers() {
        let json = String(repeating: "{\"int\":", count: 300) + "1" + String(repeating: "}", count: 300)
        expectThrowsOnSmallStack { _ = try TransactionMetadatum.fromJSON(json) }
        expectSucceedsOnSmallStack {
            let value = try TransactionMetadatum.fromJSON("{\"int\":5}")
            #expect(value == .integer(5))
        }
    }

    @Test("Native script JSON nested past the limit throws on a 512 KB stack")
    func nativeScriptTooDeep() {
        for type in ["all", "any", "atLeast"] {
            expectThrowsOnSmallStack { _ = try NativeScript.fromJSON(nestedNativeScript(type, 255)) }
        }
        expectThrowsOnSmallStack { _ = try ScriptAll.fromJSON(nestedNativeScript("all", 255)) }
        expectThrowsOnSmallStack { _ = try ScriptAny.fromJSON(nestedNativeScript("any", 255)) }
        expectThrowsOnSmallStack { _ = try ScriptNofK.fromJSON(nestedNativeScript("atLeast", 255)) }
    }

    @Test("Native script JSON within the limit still decodes on a 512 KB stack")
    func nativeScriptModerate() {
        for type in ["all", "any", "atLeast"] {
            expectSucceedsOnSmallStack { _ = try NativeScript.fromJSON(nestedNativeScript(type, 100)) }
            expectSucceedsOnSmallStack {
                _ = try NativeScript.fromJSON(nestedNativeScript(type, NativeScript.maxConversionDepth - 1))
            }
            expectThrowsOnSmallStack {
                _ = try NativeScript.fromJSON(nestedNativeScript(type, NativeScript.maxConversionDepth))
            }
        }
    }

    @Test("Pool metadata with a deeply nested extra field throws on a 512 KB stack")
    func poolMetadataDeepExtraField() {
        expectThrowsOnSmallStack { _ = try PoolMetadata.fromJSON(poolMetadataJSON(extraDepth: 400)) }
        expectSucceedsOnSmallStack {
            let metadata = try PoolMetadata.fromJSON(poolMetadataJSON(extraDepth: 100))
            #expect(metadata.ticker == "ABC")
        }
    }

    @Test("Primitive.from(json:) and Primitive.fromAny reject deep nesting")
    func primitiveConversionsTooDeep() {
        expectThrowsOnSmallStack {
            let json = try JSONSerialization.jsonObject(with: Data(nestedArrays(400).utf8))
            _ = try Primitive.from(json: json)
        }
        expectSucceedsOnSmallStack {
            let json = try JSONSerialization.jsonObject(with: Data(nestedArrays(100).utf8))
            _ = try Primitive.from(json: json)
        }
        expectThrowsOnSmallStack {
            var value: Any = 1
            for _ in 0..<400 { value = [value] }
            _ = try Primitive.fromAny(value)
        }
        expectSucceedsOnSmallStack {
            var value: Any = 1
            for _ in 0..<100 { value = [value] }
            _ = try Primitive.fromAny(value)
        }
    }

    @Test("RawPlutusData JSON nested past the limit throws on a 512 KB stack")
    func rawPlutusDataTooDeep() {
        expectThrowsOnSmallStack { _ = try RawPlutusData.fromJSON(nestedPlutusList(255)) }
        expectThrowsOnSmallStack { _ = try RawPlutusData.fromJSON(nestedConstr(255)) }
        expectSucceedsOnSmallStack { _ = try RawPlutusData.fromJSON(nestedPlutusList(50)) }
    }
}
