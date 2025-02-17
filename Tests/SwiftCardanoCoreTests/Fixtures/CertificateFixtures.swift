import Foundation
import Testing
import PotentCBOR
@testable import SwiftCardanoCore

var stakeRegistrationCertificate: StakeRegistration? {
    do {
        let certificatePath = try getFilePath(
            forResource: stakeRegistrationFilePath.forResource,
            ofType: stakeRegistrationFilePath.ofType,
            inDirectory: stakeRegistrationFilePath.inDirectory
        )
        return try StakeRegistration.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var authCommitteeCertificate: AuthCommitteeHot? {
    do {
        let certificatePath = try getFilePath(
            forResource: authCommitteeFilePath.forResource,
            ofType: authCommitteeFilePath.ofType,
            inDirectory: authCommitteeFilePath.inDirectory
        )
        return try AuthCommitteeHot.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var resignCommitteeColdCertificate: ResignCommitteeCold? {
    do {
        let certificatePath = try getFilePath(
            forResource: resignCommitteeColdFilePath.forResource,
            ofType: resignCommitteeColdFilePath.ofType,
            inDirectory: resignCommitteeColdFilePath.inDirectory
        )
        return try ResignCommitteeCold.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var poolRegistrationCertificate: PoolRegistration? {
    do {
        let certificatePath = try getFilePath(
            forResource: poolRegistrationFilePath.forResource,
            ofType: poolRegistrationFilePath.ofType,
            inDirectory: poolRegistrationFilePath.inDirectory
        )
        return try PoolRegistration.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var poolRetirementCertificate: PoolRetirement? {
    do {
        let certificatePath = try getFilePath(
            forResource: poolRetireFilePath.forResource,
            ofType: poolRetireFilePath.ofType,
            inDirectory: poolRetireFilePath.inDirectory
        )
        return try PoolRetirement.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var registerCertificate: Register? {
    do {
        let certificatePath = try getFilePath(
            forResource: registerFilePath.forResource,
            ofType: registerFilePath.ofType,
            inDirectory: registerFilePath.inDirectory
        )
        return try Register.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var registerDRepCertificate: RegisterDRep? {
    do {
        let certificatePath = try getFilePath(
            forResource: registerDRepFilePath.forResource,
            ofType: registerDRepFilePath.ofType,
            inDirectory: registerDRepFilePath.inDirectory
        )
        return try RegisterDRep.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var voteDelegateDRepCertificate: VoteDelegate? {
    do {
        let certificatePath = try getFilePath(
            forResource: voteDelegateDRepFilePath.forResource,
            ofType: voteDelegateDRepFilePath.ofType,
            inDirectory: voteDelegateDRepFilePath.inDirectory
        )
        return try VoteDelegate.load(from: certificatePath!)
    } catch {
        return nil
    }
}
var voteDelegateAlwaysAbstainCertificate: VoteDelegate? {
    do {
        let certificatePath = try getFilePath(
            forResource: voteDelegateAlwaysAbstainFilePath.forResource,
            ofType: voteDelegateAlwaysAbstainFilePath.ofType,
            inDirectory: voteDelegateAlwaysAbstainFilePath.inDirectory
        )
        return try VoteDelegate.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var voteDelegateAlwaysNoConfidenceCertificate: VoteDelegate? {
    do {
        let certificatePath = try getFilePath(
            forResource: voteDelegateAlwaysNoConfidenceFilePath.forResource,
            ofType: voteDelegateAlwaysNoConfidenceFilePath.ofType,
            inDirectory: voteDelegateAlwaysNoConfidenceFilePath.inDirectory
        )
        return try VoteDelegate.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var voteDelegateScriptCertificate: VoteDelegate? {
    do {
        let certificatePath = try getFilePath(
            forResource: voteDelegateScriptFilePath.forResource,
            ofType: voteDelegateScriptFilePath.ofType,
            inDirectory: voteDelegateScriptFilePath.inDirectory
        )
        return try VoteDelegate.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var stakeDelegationCertificate: StakeDelegation? {
    do {
        let certificatePath = try getFilePath(
            forResource: stakeDelegationFilePath.forResource,
            ofType: stakeDelegationFilePath.ofType,
            inDirectory: stakeDelegationFilePath.inDirectory
        )
        return try StakeDelegation.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var stakeUnregisterCertificate: Unregister? {
    do {
        let certificatePath = try getFilePath(
            forResource: stakeUnregisterFilePath.forResource,
            ofType: stakeUnregisterFilePath.ofType,
            inDirectory: stakeUnregisterFilePath.inDirectory
        )
        return try Unregister.load(from: certificatePath!)
    } catch {
        return nil
    }
}

var stakeDeregistrationCertificate: StakeDeregistration? {
    do {
        let certificatePath = try getFilePath(
            forResource: stakeDeregistrationFilePath.forResource,
            ofType: stakeDeregistrationFilePath.ofType,
            inDirectory: stakeDeregistrationFilePath.inDirectory
        )
        return try StakeDeregistration.load(from: certificatePath!)
    } catch {
        return nil
    }
}


var stakeRegisterDelegateCertificate: StakeRegisterDelegate? {
    do {
        let certificatePath = try getFilePath(
            forResource: stakeRegisterDelegateFilePath.forResource,
            ofType: stakeRegisterDelegateFilePath.ofType,
            inDirectory: stakeRegisterDelegateFilePath.inDirectory
        )
        return try StakeRegisterDelegate.load(from: certificatePath!)
    } catch {
        return nil
    }
}
