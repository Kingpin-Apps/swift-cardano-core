import Foundation
import Version

public struct VersionFile: Codable {
    let version: String
}

public var version: Version? {
    // Try to read version from version.json in bundle resources
    let data = Data(PackageResources.version_json)
    guard let versionFile = try? JSONDecoder().decode(VersionFile.self, from: data) else {
        // Failed to load version information; return nil
        return nil
    }
    
    return Version(versionFile.version)
}
