import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct CertificateTests {

    @Test func testStakeRegistrationCertificate() async throws {
        let stakeRegistration = stakeRegistrationCertificate!
        let certificate = Certificate.stakeRegistration(stakeRegistration)
        
        // Assertions
        guard case .stakeRegistration(let reg) = certificate else {
            fatalError("Expected stake registration certificate")
        }
        #expect(
            reg.payload == stakeRegistration.payload,
            "Certificate should not be nil"
        )
    }
}
