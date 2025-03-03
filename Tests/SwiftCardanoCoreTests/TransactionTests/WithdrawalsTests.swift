import Foundation
import Testing
@testable import SwiftCardanoCore

@Suite("Withdrawals Tests")
struct WithdrawalsTests {
    @Test("Initialization with dictionary")
    func testInitialization() throws {
        let rewardAccount = RewardAccount(Data([1, 2, 3]))
        let coin = Coin(1000)
        let withdrawals = Withdrawals([rewardAccount: coin])
        
        #expect(withdrawals[rewardAccount] == coin)
        #expect(withdrawals.data[rewardAccount] == coin)
    }
    
    @Test("Empty initialization")
    func testEmptyInitialization() throws {
        let withdrawals = Withdrawals([:])
        #expect(withdrawals.data.isEmpty)
    }
    
    @Test("Encoding and decoding")
    func testEncodingAndDecoding() throws {
        let rewardAccount = RewardAccount(Data([1, 2, 3]))
        let coin = Coin(1000)
        let originalWithdrawals = Withdrawals([rewardAccount: coin])
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let encoded = try encoder.encode(originalWithdrawals)
        let decodedWithdrawals = try decoder.decode(Withdrawals.self, from: encoded)
        
        #expect(decodedWithdrawals[rewardAccount] == coin)
        #expect(decodedWithdrawals.data == originalWithdrawals.data)
    }
    
    @Test("Subscript access")
    func testSubscriptAccess() throws {
        let rewardAccount = RewardAccount(Data([1, 2, 3]))
        let coin = Coin(1000)
        var withdrawals = Withdrawals([:])
        
        withdrawals[rewardAccount] = coin
        #expect(withdrawals[rewardAccount] == coin)
        
        withdrawals[rewardAccount] = nil
        #expect(withdrawals[rewardAccount] == nil)
    }
    
    @Test("Data property access")
    func testDataPropertyAccess() throws {
        let rewardAccount = RewardAccount(Data([1, 2, 3]))
        let coin = Coin(1000)
        var withdrawals = Withdrawals([:])
        
        withdrawals.data[rewardAccount] = coin
        #expect(withdrawals[rewardAccount] == coin)
        
        withdrawals.data.removeAll()
        #expect(withdrawals.data.isEmpty)
    }
} 
