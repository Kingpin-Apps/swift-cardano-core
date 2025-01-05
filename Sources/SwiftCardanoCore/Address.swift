//
//  Created by Hareem Adderley on 29/06/2024 AT 6:28 PM
//  Copyright © 2024 Kingpin Apps. All rights reserved.
//  

import Foundation

enum PaymentPart {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
}

enum StakingPart {
    case verificationKeyHash(VerificationKeyHash)
    case scriptHash(ScriptHash)
    case pointerAddress(PointerAddress)
}

enum AddressFromPrimitiveData {
    case bytes(Data)
    case string(String)
}

/// Address type definition.
enum AddressType: Int {
    
    /// Byron address
    case byron = 0b1000
    
    /// Payment key hash + Stake key hash
    case keyKey = 0b0000
    
    /// Script hash + Stake key hash
    case scriptKey = 0b0001
    
    /// Payment key hash + Script hash
    case keyScript = 0b0010
    
    /// Script hash + Script hash
    case scriptScript = 0b0011
    
    /// Payment key hash + Pointer address
    case keyPointer = 0b0100
    
    /// Script hash + Pointer address
    case scriptPointer = 0b0101
    
    /// Payment key hash only
    case keyNone = 0b0110
    
    /// Script hash for payment part only
    case scriptNone = 0b0111
    
    /// Stake key hash for stake part only
    case noneKey = 0b1110
    
    /// Script hash for stake part only
    case noneScript = 0b1111
}

extension AddressType: CustomStringConvertible {
    var description: String {
        switch self {
        case .byron:
            return "byron"
        case .keyKey:
            return "keyKey"
        case .scriptKey:
            return "scriptKey"
        case .keyScript:
            return "keyScript"
        case .scriptScript:
            return "scriptScript"
        case .keyPointer:
            return "keyPointer"
        case .scriptPointer:
            return "scriptPointer"
        case .keyNone:
            return "keyNone"
        case .scriptNone:
            return "scriptNone"
        case .noneKey:
            return "noneKey"
        case .noneScript:
            return "noneScript"
        }
    }
}

/// Pointer address.
///
/// It refers to a point of the chain containing a stake key registration certificate.
///
/// - Parameters:
///  - slot: Slot in which the staking certificate was posted.
///  - txIndex: The transaction index (within that slot).
///  - certIndex: A (delegation) certificate index (within that transaction).
struct PointerAddress: CBORSerializable, Equatable {
    public var slot: Int { get { return _slot } }
    private let _slot: Int
    
    public var txIndex: Int { get { return _txIndex } }
    private let _txIndex: Int
    
    public var certIndex: Int { get { return _certIndex } }
    private let _certIndex: Int

    init(slot: Int, txIndex: Int, certIndex: Int) {
        self._slot = slot
        self._txIndex = txIndex
        self._certIndex = certIndex
    }

    private func encodeInt(_ n: Int) -> Data {
        var n = n
        var output = [UInt8]()
        output.append(UInt8(n & 0x7F))
        n >>= 7
        while n > 0 {
            output.append(0x80 | UInt8(n & 0x7F))
            n >>= 7
        }
        return Data(output.reversed())
    }
    
    /// Encode the pointer address to bytes.
    ///
    /// The encoding follows [CIP-0019#Pointers](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0019#pointers).
    /// - Returns: Encoded bytes.
    func encode() -> Data {
        return encodeInt(slot) + encodeInt(txIndex) + encodeInt(certIndex)
    }
    
    /// Decode bytes into a PointerAddress.
    /// - Parameter data: The data to be decoded.
    /// - Returns: Decoded pointer address.
    static func decode(_ data: Data) throws -> PointerAddress {
        var ints = [Int]()
        var curInt = 0
        for byte in data {
            curInt |= Int(byte & 0x7F)
            if byte & 0x80 == 0 {
                ints.append(curInt)
                curInt = 0
            } else {
                curInt <<= 7
            }
        }

        guard ints.count == 3 else {
            throw CardanoException.decodingException("Error in decoding data \(data) into a PointerAddress")
        }

        return PointerAddress(slot: ints[0], txIndex: ints[1], certIndex: ints[2])
    }

    // MARK: - CBORSerializable

    func toPrimitive() -> Data? {
        return encode()
    }

    static func fromPrimitive(_ value: Data) throws -> PointerAddress? {
        return try decode(value)
    }

    // MARK: - Equatable

    static func == (lhs: PointerAddress, rhs: PointerAddress) -> Bool {
        return lhs.slot == rhs.slot &&
               lhs.txIndex == rhs.txIndex &&
               lhs.certIndex == rhs.certIndex
    }

    // MARK: - CustomStringConvertible

    var description: String {
        return "PointerAddress(\(slot), \(txIndex), \(certIndex))"
    }
}

/// A shelley address. It consists of two parts: payment part and staking part.
/// Either of the parts could be None, but they cannot be None at the same time.
/// - Parameters:
///  - paymentPart: The payment part of the address.
///  - stakingPart: The staking part of the address.
///  - network: Type of network the address belongs to.
struct Address: CustomStringConvertible, Equatable {
    public var paymentPart: PaymentPart? { get { return _paymentPart } }
    private let _paymentPart: PaymentPart?
    
