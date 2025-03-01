import Foundation

protocol ConfigFile: Codable, Hashable, Equatable {}

extension ConfigFile {
    /// Save the JSON representation to a file.
    /// - Parameter path: The file path.
    func save(to path: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            throw CardanoCoreError.ioError("File already exists: \(path)")
        }
        
        let data = try JSONEncoder().encode(self)
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
    
    /// Load the object from a JSON file.
    /// - Parameter path: The file path
    /// - Returns: The object restored from the JSON file.
    static func load(from path: String) throws -> Self {
        let jsonString = try String(contentsOfFile: path, encoding: .utf8)
        return try JSONDecoder().decode(
            Self.self,
            from: jsonString.toData
        )
    }
}
