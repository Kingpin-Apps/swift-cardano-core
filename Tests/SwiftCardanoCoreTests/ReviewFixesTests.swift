import Testing
import Foundation
import BigInt
import OrderedCollections

import CBORCodable
@testable import SwiftCardanoCore

private let policyA = ScriptHash(payload: Data(repeating: 0xA1, count: 28))
private let policyB = ScriptHash(payload: Data(repeating: 0xB2, count: 28))
private let token = AssetName(from: "token")

private func multiAsset(_ entries: [(ScriptHash, BigInt)]) -> MultiAsset {
    var data: [ScriptHash: Asset] = [:]
    for (policy, amount) in entries {
        data[policy] = Asset(OrderedDictionary(uniqueKeysWithValues: [(token, amount)]))
    }
    return MultiAsset(data)
}

@Suite struct ValueComparisonTests {
    @Test("A token only on the right makes the left smaller, not larger")
    func tokenOnlyOnTheRight() {
        let lhs = multiAsset([(policyA, 5)])
        let rhs = multiAsset([(policyA, 5), (policyB, 1)])
        #expect(lhs <= rhs)
        #expect(!(lhs >= rhs))
        #expect(lhs < rhs)
        #expect(!(lhs > rhs))
        #expect(rhs > lhs)
    }

    @Test("Multi-assets with no policy in common are not ordered")
    func disjointPolicies() {
        let lhs = multiAsset([(policyA, 1)])
        let rhs = multiAsset([(policyB, 1)])
        #expect(!(lhs <= rhs))
        #expect(!(lhs >= rhs))
        #expect(!(lhs < rhs))
        #expect(!(lhs > rhs))
    }

    @Test("Equal multi-assets are <= and >= but not < or >")
    func equalValues() {
        let lhs = multiAsset([(policyA, 3)])
        let rhs = multiAsset([(policyA, 3)])
        #expect(lhs <= rhs && lhs >= rhs)
        #expect(!(lhs < rhs) && !(lhs > rhs))
    }

    @Test("A negative amount counts against a missing one as zero")
    func negativeAmounts() {
        let negative = multiAsset([(policyA, -2)])
        let empty = MultiAsset([:])
        #expect(negative <= empty)
        #expect(negative < empty)
        #expect(!(empty <= negative))
    }

    @Test("Value covers another only when the coin and every token cover it")
    func valueCoverage() {
        let inputs = Value(coin: 10, multiAsset: multiAsset([(policyA, 5)]))
        let outputs = Value(coin: 4, multiAsset: multiAsset([(policyA, 5), (policyB, 1)]))
        #expect(!(inputs >= outputs))
        #expect(!(outputs <= inputs))
        #expect(!(inputs > outputs))

        let more = Value(coin: 10, multiAsset: multiAsset([(policyA, 6)]))
        #expect(more > inputs)
        #expect(inputs < more)
        #expect(Value(coin: 9, multiAsset: multiAsset([(policyA, 5)])) < inputs)
    }
}

@Suite struct GovernanceCredentialBech32Tests {
    @Test("CIP-105 gives a script DRep the drep_script prefix")
    func scriptDRepPrefix() throws {
        let credential = DRepCredential(credential: .scriptHash(policyA))
        let cip105 = try credential.toBech32(.cip105)
        #expect(cip105.hasPrefix("drep_script1"))
        #expect(try DRepCredential.fromBech32(cip105) == credential)

        let cip129 = try credential.toBech32(.cip129)
        #expect(cip129.hasPrefix("drep1"))
        #expect(try DRepCredential.fromBech32(cip129) == credential)
    }

    @Test("CIP-105 keeps the plain prefix for a key DRep")
    func keyDRepPrefix() throws {
        let credential = DRepCredential(credential: .verificationKeyHash(
            VerificationKeyHash(payload: Data(repeating: 0x11, count: 28))))
        #expect(try credential.toBech32(.cip105).hasPrefix("drep1"))
    }
}

@Suite struct CertificateEnvelopeTypeTests {
    @Test("A certificate read from a Shelley envelope reports and writes that type")
    func shelleyEnvelopeType() throws {
        let delegation = try StakeDelegation(
            stakeCredential: StakeCredential(credential: .verificationKeyHash(
                VerificationKeyHash(payload: Data(repeating: 0x11, count: 28)))),
            poolKeyHash: PoolKeyHash(payload: Data(repeating: 0x22, count: 28)))
        let conway = try #require(try delegation.toTextEnvelope())
        let shelley = conway
            .replacingOccurrences(of: "CertificateConway", with: "CertificateShelley")
        let restored = try StakeDelegation.fromTextEnvelope(shelley)
        #expect(restored.type == "CertificateShelley")
        #expect(try #require(try restored.toTextEnvelope()).contains("CertificateShelley"))
        #expect(delegation.type == StakeDelegation.TYPE)
    }
}

@Suite struct ScriptRefSyncTests {
    private let before = Script(script: .nativeScript(.invalidBefore(BeforeScript(slot: 100))))
    private let pubkey = Script(script: .nativeScript(.scriptPubkey(ScriptPubkey(
        keyHash: VerificationKeyHash(payload: Data(repeating: 0x33, count: 28))))))

    @Test("Setting script rewrites the value toPrimitive writes")
    func settingScriptUpdatesValue() throws {
        var ref = try ScriptRef(script: before)
        ref.script = pubkey
        let restored = try ScriptRef(from: try ref.toPrimitive())
        #expect(restored.script == pubkey)
    }

    @Test("Setting value decodes script again")
    func settingValueUpdatesScript() throws {
        var ref = try ScriptRef(script: before)
        ref.value = .bytes(try CBOREncoder().encode(pubkey))
        #expect(ref.script == pubkey)
    }

    @Test("Equal references hash alike")
    func hashMatchesEquality() throws {
        let read = try ScriptRef(from: try ScriptRef(script: before).toPrimitive())
        let built = try ScriptRef(script: before)
        #expect(read == built)
        #expect(read.hashValue == built.hashValue)
    }
}