    public var stakingPart: StakingPart? { get { return _stakingPart } }
    private let _stakingPart: StakingPart?
    
    public var network: Network { get { return _network } }
    private let _network: Network
    
    public var addressType: AddressType? { get { return _addressType } }
    private let _addressType: AddressType
    
    public var headerByte: Data { get { return _headerByte } }
    private let _headerByte: Data
    
    public var hrp: String { get { return _hrp } }
    private let _hrp: String
    
    init(paymentPart: PaymentPart? = nil, stakingPart: StakingPart? = nil, network: Network = .mainnet) throws {
        _paymentPart = paymentPart
        _stakingPart = stakingPart
        _network = network
        _addressType = try Address.inferAddressType(paymentPart: paymentPart, stakingPart: stakingPart)
        _headerByte = Address.computeHeaderByte(addressType: _addressType, network: _network)
        _hrp = Address.computeHrp(addressType: _addressType, network: _network)
    }
    
    static func inferAddressType(paymentPart: PaymentPart?, stakingPart: StakingPart?) throws -> AddressType {
        switch paymentPart {
            case .verificationKeyHash:
                switch stakingPart {
                    case .verificationKeyHash:
                        return .keyKey
                    case .scriptHash:
                        return .keyScript
                    case .pointerAddress:
                        return .keyPointer
                    default:
                        if stakingPart == nil { return .keyNone }
                    }
            case .scriptHash:
                switch stakingPart {
                    case .verificationKeyHash:
                        return .scriptKey
                    case .scriptHash:
                        return .scriptScript
                    case .pointerAddress:
                        return .scriptPointer
                    default:
                        if stakingPart == nil { return .scriptNone }
                    }
            default:
                if paymentPart == nil {
                    switch stakingPart {
                        case .verificationKeyHash:
                            return .noneKey
                        case .scriptHash:
                            return .noneScript
                        default:
                            break
                        }
                }
        }
        
        throw CardanoException.invalidAddressInputException(
            "Cannot construct a shelley address from a combination of payment part: \(String(describing: paymentPart)) and stake part: \(String(describing: stakingPart))")
    }
    
    static func computeHeaderByte(addressType: AddressType, network: Network) -> Data {
        let header = (addressType.rawValue << 4 | network.rawValue)
        return Data([UInt8(header)])
    }
    
    /// Compute human-readable prefix for bech32 encoder.
    ///
    /// Based on [miscellaneous section](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0005#miscellaneous) in CIP-5.
    /// - Parameters:
    ///   - addressType: Type of address.
    ///   - network: Type of network
    /// - Returns: The human-readable prefix.
    static func computeHrp(addressType: AddressType, network: Network) -> String {
        let prefix = (addressType == .noneKey || addressType == .noneScript) ? "stake" : "addr"
        let suffix = (network == .mainnet) ? "" : "_test"
        return prefix + suffix
    }
    
    var description: String {
        do {
            return try self.encode()
        } catch {
            return ""
        }
        
    }
    
    func toBytes() -> Data {
        let paymentData: Data
        if let paymentPart = paymentPart as? any ConstrainedBytes {
            paymentData = paymentPart.payload
        } else {
            paymentData = Data()
        }
        
        let stakingData: Data
        if let stakingPart = stakingPart {
            switch stakingPart {
            case .verificationKeyHash(let verificationKeyHash):
                stakingData = verificationKeyHash.payload
            case .scriptHash(let scriptHash):
                stakingData = scriptHash.payload
            case .pointerAddress(let pointerAddress):
                stakingData = pointerAddress.encode()
            }
        } else {
            stakingData = Data()
        }
        
        return headerByte + paymentData + stakingData
    }
    
    static func == (lhs: Address, rhs: Address) -> Bool {
        // Check if paymentPart is the same
        let paymentCheck: Bool
        switch (lhs.paymentPart, rhs.paymentPart) {
            case (.verificationKeyHash(let lhsPayment), .verificationKeyHash(let rhsPayment)):
                paymentCheck = lhsPayment.payload == rhsPayment.payload
            case (.scriptHash(let lhsPayment), .scriptHash(let rhsPayment)):
                paymentCheck = lhsPayment.payload == rhsPayment.payload
            case (nil, nil):
                paymentCheck = true
            default:
                paymentCheck = false
        }
        
        // Check if stakingPart is the same
        let stakingCheck: Bool
        switch (lhs.stakingPart, rhs.stakingPart) {
            case (.verificationKeyHash(let lhsStaking), .verificationKeyHash(let rhsStaking)):
                stakingCheck = lhsStaking.payload == rhsStaking.payload
            case (.scriptHash(let lhsStaking), .scriptHash(let rhsStaking)):
                stakingCheck = lhsStaking.payload == rhsStaking.payload
            case (.pointerAddress(let lhsStaking), .pointerAddress(let rhsStaking)):
                stakingCheck = lhsStaking == rhsStaking
            case (nil, nil):
                stakingCheck = true
            default:
                stakingCheck = false
        }
        
        // Check if network is the same
        let networkCheck = lhs.network == rhs.network
        
        return paymentCheck && stakingCheck && networkCheck
    }
    
