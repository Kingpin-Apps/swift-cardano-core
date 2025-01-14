import Foundation


// MARK: - Address
/// A shelley address. It consists of two parts: payment part and staking part.
/// Either of the parts could be None, but they cannot be None at the same time.
/// - Parameters:
///  - paymentPart: The payment part of the address.
///  - stakingPart: The staking part of the address.
///  - network: Type of network the address belongs to.
struct Address: CBORSerializable, CustomStringConvertible, Equatable, Hashable {
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
        
        throw CardanoCoreError.invalidAddressInputError(
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
        if let paymentPart = paymentPart {
            switch paymentPart {
                case .verificationKeyHash(let verificationKeyHash):
                    paymentData = verificationKeyHash.payload
                case .scriptHash(let scriptHash):
                    paymentData = scriptHash.payload
            }
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
    
    /// Encode the address in Bech32 format.
    ///
    /// More info about Bech32 (here)[https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki#Bech32].

    /// - Returns: Encoded address in Bech32.
    func encode() throws -> String {
        guard let encoded =  Bech32().encode(hrp: self.hrp, witprog: self.toPrimitive()) else {
            throw CardanoCoreError.encodingError("Error encoding data: \(self.toPrimitive())")
        }
        return encoded
    }
    
    /// Decode a bech32 string into an address object.
    /// - Parameter data: Bech32-encoded string.
    /// - Returns: Decoded address.
    /// - Throws: CardanoException when the input string is not a valid Shelley address.
    static func decode(_ data: String) throws -> Address {
        return try Address.fromPrimitive(data)
    }
    
    func toShallowPrimitive() -> Any {
        return self.toBytes()
    }
    
    func toPrimitive() -> Data {
        return self.toBytes()
    }

    static func fromPrimitive<T>(_ value: Any) throws -> T {
        guard let bech32 = Bech32().decode(addr: value as! String) else {
            throw CardanoCoreError.decodingError("Error decoding data: \(value)")
        }
        let data = Data(bech32)
        
        return try self.fromPrimitive(data: data) as! T
    }
    
    static func fromPrimitive(data: Data) throws -> Address {
        let header = data[0]
        let payload = data.dropFirst()
        
        let addrBits = (UInt8(header) & 0xF0) >> 4
        let networkBits = UInt8(header & 0x0F)
        
        guard let addrType = AddressType(rawValue: Int(addrBits)) else {
            throw CardanoCoreError.invalidAddressInputError("Invalid address type in header: \(header)")
        }
        guard let network = Network(rawValue: Int(networkBits)) else {
            throw CardanoCoreError.invalidAddressInputError("Invalid network in header: \(header)")
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
            throw CardanoCoreError.deserializeError("Error in deserializing bytes: \(data)")
        }
        
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(toBytes())
    }
}
