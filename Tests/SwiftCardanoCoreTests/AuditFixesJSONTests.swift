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
/// concurrency cooperative thread, and returns how it ended.
private func onSmallStack(_ body: @escaping @Sendable () throws -> Void) -> Result<Void, any Error> {
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
    thread.stackSize = 512 * 1024
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
