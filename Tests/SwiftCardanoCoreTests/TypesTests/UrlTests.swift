import Foundation
import Testing

@testable import SwiftCardanoCore

/// The ledger keeps a URL's text as written (`url = tstr .size (0 .. 128)`).
@Suite("A URL keeps its text")
struct UrlTests {
    @Test("Text Foundation would rewrite or refuse is kept as written", arguments: [
        "https://a.b/x y", "%zz", "", "ipfs://bafy", "https://example.com/pool.json",
    ])
    func keepsText(text: String) throws {
        let url = try Url(text)
        #expect(url.text == text)
        #expect(try Url(from: url.toPrimitive()).text == text)
        #expect(try Url.fromCBOR(data: url.toCBORData()).text == text)
    }

    @Test("The limit is 128 bytes of UTF-8, not 128 characters")
    func byteLimit() throws {
        _ = try Url(String(repeating: "a", count: 128))
        #expect(throws: CardanoCoreError.self) { try Url(String(repeating: "a", count: 129)) }
        // 64 characters, 128 bytes; one more is 130.
        _ = try Url(String(repeating: "é", count: 64))
        #expect(throws: CardanoCoreError.self) { try Url(String(repeating: "é", count: 65)) }
    }

    @Test("An anchor keeps its URL as written")
    func anchor() throws {
        let anchor = try Anchor(anchorUrl: try Url("https://a.b/x y"),
            anchorDataHash: AnchorDataHash(payload: Data(repeating: 1, count: 32)))
        #expect(try Anchor.fromCBOR(data: anchor.toCBORData()).anchorUrl.text == "https://a.b/x y")
    }
}
