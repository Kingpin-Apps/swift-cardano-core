import Foundation
@testable import SwiftCardanoCore


var sigNativescript: ScriptPubkey? {
    do {
        let filePath = try getFilePath(
            forResource: sigNativescriptFilePath.forResource,
            ofType: sigNativescriptFilePath.ofType,
            inDirectory: sigNativescriptFilePath.inDirectory)
        return try ScriptPubkey.load(from: filePath!)
    } catch {
        return nil
    }
}

var allNativescript: ScriptAll? {
    do {
        let filePath = try getFilePath(
            forResource: allNativescriptFilePath.forResource,
            ofType: allNativescriptFilePath.ofType,
            inDirectory: allNativescriptFilePath.inDirectory)
        return try ScriptAll.load(from: filePath!)
    } catch {
        return nil
    }
}

var anyNativescript: ScriptAny? {
    do {
        let filePath = try getFilePath(
            forResource: anyNativescriptFilePath.forResource,
            ofType: anyNativescriptFilePath.ofType,
            inDirectory: anyNativescriptFilePath.inDirectory)
        return try ScriptAny.load(from: filePath!)
    } catch {
        return nil
    }
}

var atLeastNativescript: ScriptNofK? {
    do {
        let filePath = try getFilePath(
            forResource: atLeastNativescriptFilePath.forResource,
            ofType: atLeastNativescriptFilePath.ofType,
            inDirectory: atLeastNativescriptFilePath.inDirectory)
        return try ScriptNofK.load(from: filePath!)
    } catch {
        return nil
    }
}

var afterNativescript: AfterScript? {
    do {
        let filePath = try getFilePath(
            forResource: afterNativescriptFilePath.forResource,
            ofType: afterNativescriptFilePath.ofType,
            inDirectory: afterNativescriptFilePath.inDirectory)
        return try AfterScript.load(from: filePath!)
    } catch {
        return nil
    }
}

var beforeNativescript: BeforeScript? {
    do {
        let filePath = try getFilePath(
            forResource: beforeNativescriptFilePath.forResource,
            ofType: beforeNativescriptFilePath.ofType,
            inDirectory: beforeNativescriptFilePath.inDirectory)
        return try BeforeScript.load(from: filePath!)
    } catch {
        return nil
    }
}
