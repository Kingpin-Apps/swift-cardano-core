import Foundation
import Testing
import SwiftCardanoCore

/// What a caller outside the package can do: the module is imported without
/// `@testable`, so each test compiling at all shows the API is public.
@Suite("Public API")
struct PublicAPITests {
    // MARK: - Errors

    @Test("A caller can catch a specific CardanoCoreError case")
    func catchSpecificError() throws {
        var message: String?
        do {
            _ = try PaymentVerificationKey(payload: Data(count: 31)).verify(signature: Data(count: 64), data: Data())
        } catch CardanoCoreError.invalidKeyTypeError(let text) {
            message = text
        }
        #expect(message == "An Ed25519 verification key is 32 bytes, got 31")
        #expect(CardanoCoreError.ioError(nil).description == "IO error occurred.")
    }

    // MARK: - Ed25519 verification

    @Test("A verification key checks its signing key's signatures")
    func verifySignature() throws {
        let keyPair = try PaymentKeyPair.generate()
        let message = Data("hello".utf8)
        let signature = try keyPair.signingKey.sign(data: message)

        #expect(try keyPair.verificationKey.verify(signature: signature, data: message))
        #expect(try !keyPair.verificationKey.verify(signature: signature, data: Data("hellO".utf8)))
        #expect(try !PaymentKeyPair.generate().verificationKey.verify(signature: signature, data: message))
        #expect(try !keyPair.verificationKey.verify(signature: signature.dropLast(), data: message))
        #expect(try VerificationKeyType.verificationKey(keyPair.verificationKey)
            .verify(signature: signature, data: message))
    }

    @Test("A verification key that is not 32 bytes is rejected, not used")
    func verifyRejectsBadKey() throws {
        let key = try PaymentVerificationKey(payload: Data(count: 31))
        #expect(throws: CardanoCoreError.self) {
            try key.verify(signature: Data(count: 64), data: Data())
        }
    }

    @Test("KES and VRF keys do not check Ed25519 signatures")
    func verifyRefusesKESAndVRF() throws {
        let kes = try KESKeyPair.generate().verificationKey
        let vrf = try VRFKeyPair.generate().verificationKey
        #expect(throws: CardanoCoreError.self) { try kes.verify(signature: Data(count: 64), data: Data()) }
        #expect(throws: CardanoCoreError.self) { try vrf.verify(signature: Data(count: 64), data: Data()) }
    }

    // MARK: - Extended keys

    @Test("A generated extended key signs, and its extended verification key checks it")
    func generateExtendedKey() throws {
        let signingKey = try PaymentExtendedSigningKey.generate()
        #expect(signingKey.payload.count == 128)
        #expect(signingKey.type == PaymentExtendedSigningKey.TYPE)
        #expect(try PaymentExtendedSigningKey.generate() != signingKey)

        let verificationKey = try PaymentExtendedVerificationKey.fromSigningKey(signingKey)
        #expect(verificationKey.payload.count == 64)
        let message = Data("extended".utf8)
        let signature = try signingKey.sign(data: message)
        #expect(try verificationKey.verify(signature: signature, data: message))
        #expect(try !verificationKey.verify(signature: signature, data: Data("other".utf8)))
    }

    @Test("fromHDWallet gives the key type asked for, labelled as that type")
    func fromHDWalletIsConcrete() throws {
        let mnemonic = try HDWallet.generateMnemonic().joined(separator: " ")
        let wallet = try HDWallet.fromMnemonic(mnemonic: mnemonic)
        let stakeKey: StakeExtendedSigningKey =
            try StakeExtendedSigningKey.fromHDWallet(wallet.derive(fromPath: "m/1852'/1815'/0'/2/0"))
        #expect(stakeKey.type == "StakeExtendedSigningKeyShelley_ed25519_bip32")
        #expect(stakeKey.description == StakeExtendedSigningKey.DESCRIPTION)
    }

    @Test("fromSigningKey infers the verification key type")
    func fromSigningKeyInfers() throws {
        let keyPair = try PaymentKeyPair.generate()
        let verificationKey = try PaymentVerificationKey.fromSigningKey(keyPair.signingKey)
        #expect(verificationKey == keyPair.verificationKey)
        #expect(verificationKey.type == PaymentVerificationKey.TYPE)
    }

    // MARK: - Plutus data and AnyValue

    struct Bid: PlutusDataProtocol {
        var amount: Int64
        var bidder: Data

        init(amount: Int64, bidder: Data) {
            self.amount = amount
            self.bidder = bidder
        }

        init(from plutusData: PlutusData) throws {
            guard case .constructor(let constr) = plutusData, constr.fields.count == 2,
                  case .bigInt(.int(let amount)) = constr.fields[0],
                  case .bytes(let bidder) = constr.fields[1] else {
                throw CardanoCoreError.deserializeError("Not a Bid: \(plutusData)")
            }
            self.init(amount: amount, bidder: bidder.data)
        }

        func toPlutusData() throws -> PlutusData {
            .constructor(Constr(tag: 0, fields: [.bigInt(.int(amount)), .bytes(try Bytes(from: bidder))]))
        }
    }

    @Test("A caller's own type can be Plutus data")
    func ownPlutusDataType() throws {
        let bid = Bid(amount: 5_000_000, bidder: Data(repeating: 0xab, count: 28))
        #expect(try Bid(from: bid.toPrimitive()) == bid)
        #expect(try Bid.fromJSON(bid.toJSON()!) == bid)
        #expect(try bid.hash() == datumHash(datum: .plutusData(bid.toPlutusData())))
    }

    @Test("AnyValue is reachable through SwiftCardanoCore alone")
    func anyValueIsReachable() throws {
        let value: AnyValue = Primitive.uint(7).toAnyValue()
        #expect(value == Primitive.uint(7).toAnyValue())
    }

    // MARK: - JSON

    @Test("A value whose JSON is a bare string writes it and reads it back")
    func bareJSONValues() throws {
        let txId = try TransactionId(payload: Data(repeating: 1, count: 32))
        let scriptHash = try ScriptHash(payload: Data(repeating: 2, count: 28))
        #expect(try TransactionId.fromJSON(txId.toJSON()!) == txId)
        #expect(try ScriptHash.fromJSON(scriptHash.toJSON()!) == scriptHash)
        #expect(try TransactionId.fromJSON("\"\(String(repeating: "01", count: 32))\"") == txId)
    }

    @Test("An operational certificate round-trips through JSON with its cold key")
    func operationalCertificateJSON() throws {
        let cold = try StakePoolKeyPair.generate()
        var counter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: cold.verificationKey)
        let certificate = try OperationalCertificate.issue(
            kesVerificationKey: KESKeyPair.generate().verificationKey,
            coldSigningKey: cold.signingKey,
            operationalCertificateIssueCounter: &counter,
            kesPeriod: 42)

        let json = try #require(try certificate.toJSON())
        let restored = try OperationalCertificate.fromJSON(json)
        #expect(restored == certificate)
        #expect(restored.coldVerificationKey == cold.verificationKey)
        #expect(try restored.toCBORHex() == certificate.toCBORHex())
        #expect(json.contains(certificate.sigma.toHex))

        // Without the cold key, as an on-chain certificate is.
        let onChain = try OperationalCertificate(
            hotVKey: certificate.hotVKey, sequenceNumber: 1, kesPeriod: 2, sigma: certificate.sigma)
        let restoredOnChain = try OperationalCertificate.fromJSON(onChain.toJSON()!)
        #expect(restoredOnChain == onChain)
        #expect(restoredOnChain.coldVerificationKey == nil)
    }

    @Test("A witness signature written as hex is read as hex, not as base64")
    func witnessHexSignature() throws {
        let keyPair = try PaymentKeyPair.generate()
        let signature = try keyPair.signingKey.sign(data: Data("tx".utf8))
        let json = """
            {"vkey": "\(keyPair.verificationKey.payload.toHex)", "signature": "\(signature.toHex)"}
            """
        let witness = try VerificationKeyWitness.fromJSON(json)
        #expect(witness.signature == signature)

        let written = VerificationKeyWitness(vkey: .verificationKey(keyPair.verificationKey), signature: signature)
        #expect(try VerificationKeyWitness.fromJSON(written.toJSON()!) == written)
    }

    @Test("Credentials and anchors round-trip through JSON", arguments: [false, true])
    func credentialAndAnchorJSON(script: Bool) throws {
        let hash = Data(repeating: 0x5a, count: 28)
        let credential = StakeCredential(credential: script
            ? .scriptHash(try ScriptHash(payload: hash))
            : .verificationKeyHash(try VerificationKeyHash(payload: hash)))
        let json = try #require(try credential.toJSON())
        #expect(json == "{\"\(script ? "scriptHash" : "keyHash")\":\"\(hash.toHex)\"}")
        #expect(try StakeCredential.fromJSON(json) == credential)

        let drep = DRepCredential(credential: credential.credential)
        #expect(try DRepCredential.fromJSON(drep.toJSON()!) == drep)

        let anchor = Anchor(
            anchorUrl: try Url("https://example.com/a.json"),
            anchorDataHash: AnchorDataHash(payload: Data(repeating: 0x33, count: 32)))
        #expect(try Anchor.fromJSON(anchor.toJSON()!) == anchor)
    }

    @Test("JSON writes bytes as hex, and still reads the base64 earlier versions wrote")
    func jsonBytesAreHex() throws {
        let hash = Data(repeating: 0xab, count: 32)
        let anchor = Anchor(anchorUrl: try Url("https://example.com/a.json"), anchorDataHash: AnchorDataHash(payload: hash))
        let json = try #require(try anchor.toJSON())
        #expect(json.contains(hash.toHex))
        let legacy = json.replacingOccurrences(of: hash.toHex, with: hash.base64EncodedString())
        #expect(try Anchor.fromJSON(legacy) == anchor)
    }

    @Test("Governance ids, votes, intervals and relays round-trip through JSON")
    func governanceAndPoolJSON() throws {
        let action = GovActionID(transactionID: try TransactionId(payload: Data(repeating: 4, count: 32)), govActionIndex: 3)
        #expect(try action.toJSON() == "{\"govActionIndex\":3,\"transactionId\":\"\(String(repeating: "04", count: 32))\"}")
        #expect(try GovActionID.fromJSON(action.toJSON()!) == action)

        let interval = UnitInterval(numerator: 3, denominator: 100)
        #expect(try interval.toJSON() == "{\"denominator\":100,\"numerator\":3}")
        #expect(try UnitInterval.fromJSON(interval.toJSON()!) == interval)
        #expect(throws: CardanoCoreError.self) { try UnitInterval.fromJSON("{\"numerator\":3,\"denominator\":2}") }

        for vote in [Vote.no, .yes, .abstain] {
            #expect(try Vote.fromJSON(vote.toJSON()!) == vote)
        }
        let voter = Voter(credential: .drepKeyhash(try VerificationKeyHash(payload: Data(repeating: 7, count: 28))))
        let procedures = VotingProcedures([voter: [action: VotingProcedure(vote: .yes)]])
        #expect(try VotingProcedures.fromJSON(procedures.toJSON()!) == procedures)

        let relays: [Relay] = [
            .singleHostAddr(SingleHostAddr(port: 3001, ipv4: IPv4Address("192.0.2.1"), ipv6: nil)),
            .singleHostName(try SingleHostName(port: nil, dnsName: "relay.example.com")),
            .multiHostName(try MultiHostName(dnsName: "pool.example.com")),
        ]
        for relay in relays {
            #expect(try Relay.fromJSON(relay.toJSON()!) == relay)
        }
    }

    @Test("A JSON boolean is read as a boolean")
    func jsonBooleans() throws {
        let tx = Transaction(
            transactionBody: TransactionBody(
                inputs: .list([TransactionInput(transactionId: TransactionId(payload: Data(count: 32)), index: 0)]),
                outputs: [], fee: 1),
            transactionWitnessSet: TransactionWitnessSet(),
            valid: false)
        let restored = try Transaction.fromJSON(tx.toJSON()!)
        #expect(restored.valid == false)
        #expect(restored == tx)
    }

    @Test("Loading a file that is not there throws ioError, whatever the type")
    func missingFilesThrowIOError() throws {
        let path = NSTemporaryDirectory() + "missing-\(UUID().uuidString)"
        func expectIOError(_ load: () throws -> Any) {
            do {
                _ = try load()
                Issue.record("Expected ioError, but the load succeeded")
            } catch CardanoCoreError.ioError(let message) {
                #expect(message?.contains(path) == true)
            } catch {
                Issue.record("Expected ioError, got \(error)")
            }
        }
        expectIOError { try PaymentSigningKey.load(from: path) }
        expectIOError { try PaymentVerificationKey.load(from: path) }
        expectIOError { try SigningKeyType.load(from: path) }
        expectIOError { try VerificationKeyType.load(from: path) }
        expectIOError { try Transaction.load(from: path) }
        expectIOError { try OperationalCertificate.load(from: path) }
        expectIOError { try OperationalCertificateIssueCounter.load(from: path) }
        expectIOError { try Address.load(from: path) }
        expectIOError { try PoolOperator.load(from: path) }
        expectIOError { try DRep.load(from: path) }
        expectIOError { try Register.load(from: path) }
    }

    @Test("A key file is read only as the type of key it holds")
    func keyFilesMustMatchTheirType() throws {
        let directory = NSTemporaryDirectory() + "keys-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let keyPair = try PaymentKeyPair.generate()
        let skeyPath = directory + "payment.skey", vkeyPath = directory + "payment.vkey"
        try keyPair.signingKey.save(to: skeyPath)
        try keyPair.verificationKey.save(to: vkeyPath)

        #expect(try PaymentSigningKey.load(from: skeyPath) == keyPair.signingKey)
        #expect(try PaymentVerificationKey.load(from: vkeyPath) == keyPair.verificationKey)
        #expect(throws: CardanoCoreError.self) { try PaymentVerificationKey.load(from: skeyPath) }
        #expect(throws: CardanoCoreError.self) { try StakeSigningKey.load(from: skeyPath) }
        #expect(throws: CardanoCoreError.self) { try PaymentSigningKey.load(from: vkeyPath) }
        // The untyped key reads any signing key file.
        #expect(try SigningKey.load(from: skeyPath).payload == keyPair.signingKey.payload)
    }

    @Test("Issuing refuses a counter kept for another pool's cold key")
    func issueChecksTheCounterColdKey() throws {
        let cold = try StakePoolKeyPair.generate()
        var otherPoolCounter = try OperationalCertificateIssueCounter.createNewCounter(
            coldVerificationKey: StakePoolKeyPair.generate().verificationKey)
        #expect(throws: CardanoCoreError.self) {
            try OperationalCertificate.issue(
                kesVerificationKey: KESKeyPair.generate().verificationKey,
                coldSigningKey: cold.signingKey,
                operationalCertificateIssueCounter: &otherPoolCounter,
                kesPeriod: 0)
        }
        #expect(otherPoolCounter.counterValue == 0)
    }
}
