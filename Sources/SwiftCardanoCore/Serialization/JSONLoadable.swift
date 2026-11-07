import Foundation

/// A `Codable` value that can be saved to and loaded from a JSON file with
/// `JSONEncoder` and `JSONDecoder`.
public protocol JSONLoadable: Codable, Hashable, Equatable, Sendable {}

public extension JSONLoadable {
    
    /// Save the JSON representation to a file.
    /// - Parameters:
    ///  - path: The path to save the file
    ///  - overwrite: Whether to overwrite the file if it already exists
    /// - Throws: `CardanoCoreError.ioError` if the file already exists and
    ///   overwrite is false, or when it cannot be written
    ///
    /// The file is created owner-only (mode `0600`), as the JSON may hold
    /// secrets; see ``PayloadCBORSerializable/save(to:overwrite:)``.
    func save(to path: String, overwrite: Bool = false) throws {
        let data = try JSONEncoder().encode(self)
        try writeOwnerOnlyFile(data, to: path, overwrite: overwrite)
    }
    
    /// Load the object from a JSON file.
    /// - Parameter path: The file path
    /// - Returns: The object restored from the JSON file.
    static func load(from path: String) throws -> Self {
        let jsonString = try readTextFile(path)
        return try JSONDecoder().decode(
            Self.self,
            from: jsonString.toData
        )
    }
}
