import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct UnUnregisterDRepTests {
    let drepCredential = DRepCredential(credential:
            .verificationKeyHash(try! drepVerificationKey!.hash())
    )
    
    let coin: Coin = 500000000
    
    @Test func testInitialization() async throws {
        let cert = UnregisterDRep(
            drepCredential: drepCredential,
            coin: coin
        )
        
        #expect(UnregisterDRep.CODE.rawValue == 17)
        #expect(cert.drepCredential == drepCredential)
        #expect(cert.coin == coin)
    }
    
    @Test func testJSON() async throws {
        let cert = unregisterDRepCertificate!
        
        let json = try cert.toTextEnvelope()
        let certFromJSON = try UnregisterDRep.fromTextEnvelope(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = unregisterDRepCertificate?.payload.toHex
        
        let cert = UnregisterDRep(
            drepCredential: drepCredential,
            coin: coin
        )
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(UnregisterDRep.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
