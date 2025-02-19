import Foundation
@testable import SwiftCardanoCore

var drepId: String? {
    do {
        let filePath = try getFilePath(
            forResource: drepIdFilePath.forResource,
            ofType: drepIdFilePath.ofType,
            inDirectory: drepIdFilePath.inDirectory
        )
        return try String(contentsOfFile: filePath!).trimmingCharacters(in: .newlines)
    } catch {
        return nil
    }
}
var drepHexId: String? {
    do {
        let filePath = try getFilePath(
            forResource: drepHexIdFilePath.forResource,
            ofType: drepHexIdFilePath.ofType,
            inDirectory: drepHexIdFilePath.inDirectory
        )
        return try String(contentsOfFile: filePath!).trimmingCharacters(in: .newlines)
    } catch {
        return nil
    }
}
//var drepMetadata: DRepMetadata? {
//    do {
//        let filePath = try getFilePath(
//            forResource: drepMetadataFilePath.forResource,
//            ofType: drepMetadataFilePath.ofType,
//            inDirectory: drepMetadataFilePath.inDirectory
//        )
//        return try DRepMetadata.load(from: filePath!)
//    } catch {
//        return nil
//    }
//}
var drepMetadataHash: String? {
    do {
        let filePath = try getFilePath(
            forResource: drepMetadataHashFilePath.forResource,
            ofType: drepMetadataHashFilePath.ofType,
            inDirectory: drepMetadataHashFilePath.inDirectory
        )
        return try String(contentsOfFile: filePath!).trimmingCharacters(in: .newlines)
    } catch {
        return nil
    }
}
