import Foundation
import Testing
import SwiftCardanoCore

/// The code example of the package's landing page (`Documentation.md`),
/// compiled and run so that it stays true to the API.
///
/// The module is imported without `@testable`, so the example sees only the
/// public API, as a reader of the documentation does.
@Suite("Documentation guide examples")
struct DocumentationGuideExamplesTests {
    @Test func quickStart() throws {
        // Generate cryptographic keys
        let paymentKeyPair = try PaymentKeyPair.generate()
        let stakeKeyPair = try StakeKeyPair.generate()

        // Create a Cardano address
        let address = try Address(
            paymentPart: .verificationKeyHash(try paymentKeyPair.verificationKey.hash()),
            stakingPart: .verificationKeyHash(try stakeKeyPair.verificationKey.hash()),
            network: .testnet
        )

        print("Generated address: \(try address.toBech32())")
        #expect(try address.toBech32().hasPrefix("addr_test1"))
    }
}
