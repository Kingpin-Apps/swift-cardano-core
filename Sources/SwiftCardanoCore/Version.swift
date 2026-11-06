import Foundation
import Version

/// The contents of the package's bundled `version.json` file.
public struct VersionFile: Codable {
    let version: String
}

/// The version of this package, read from its bundled `version.json`, or `nil`
/// when the file cannot be decoded.
public var version: Version? {
    // Try to read version from version.json in bundle resources
    let data = Data(PackageResources.version_json)
    guard let versionFile = try? JSONDecoder().decode(VersionFile.self, from: data) else {
        // Failed to load version information; return nil
        return nil
    }
    
    return Version(versionFile.version)
}
