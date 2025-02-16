import Foundation
@testable import SwiftCardanoCore


var paymentAddress: Address? {
    do {
        return try getTestAddress(
            forResource: paymentAddressFilePath.forResource,
            ofType: paymentAddressFilePath.ofType,
            inDirectory: paymentAddressFilePath.inDirectory)
    } catch {
        return nil
    }
}

var stakeAddress: Address? {
    do {
        return try getTestAddress(
            forResource: stakeAddressFilePath.forResource,
            ofType: stakeAddressFilePath.ofType,
            inDirectory: stakeAddressFilePath.inDirectory)
    } catch {
        return nil
    }
}

var scriptHash: String? {
    do {
        let filePath = try getFilePath(
            forResource: scriptHashFilePath.forResource,
            ofType: scriptHashFilePath.ofType,
            inDirectory: scriptHashFilePath.inDirectory
        )
        return try String(contentsOfFile: filePath!).trimmingCharacters(in: .newlines)
    } catch {
        return nil
    }
}
