import Foundation

/// A URL as the ledger holds one: `url = tstr .size (0 .. 128)`.
///
/// The ledger keeps the text as written — anchor and pool-metadata hashes are
/// checked against the documents it names — so this does too. Parsing it into
/// a Foundation `URL` would change it: escaping a space or a stray `%`, or
/// refusing the empty string the CDDL allows.
public struct Url: CBORSerializable, Sendable {
    /// The URL's text, exactly as written.
    public let text: String

    /// The text as a Foundation `URL`, or `nil` when Foundation cannot read
    /// it. The ledger does not require that it can.
    public var value: URL? { URL(string: text) }

    public var absoluteString: String { text }

    /// - Throws: When `text` is longer than 128 bytes of UTF-8, which the
    ///   ledger rejects.
    public init(_ text: String) throws {
        guard text.utf8.count <= 128 else {
            throw CardanoCoreError.valueError(
                "A URL may be at most 128 bytes, got \(text.utf8.count): \(text)")
        }
        self.text = text
    }

    public init(from primitive: Primitive) throws {
        switch primitive {
        case .string(let text):
            try self.init(text)
        case .cborSimpleValue(.indefiniteTextString(let chunks)):
            try self.init(chunks.joined())
        default:
            throw CardanoCoreError.valueError("Invalid Url type")
        }
    }

    public func toPrimitive() throws -> Primitive {
        .string(text)
    }
}
