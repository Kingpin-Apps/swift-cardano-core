import Foundation
import Testing
import PotentCBOR
@testable import SwiftCardanoCore

var paymentVerificationKey: PaymentVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: paymentVerificationKeyFilePath.forResource,
            ofType: paymentVerificationKeyFilePath.ofType,
            inDirectory: paymentVerificationKeyFilePath.inDirectory
        )
        return try PaymentVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var stakeVerificationKey: StakeVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: stakeVerificationKeyFilePath.forResource,
            ofType: stakeVerificationKeyFilePath.ofType,
            inDirectory: stakeVerificationKeyFilePath.inDirectory
        )
        return try StakeVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var committeeColdVerificationKey: CommitteeColdVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: committeeColdVerificationKeyFilePath.forResource,
            ofType: committeeColdVerificationKeyFilePath.ofType,
            inDirectory: committeeColdVerificationKeyFilePath.inDirectory
        )
        return try CommitteeColdVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var committeeColdSigningKey: CommitteeColdSigningKey? {
    do {
        let keyPath = try getFilePath(
            forResource: committeeColdSigningKeyFilePath.forResource,
            ofType: committeeColdSigningKeyFilePath.ofType,
            inDirectory: committeeColdSigningKeyFilePath.inDirectory
        )
        return try CommitteeColdSigningKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var committeeHotVerificationKey: CommitteeHotVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: committeeHotVerificationKeyFilePath.forResource,
            ofType: committeeHotVerificationKeyFilePath.ofType,
            inDirectory: committeeHotVerificationKeyFilePath.inDirectory
        )
        return try CommitteeHotVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var committeeHotSigningKey: CommitteeHotSigningKey? {
    do {
        let keyPath = try getFilePath(
            forResource: committeeHotSigningKeyFilePath.forResource,
            ofType: committeeHotSigningKeyFilePath.ofType,
            inDirectory: committeeHotSigningKeyFilePath.inDirectory
        )
        return try CommitteeHotSigningKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var stakePoolVerificationKey: StakePoolVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: stakePoolVerificationKeyFilePath.forResource,
            ofType: stakePoolVerificationKeyFilePath.ofType,
            inDirectory: stakePoolVerificationKeyFilePath.inDirectory
        )
        return try StakePoolVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var stakePoolSigningKey: StakePoolSigningKey? {
    do {
        let keyPath = try getFilePath(
            forResource: stakePoolSigningKeyFilePath.forResource,
            ofType: stakePoolSigningKeyFilePath.ofType,
            inDirectory: stakePoolSigningKeyFilePath.inDirectory
        )
        return try StakePoolSigningKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var vrfVerificationKey: VRFVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: vrfVerificationKeyFilePath.forResource,
            ofType: vrfVerificationKeyFilePath.ofType,
            inDirectory: vrfVerificationKeyFilePath.inDirectory
        )
        return try VRFVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var vrfSigningKey: VRFSigningKey? {
    do {
        let keyPath = try getFilePath(
            forResource: vrfSigningKeyFilePath.forResource,
            ofType: vrfSigningKeyFilePath.ofType,
            inDirectory: vrfSigningKeyFilePath.inDirectory
        )
        return try VRFSigningKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var drepVerificationKey: DRepVerificationKey? {
    do {
        let keyPath = try getFilePath(
            forResource: drepVerificationKeyFilePath.forResource,
            ofType: drepVerificationKeyFilePath.ofType,
            inDirectory: drepVerificationKeyFilePath.inDirectory
        )
        return try DRepVerificationKey.load(from: keyPath!)
    } catch {
        return nil
    }
}

var drepSigningKey: DRepSigningKey? {
    do {
        let keyPath = try getFilePath(
            forResource: drepSigningKeyFilePath.forResource,
            ofType: drepSigningKeyFilePath.ofType,
            inDirectory: drepSigningKeyFilePath.inDirectory
        )
        return try DRepSigningKey.load(from: keyPath!)
    } catch {
        return nil
    }
}
