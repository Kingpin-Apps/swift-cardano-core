import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

struct CertificateTests {

    @Test func testStakeRegistrationCertificate() async throws {
        let stakeRegistration = stakeRegistrationCertificate!
        let certificate = Certificate.stakeRegistration(stakeRegistration)
        
        // Assertions
        #expect(certificate != nil, "Certificate should not be nil")
    }
}
