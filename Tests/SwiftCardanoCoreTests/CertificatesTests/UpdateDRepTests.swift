import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct UpdateDRepTests {
    let drepCredential = DRepCredential(
        credential: .verificationKeyHash(try! drepVerificationKey!.hash())
    )
    
    let anchor = Anchor(
        anchorUrl: try! Url(
            "https://raw.githubusercontent.com/cardano-foundation/CIPs/master/CIP-0119/examples/drep.jsonld"
        ),
        anchorDataHash: AnchorDataHash(
            payload: drepMetadataHash!.hexStringToData
        )
    )
    
    @Test func testInitialization() async throws {
        let cert = UpdateDRep(
            drepCredential: drepCredential,
            anchor: anchor
        )
        
        #expect(UpdateDRep.CODE.rawValue == 18)
        #expect(cert.drepCredential == drepCredential)
        #expect(cert.anchor == anchor)
    }
    
    @Test func testJSON() async throws {
        let cert = updateDRepCertificate!
        
        let json = try cert.toTextEnvelope()
        let certFromJSON = try UpdateDRep.fromTextEnvelope(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = updateDRepCertificate?.payload.toHex
        
        let cert = UpdateDRep(
            drepCredential: drepCredential,
            anchor: anchor
        )
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(UpdateDRep.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
