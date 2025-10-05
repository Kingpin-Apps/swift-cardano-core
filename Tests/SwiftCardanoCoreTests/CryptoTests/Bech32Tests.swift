//
//  Created by Hareem Adderley on 19/06/2024 AT 8:13 PM
//  Copyright © 2024 Kingpin Apps. All rights reserved.
//
import Testing
@testable import SwiftCardanoCore

@Suite("Bech32 Tests")
struct Bech32Tests {
    let bech32 = Bech32()
    let addr = "addr_test1qrxrqjtlfluk9axpmjj5enh0uw0cduwhz7txsqyl36m3uk2g9z3d4kaf0j5l6rxunxt43x28pssehhqds2x05mwld45sjncs0p"

    @Test("Decoding and encoding round-trips a bech32 address")
    func bech32_roundTrip() async throws {
        let decoded = try #require(bech32.decode(addr: addr), "Decoding returned nil for \(addr)")
        #expect(!decoded.isEmpty, "Empty result for \"\(addr)\"")

        let recoded = try #require(bech32.encode(hrp: "addr_test", witprog: decoded), "Encoding returned nil")
        #expect(addr.lowercased() == recoded.lowercased(), "Roundtrip encoding failed: \(addr) != \(recoded)")
    }
}
