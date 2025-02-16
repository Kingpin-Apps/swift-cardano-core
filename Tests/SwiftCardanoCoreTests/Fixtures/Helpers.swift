import Foundation
import Testing
@testable import SwiftCardanoCore

func getTestAddress(forResource: String, ofType: String, inDirectory: String) throws -> Address? {
    guard let filePath = Bundle.module.path(
        forResource: forResource,
        ofType: ofType,
        inDirectory: inDirectory) else {
        Issue.record("File not found: \(forResource).\(ofType)")
        try #require(Bool(false))
        return nil
    }
    
    do {
        return try Address.load(from: filePath)
    } catch {
        Issue.record("Failed to load address from file: \(filePath)")
        try #require(Bool(false))
        return nil
    }
}

func getFilePath(forResource: String, ofType: String, inDirectory: String) throws -> String? {
    guard let filePath = Bundle.module.path(
        forResource: forResource,
        ofType: ofType,
        inDirectory: inDirectory) else {
        Issue.record("File not found: \(forResource).\(ofType)")
        try #require(Bool(false))
        return nil
    }
    return filePath
}

func getVerificationKey<T>(forResource: String, ofType: String, inDirectory: String) throws -> T? where T: VerificationKey {
    guard let filePath = Bundle.module.path(
        forResource: forResource,
        ofType: ofType,
        inDirectory: inDirectory) else {
        Issue.record("File not found: \(forResource).\(ofType)")
        try #require(Bool(false))
        return nil
    }
    
    do {
        let key = try T.load(from: filePath)
        return key
    } catch {
        Issue.record("Failed to load address from file: \(filePath)")
        try #require(Bool(false))
        return nil
    }
}
