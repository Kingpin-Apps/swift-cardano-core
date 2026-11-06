import Foundation
import SwiftNaCl

/// Protocol for hashing file contents
/// - Requires `contents` property to be settable
/// - Requires `HASH_SIZE` static property to be set
/// - Requires `init(contents:)` initializer
public protocol FileHashable: Codable, Hashable, Equatable {
    /// The file's text.
    var contents: String { get set }
    /// The size of the BLAKE2b digest ``hash()`` returns, in bytes.
    static var HASH_SIZE: Int { get }
    
    /// Creates a value holding the given file text.
    /// - Parameter contents: The file's text.
    init(contents: String)
}

public extension FileHashable {
    /// Load file contents from a given path
    /// - Parameter path: The path to the file
    /// - Returns: An instance of the conforming type
    static func load(from path: String) throws -> Self {
        self.init(contents: try readTextFile(path))
    }
    
    /// Get the hash of the file contents
    ///
    /// The hash is BLAKE2b of the UTF-8 bytes of ``contents``, ``HASH_SIZE``
    /// bytes long.
    /// - Returns: The hash of the file contents as lowercase hex.
    func hash() throws -> String {
        let hash =  try SwiftNaCl.Hash().blake2b(
            data: self.contents.data(using: .utf8)!,
            digestSize: Self.HASH_SIZE,
            encoder: RawEncoder.self
        )
        
        return hash.toHex
    }
}

/// Hash of a file
public struct FileHash: FileHashable {
    /// The file's text.
    public var contents: String
    /// The digest size, 32 bytes.
    public static var HASH_SIZE: Int { 32 }
    
    /// Creates a file hash holder for the given text.
    /// - Parameter contents: The file's text.
    public init(contents: String) {
        self.contents = contents
    }
}

