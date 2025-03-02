import Foundation


// MARK: - Address
/// A shelley address. It consists of two parts: payment part and staking part.
/// Either of the parts could be None, but they cannot be None at the same time.
/// - Parameters:
///  - paymentPart: The payment part of the address.
///  - stakingPart: The staking part of the address.
///  - network: Type of network the address belongs to.
public struct Address: Codable, CustomStringConvertible, Equatable, Hashable {
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
    
    public init(paymentPart: PaymentPart? = nil, stakingPart: StakingPart? = nil, network: Network = .mainnet) throws {
        _paymentPart = paymentPart
        _stakingPart = stakingPart
        _network = network
        _addressType = try Address.inferAddressType(paymentPart: paymentPart, stakingPart: stakingPart)
        _headerByte = Address.computeHeaderByte(addressType: _addressType, network: _network)
        _hrp = Address.computeHrp(addressType: _addressType, network: _network)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        self = try Address.fromPrimitive(data: data)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toBytes())
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
    public static func computeHrp(addressType: AddressType, network: Network) -> String {
        let prefix = (addressType == .noneKey || addressType == .noneScript) ? "stake" : "addr"
        let suffix = (network == .mainnet) ? "" : "_test"
        return prefix + suffix
    }
    
    public var description: String {
        do {
            return try self.toBech32()
        } catch {
            return ""
        }
        
    }
    
    public func toBytes() -> Data {
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
    
    public static func == (lhs: Address, rhs: Address) -> Bool {
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
    func toBech32() throws -> String {
        guard let encoded =  Bech32().encode(hrp: self.hrp, witprog: self.toBytes()) else {
            throw CardanoCoreError.encodingError("Error encoding data: \(self.toBytes())")
        }
        return encoded
    }
    
    /// Decode a bech32 string into an address object.
    /// - Parameter data: Bech32-encoded string.
    /// - Returns: Decoded address.
    /// - Throws: CardanoException when the input string is not a valid Shelley address.
    static func fromBech32(_ data: String) throws -> Address {
        return try Address.fromPrimitive(data)
    }

    static func fromPrimitive<T>(_ value: Any) throws -> T {
        let data: Data
        if let value = value as? String {
            guard let bech32 = Bech32().decode(addr: value) else {
                throw CardanoCoreError.decodingError("Error decoding data: \(value)")
            }
            data = Data(bech32)
        } else if let value = value as? Data {
            data = value
        } else {
            throw CardanoCoreError.valueError("Invalid value type for Address")
        }
        
        return try self.fromPrimitive(data: data) as! T
    }
    
    public static func fromPrimitive(data: Data) throws -> Address {
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
            let paymentPart = VerificationKeyHash(
                payload: payload.prefix(VERIFICATION_KEY_HASH_SIZE)
            )
            let stakingPart = VerificationKeyHash(
                payload: payload.suffix(VERIFICATION_KEY_HASH_SIZE)
            )
                
            return try Address(
                paymentPart: PaymentPart.verificationKeyHash(paymentPart),
                stakingPart: StakingPart.verificationKeyHash(stakingPart),
                network: network
            )
        case .keyScript:
            let paymentPart = VerificationKeyHash(
                payload: payload.prefix(VERIFICATION_KEY_HASH_SIZE)
            )
            let stakingPart = ScriptHash(
                payload: payload.suffix( VERIFICATION_KEY_HASH_SIZE)
            )
                
            return try Address(
                paymentPart: PaymentPart.verificationKeyHash(paymentPart),
                stakingPart: StakingPart.scriptHash(stakingPart),
                network: network
            )
        case .keyPointer:
            let paymentPart = VerificationKeyHash(
                payload: payload.prefix(VERIFICATION_KEY_HASH_SIZE)
            )
                let pointerAddr = try PointerAddress.decode(payload.suffix(from: VERIFICATION_KEY_HASH_SIZE + 1))
                
            return try Address(
                paymentPart: PaymentPart.verificationKeyHash(paymentPart),
                stakingPart: StakingPart.pointerAddress(pointerAddr),
                network: network
            )
        case .keyNone:
            let paymentPart = VerificationKeyHash(
                payload: payload
            )
                
            return try Address(
                paymentPart: PaymentPart.verificationKeyHash(paymentPart),
                stakingPart: nil, network: network
            )
        case .scriptKey:
            let paymentPart = ScriptHash(
                payload: payload.prefix(VERIFICATION_KEY_HASH_SIZE)
            )
            let stakingPart = VerificationKeyHash(
                payload: payload.suffix( VERIFICATION_KEY_HASH_SIZE)
            )
                
            return try Address(
                paymentPart: PaymentPart.scriptHash(paymentPart),
                stakingPart: StakingPart.verificationKeyHash(stakingPart),
                network: network
            )
        case .scriptScript:
            let paymentPart = ScriptHash(
                payload: payload.prefix(VERIFICATION_KEY_HASH_SIZE)
            )
            let stakingPart = ScriptHash(
                payload: payload.suffix( VERIFICATION_KEY_HASH_SIZE)
            )
            return try Address(
                paymentPart: PaymentPart.scriptHash(paymentPart),
                stakingPart: StakingPart.scriptHash(stakingPart),
                network: network
            )
        case .scriptPointer:
            let paymentPart = ScriptHash(
                payload: payload.prefix(VERIFICATION_KEY_HASH_SIZE)
            )
                
            let pointerAddr = try PointerAddress.decode(payload.suffix(from: VERIFICATION_KEY_HASH_SIZE + 1))
                
            return try Address(
                paymentPart: PaymentPart.scriptHash(paymentPart),
                stakingPart: StakingPart.pointerAddress(pointerAddr),
                network: network
            )
        case .scriptNone:
            let paymentPart = ScriptHash(
                payload: payload
            )
                
            return try Address(
                paymentPart: PaymentPart.scriptHash(paymentPart),
                stakingPart: nil,
                network: network
            )
        case .noneKey:
            let stakingPart = VerificationKeyHash(
                payload: payload
            )
            return try Address(
                paymentPart: nil,
                stakingPart: StakingPart.verificationKeyHash(stakingPart),
                network: network
            )
        case .noneScript:
            let stakingPart = ScriptHash(
                payload: payload
            )
            return try Address(
                paymentPart: nil,
                stakingPart: StakingPart.scriptHash(stakingPart),
                network: network
            )
        default:
            throw CardanoCoreError.deserializeError("Error in deserializing bytes: \(data)")
        }
        
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(toBytes())
    }
    
    public func save(to path: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            throw CardanoCoreError.ioError("File already exists: \(path)")
        }
        
        let bech32String = try toBech32()
        try bech32String.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    public static func load(from path: String) throws -> Address {
        guard FileManager.default.fileExists(atPath: path) else {
            throw CardanoCoreError.ioError("File not found: \(path)")
        }
        
        let bech32String = try String(contentsOfFile: path)
        return try Address.fromBech32(bech32String)
    }
}
