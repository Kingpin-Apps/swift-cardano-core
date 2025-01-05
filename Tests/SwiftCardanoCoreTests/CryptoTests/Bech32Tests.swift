//
//  Created by Hareem Adderley on 19/06/2024 AT 8:13 PM
//  Copyright © 2024 Kingpin Apps. All rights reserved.
//
import XCTest
@testable import SwiftCardanoCore

final class Bech32Tests: XCTestCase {
    let bech32 = Bech32()
    let addr = "addr_test1qrxrqjtlfluk9axpmjj5enh0uw0cduwhz7txsqyl36m3uk2g9z3d4kaf0j5l6rxunxt43x28pssehhqds2x05mwld45sjncs0p"

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testBech32() throws {
        let decoded = bech32.decode(addr: addr)
        XCTAssertFalse(decoded!.isEmpty, "Empty result for \"\(addr)\"")
        let recoded = bech32.encode(hrp: "addr_test", witprog: decoded!)
        XCTAssert(addr.lowercased() == recoded!.lowercased(), "Roundtrip encoding failed: \(addr) != \(String(describing: recoded))")
    }
}
