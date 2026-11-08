import Testing
import Foundation
@testable import SwiftCardanoCore

/// `JSONSerializable.fromJSON` checks depth on the raw bytes before
/// JSONSerialization recurses.
@Suite("Raw JSON depth check")
struct JSONRawDepthTests {
    @Test("Deep nesting is refused before parsing")
    func deep() {
        let nested = String(repeating: "[", count: 500) + "1" + String(repeating: "]", count: 500)
        #expect(throws: CardanoCoreError.self) { try checkRawJSONDepth(Data(nested.utf8)) }
        #expect(throws: CardanoCoreError.self) {
            _ = try OperationalCertificateIssueCounter.fromJSON(#"{"a":\#(nested)}"#)
        }
    }

    @Test("Brackets inside strings are not counted, and normal JSON passes")
    func strings() throws {
        let inString = "\"" + String(repeating: "[", count: 300) + "\\\"]\""
        try checkRawJSONDepth(Data(#"{"a":\#(inString),"b":[[1]]}"#.utf8))
        let atLimit = String(repeating: "[", count: maxRawJSONDepth) + String(repeating: "]", count: maxRawJSONDepth)
        try checkRawJSONDepth(Data(atLimit.utf8))
        #expect(throws: CardanoCoreError.self) { try checkRawJSONDepth(Data(("[" + atLimit + "]").utf8)) }
    }

    @Test("JSONSerialization parses the raw limit on a 512 KiB stack")
    func limitFitsSmallStack() {
        final class Box: @unchecked Sendable { var parsed = false }
        let box = Box()
        let json = String(repeating: "[", count: maxRawJSONDepth) + "1" + String(repeating: "]", count: maxRawJSONDepth)
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            box.parsed = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) != nil
            done.signal()
        }
        thread.stackSize = 512 * 1024
        thread.start()
        done.wait()
        #expect(box.parsed)
    }

    @Test("Zero bytes and unbalanced brackets are refused")
    func malformed() {
        #expect(throws: CardanoCoreError.self) { try checkRawJSONDepth(Data([0x7b, 0x00, 0x7d, 0x00])) }
        #expect(throws: CardanoCoreError.self) { try checkRawJSONDepth(Data("]]]{".utf8)) }
    }
}
