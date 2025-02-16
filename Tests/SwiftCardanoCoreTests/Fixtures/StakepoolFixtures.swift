import Foundation
import Testing
import PotentCBOR
@testable import SwiftCardanoCore

var poolMetadataJSON: PoolMetadata? {
    do {
        let filePath = try getFilePath(
            forResource: poolMetadataJSONFilePath.forResource,
            ofType: poolMetadataJSONFilePath.ofType,
            inDirectory: poolMetadataJSONFilePath.inDirectory
        )
        return try PoolMetadata.load(from: filePath!)
    } catch {
        return nil
    }
}

var poolMetadataHash: String? {
    do {
        let filePath = try getFilePath(
            forResource: poolMetadataHashFilePath.forResource,
            ofType: poolMetadataHashFilePath.ofType,
            inDirectory: poolMetadataHashFilePath.inDirectory
        )
        return try String(contentsOfFile: filePath!).trimmingCharacters(in: .newlines)
    } catch {
        return nil
    }
}
