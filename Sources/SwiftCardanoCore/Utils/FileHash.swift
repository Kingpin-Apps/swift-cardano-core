import Foundation
import SwiftNcal

/// Protocol for hashing file contents
/// - Requires `contents` property to be settable
/// - Requires `HASH_SIZE` static property to be set
/// - Requires `init(contents:)` initializer
public protocol FileHashable: Codable, Hashable, Equatable {
    var contents: String { get set }
    static var HASH_SIZE: Int { get }
    
    init(contents: String)
}

public extension FileHashable {
    /// Load file contents from a given path
    /// - Parameter path: The path to the file
    /// - Returns: An instance of the conforming type
    static func load(from path: String) throws -> Self {
        self.init(contents: try String(contentsOfFile: path))
    }
    
    /// Get the hash of the file contents
    /// - Returns: The hash of the file contents
    func hash() throws -> String {
        let hash =  try SwiftNcal.Hash().blake2b(
            data: self.contents.data(using: .utf8)!,
            digestSize: Self.HASH_SIZE,
            encoder: RawEncoder.self
        )
        
        return hash.toHex
    }
}

/// Hash of a file
public struct FileHash: FileHashable {
    public var contents: String
    public static var HASH_SIZE: Int { 32 }
    
    public init(contents: String) {
        self.contents = contents
    }
}

