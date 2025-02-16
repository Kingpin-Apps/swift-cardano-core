import Testing
import Foundation
import PotentCBOR
@testable import SwiftCardanoCore

@Suite struct RegisterDRepTests {
    let coin: Coin = 500000000
    
    let drepType: CredentialType = .verificationKeyHash(try! drepVerificationKey!.hash())
    
    let anchor = Anchor(
        anchorUrl: try! Url(
            "https://raw.githubusercontent.com/cardano-foundation/CIPs/master/CIP-0119/examples/drep.jsonld"
        ),
        anchorDataHash: AnchorDataHash(
            payload: drepMetadataHash!.hexStringToData
        )
    )
    
    @Test func testInitialization() async throws {
        let drepCredential = DRepCredential(credential: drepType)
        
        let registerDRep = RegisterDRep(
            drepCredential: drepCredential,
            coin: coin,
            anchor: anchor
        )
        
        #expect(RegisterDRep.CODE.rawValue == 16)
        #expect(registerDRep.drepCredential == drepCredential)
        #expect(registerDRep.coin == coin)
        #expect(registerDRep.anchor == anchor)
    }
    
    @Test func testJSON() async throws {
        let cert = registerDRepCertificate!
        
        let json = try cert.toJSON()
        let certFromJSON = try RegisterDRep.fromJSON(json!)
        
        #expect(cert == certFromJSON)
    }
    
    @Test func testToFromCBOR() async throws {
        let excpectedCBOR = registerDRepCertificate?.payload.toHex
        
        let drepCredential = DRepCredential(credential: drepType)
        
        let cert = RegisterDRep(
            drepCredential: drepCredential,
            coin: coin,
            anchor: anchor
        )
        
        let cborData = try CBOREncoder().encode(cert)
        let cborHex = cborData.toHex
        
        let fromCBOR = try CBORDecoder().decode(RegisterDRep.self, from: cborData)
        
        #expect(cborHex == excpectedCBOR)
        #expect(fromCBOR == cert)
    }
}
