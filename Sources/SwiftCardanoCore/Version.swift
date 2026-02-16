import Foundation
import Version

public struct VersionFile: Codable {
    let version: String
}

public var version: Version? {
    // Try to read version from version.json in bundle resources
    guard let resourceURL = Bundle.module.url(forResource: "version", withExtension: "json", subdirectory: "Resources"),
          let data = try? Data(contentsOf: resourceURL),
          let versionFile = try? JSONDecoder().decode(VersionFile.self, from: data) else {
        // Failed to load version information; return nil
        return nil
    }
    
    return Version(versionFile.version)
}