    func encode() throws -> String {
        guard let encoded =  Bech32().encode(hrp: self.hrp, witprog: self.toPrimitive()) else {
            throw CardanoException.encodingException("Error encoding data: \(self.toPrimitive())")
        }
        return encoded
    }
    
    static func decode(_ data: String) throws -> Address {
        return try Address.fromPrimitive(data: data) // Placeholder for Bech32 decoding logic
    }
    
    func toPrimitive() -> Data {
        return self.toBytes()
    }
    
    static func fromPrimitive(data: String) throws -> Address {
        guard let bech32 = Bech32().decode(addr: data) else {
            throw CardanoException.decodingException("Error decoding data: \(data)")
        }
        let value = Data(bech32)
        
        return try self.fromPrimitive(data: value)
    }
    
    static func fromPrimitive(data: Data) throws -> Address {
        let header = data[0]
        let payload = data.dropFirst()
        
        let addrBits = (UInt8(header) & 0xF0) >> 4
        let networkBits = UInt8(header & 0x0F)
        
        guard let addrType = AddressType(rawValue: Int(addrBits)) else {
            throw CardanoException.invalidAddressInputException("Invalid address type in header: \(header)")
        }
        guard let network = Network(rawValue: Int(networkBits)) else {
            throw CardanoException.invalidAddressInputException("Invalid network in header: \(header)")
        }
        
        switch addrType {
        case .keyKey:
            let paymentPart = try VerificationKeyHash(payload: payload.prefix(VERIFICATION_KEY_HASH_SIZE))
            let stakingPart = try VerificationKeyHash(payload: payload.suffix(from: VERIFICATION_KEY_HASH_SIZE))
            return try Address(paymentPart: PaymentPart.verificationKeyHash(paymentPart), stakingPart: StakingPart.verificationKeyHash(stakingPart), network: network)
        case .keyScript:
            let paymentPart = try VerificationKeyHash(payload: payload.prefix(VERIFICATION_KEY_HASH_SIZE))
            let stakingPart = try ScriptHash(payload: payload.suffix(from: VERIFICATION_KEY_HASH_SIZE))
            return try Address(paymentPart: PaymentPart.verificationKeyHash(paymentPart), stakingPart: StakingPart.scriptHash(stakingPart), network: network)
        case .keyPointer:
            let paymentPart = try VerificationKeyHash(payload: payload.prefix(VERIFICATION_KEY_HASH_SIZE))
            let pointerAddr = try PointerAddress.decode(payload.suffix(from: VERIFICATION_KEY_HASH_SIZE))
            return try Address(paymentPart: PaymentPart.verificationKeyHash(paymentPart), stakingPart: StakingPart.pointerAddress(pointerAddr), network: network)
        case .keyNone:
            let paymentPart = try VerificationKeyHash(payload: payload)
            return try Address(paymentPart: PaymentPart.verificationKeyHash(paymentPart), stakingPart: nil, network: network)
        case .scriptKey:
            let paymentPart = try ScriptHash(payload: payload.prefix(VERIFICATION_KEY_HASH_SIZE))
            let stakingPart = try VerificationKeyHash(payload: payload.suffix(from: VERIFICATION_KEY_HASH_SIZE))
            return try Address(paymentPart: PaymentPart.scriptHash(paymentPart), stakingPart: StakingPart.verificationKeyHash(stakingPart), network: network)
        case .scriptScript:
            let paymentPart = try ScriptHash(payload: payload.prefix(VERIFICATION_KEY_HASH_SIZE))
            let stakingPart = try ScriptHash(payload: payload.suffix(from: VERIFICATION_KEY_HASH_SIZE))
            return try Address(paymentPart: PaymentPart.scriptHash(paymentPart), stakingPart: StakingPart.scriptHash(stakingPart), network: network)
        case .scriptPointer:
            let paymentPart = try ScriptHash(payload: payload.prefix(VERIFICATION_KEY_HASH_SIZE))
            let pointerAddr = try PointerAddress.decode(payload.suffix(from: VERIFICATION_KEY_HASH_SIZE))
            return try Address(paymentPart: PaymentPart.scriptHash(paymentPart), stakingPart: StakingPart.pointerAddress(pointerAddr), network: network)
        case .scriptNone:
            let paymentPart = try ScriptHash(payload: payload)
            return try Address(paymentPart: PaymentPart.scriptHash(paymentPart), stakingPart: nil, network: network)
        case .noneKey:
            let stakingPart = try VerificationKeyHash(payload: payload)
            return try Address(paymentPart: nil, stakingPart: StakingPart.verificationKeyHash(stakingPart), network: network)
        case .noneScript:
            let stakingPart = try ScriptHash(payload: payload)
            return try Address(paymentPart: nil, stakingPart: StakingPart.scriptHash(stakingPart), network: network)
        default:
            throw CardanoException.deserializeException("Error in deserializing bytes: \(data)")
        }
        
    }
}
