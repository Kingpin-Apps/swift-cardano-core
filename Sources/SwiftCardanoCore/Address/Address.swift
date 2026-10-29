import Foundation


// MARK: - Address
/// A shelley address. It consists of two parts: payment part and staking part.
/// Either of the parts could be None, but they cannot be None at the same time.
/// - Parameters:
///  - paymentPart: The payment part of the address.
///  - stakingPart: The staking part of the address.
///  - network: Type of network the address belongs to.
public struct Address: CBORSerializable, CustomStringConvertible, Equatable, Sendable {
    /// The payment part of the address.
    public var paymentPart: PaymentPart? { get { return _paymentPart } }
    private let _paymentPart: PaymentPart?
    
    /// The staking part of the address.
    public var stakingPart: StakingPart? { get { return _stakingPart } }
    private let _stakingPart: StakingPart?
    
    /// The network the address belongs to.
    public var network: NetworkId { get { return _network } }
    private let _network: NetworkId
    
    /// The type of the address.
    public var addressType: AddressType? { get { return _addressType } }
    private let _addressType: AddressType
    
    /// The header byte of the address.
    public var headerByte: Data { get { return _headerByte } }
    private let _headerByte: Data
    
    /// The human-readable prefix of the address.
    public var hrp: String { get { return _hrp } }
    private let _hrp: String

    /// The Byron address wrapped by this `Address`, or `nil` for Shelley addresses.
    ///
    /// Check this property to access Byron-specific fields (root key hash, HD attributes, address sub-type).
    public var byronAddress: ByronAddress? { get { return _byronAddress } }
    private let _byronAddress: ByronAddress?

    /// Bytes that followed the address where it was read, which the ledger
    /// before Babbage did not check for and ignored (`fromCborBackwardsBothAddr`,
    /// `libs/cardano-ledger-core/src/Cardano/Ledger/Address.hs`).
    ///
    /// They are not part of the address the ledger holds — ``ledgerBytes``,
    /// ``toBech32()``, `==` and hashing leave them out — but ``toBytes()``
    /// keeps them, so the address is written again exactly as it was read.
    /// Empty for every address read under Babbage or later rules, and for
    /// every address built from its parts.
    public var trailingBytes: Data { _trailingBytes }
    private var _trailingBytes = Data()

    /// Initialize a shelley address from its parts.
    ///
    /// The address type is inferred from the payment part and staking part. If the address type cannot be inferred, an error is thrown.
    ///
    ///  ```swift
    ///  let paymentPart = PaymentPart.verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)))
    ///  let stakingPart = StakingPart.verificationKeyHash(VerificationKeyHash(payload: Data(repeating: 0, count: VERIFICATION_KEY_HASH_SIZE)))
    ///  let address = try Address(paymentPart: paymentPart, stakingPart: stakingPart, network: .testnet)
    ///  ```
    ///
    /// - Parameters:
    ///   - paymentPart: The payment part of the address.
    ///   - stakingPart: The staking part of the address.
    ///   - network: Type of network the address belongs to.
    /// - Throws: `CardanoCoreError.invalidAddressInputError` when the address type cannot be inferred from the ``PaymentPart`` and ``StakingPart``.
    public init(paymentPart: PaymentPart? = nil, stakingPart: StakingPart? = nil, network: NetworkId = .mainnet) throws {
        _paymentPart = paymentPart
        _stakingPart = stakingPart
        _network = network
        _addressType = try Address.inferAddressType(paymentPart: paymentPart, stakingPart: stakingPart)
        _headerByte = Address.computeHeaderByte(addressType: _addressType, network: _network)
        _hrp = Address.computeHrp(addressType: _addressType, network: _network)
        _byronAddress = nil
    }

    /// Initialise an `Address` that wraps a Byron era address.
    ///
    /// Shelley-specific fields (`paymentPart`, `stakingPart`, `headerByte`, `hrp`) are
    /// left empty; callers should access Byron data via `byronAddress`.
    private init(byronAddress: ByronAddress) {
        _paymentPart = nil
        _stakingPart = nil
        _network = byronAddress.network
        _addressType = .byron
        _headerByte = Data()
        _hrp = ""
        _byronAddress = byronAddress
    }
    
    /// Initialize a shelley address from its bytes or bech32 string.
    ///
    /// The address type is inferred from the bytes. If the address type cannot be inferred, an error is thrown.
    /// ```swift
    /// let address = try Address(from: "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7")
    /// ```
    /// - Parameter primitive: The bytes or bech32 string.
    /// - Throws: `CardanoCoreError.decodingError` when the input is not a valid Shelley Address.
    /// - Throws: `CardanoCoreError.valueError` when the input is not a `Data` or `String`.
    public init(from primitive: Primitive) throws {
        let data: Data
        if case let .string(value) = primitive {
            if let bech32 = Bech32().decode(addr: value) {
                // Shelley address — Bech32 decoded successfully
                data = Data(bech32)
            } else {
                // Not a Bech32 string; attempt Base58 decoding (Byron address)
                do {
                    let byronAddr = try ByronAddress(from: .string(value))
                    self.init(byronAddress: byronAddr)
                    return
                } catch {
                    throw CardanoCoreError.decodingError(
                        "Address string is neither a valid Bech32 (Shelley) nor Base58 (Byron) address: \(value)"
                    )
                }
            }
        } else if case let .bytes(value) = primitive {
            data = value
        } else {
            throw CardanoCoreError.valueError("Invalid value type for Address")
        }

        guard !data.isEmpty else {
            throw CardanoCoreError.decodingError("Address byte data is empty")
        }

        let header = data[data.startIndex]
        // Re-based so that offsets into it start at 0.
        let payload = Data(data.dropFirst())

        let addrBits = (UInt8(header) & 0xF0) >> 4
        let networkBits = UInt8(header & 0x0F)

        // A Byron address is CBOR `[payload, crc]`, whose first byte is 0x82
        // (`headerByron`, `isByronAddress`, `Address.hs`).
        if header == 0x82 {
            let byronAddr = try ByronAddress(from: .bytes(data))
            self.init(byronAddress: byronAddr)
            return
        }

        guard addrBits != 0b1000, let addrType = AddressType(rawValue: Int(addrBits)) else {
            throw CardanoCoreError.invalidAddressInputError("Invalid address type in header: \(header)")
        }
        // Bits 1 to 3 of the header are unused (`headerNonShelleyBits`), so
        // the network is 0 or 1.
        guard let network = NetworkId(rawValue: Int(networkBits)) else {
            throw CardanoCoreError.invalidAddressInputError("Invalid network in header: \(header)")
        }

        let parts = try Address.readParts(addrType, payload)
        try self.init(paymentPart: parts.payment, stakingPart: parts.staking, network: network)
        _trailingBytes = parts.trailing
    }

    /// How the ledger reads the bytes of an address
    /// (`decodeAddrStateLenientT`, `libs/cardano-ledger-core/src/Cardano/Ledger/Address.hs`).
    enum DecodingRule {
        /// Before Babbage (protocol version 7) the ledger did not check that
        /// an address used every byte, and reads a pointer leniently
        /// (`fromCborBackwardsBothAddr`: `decodeAddrStateLenientT True True`).
        /// Mainnet has outputs with bytes after the address.
        case backwards
        /// Babbage (protocol versions 7 and 8): every byte must be used, and a
        /// pointer is still read leniently (`fromCborRigorousBothAddr True`).
        case rigorous
        /// From Conway (protocol version 9): every byte must be used, and a
        /// pointer is read strictly (`fromCborRigorousBothAddr False`). This
        /// is also `decodeAddr`, the decoder for addresses placed on chain
        /// today.
        case strict

        static var current: DecodingRule {
            let era = Era.decodingRules
            if era < .babbage { return .backwards }
            if era < .conway { return .rigorous }
            return .strict
        }
    }

    /// Reads the payment and staking parts after the header byte, by the
    /// rule of the era decoding follows, returning the bytes after them that
    /// the ledger ignored.
    static func readParts(
        _ addrType: AddressType, _ payload: Data
    ) throws -> (payment: PaymentPart?, staking: StakingPart?, trailing: Data) {
        let rule = DecodingRule.current
        let size = VERIFICATION_KEY_HASH_SIZE

        func hash(at offset: Int) throws -> Data {
            // `decodeHash`: fewer than 28 bytes left fails in every era.
            guard payload.count >= offset + size else {
                throw CardanoCoreError.invalidAddressInputError(
                    "Invalid \(addrType) address: \(payload.count) bytes after the header")
            }
            return payload.subdata(in: offset..<(offset + size))
        }

        let payment: PaymentPart?
        let staking: StakingPart?
        let used: Int
        switch addrType {
        case .keyKey, .keyScript, .scriptKey, .scriptScript:
            let p = try hash(at: 0), s = try hash(at: size)
            payment = addrType == .keyKey || addrType == .keyScript
                ? .verificationKeyHash(VerificationKeyHash(payload: p)) : .scriptHash(ScriptHash(payload: p))
            staking = addrType == .keyKey || addrType == .scriptKey
                ? .verificationKeyHash(VerificationKeyHash(payload: s)) : .scriptHash(ScriptHash(payload: s))
            used = 2 * size
        case .keyPointer, .scriptPointer:
            let p = try hash(at: 0)
            payment = addrType == .keyPointer
                ? .verificationKeyHash(VerificationKeyHash(payload: p)) : .scriptHash(ScriptHash(payload: p))
            // `decodeStakeReference`: `decodePtrLenient` before protocol
            // version 9, `decodePtr` from it.
            let (pointer, consumed) = try PointerAddress.read(
                payload.subdata(in: size..<payload.count),
                rule: rule == .strict ? .strict : .lenient)
            staking = .pointerAddress(pointer)
            used = size + consumed
        case .keyNone, .scriptNone:
            let p = try hash(at: 0)
            payment = addrType == .keyNone
                ? .verificationKeyHash(VerificationKeyHash(payload: p)) : .scriptHash(ScriptHash(payload: p))
            staking = nil
            used = size
        case .noneKey, .noneScript:
            // An account (reward) address: the ledger decodes it with
            // `decodeAccountAddressT`, which requires every byte in every era.
            let s = try hash(at: 0)
            guard payload.count == size else {
                throw CardanoCoreError.invalidAddressInputError(
                    "Invalid \(addrType) address: \(payload.count) bytes after the header")
            }
            payment = nil
            staking = addrType == .noneKey
                ? .verificationKeyHash(VerificationKeyHash(payload: s)) : .scriptHash(ScriptHash(payload: s))
            used = size
        case .byron:
            throw CardanoCoreError.invalidAddressInputError("Invalid address type in header")
        }

        // `ensureBufIsConsumed`, skipped only before Babbage.
        if used != payload.count, rule != .backwards {
            throw CardanoCoreError.invalidAddressInputError(
                "Invalid \(addrType) address: \(payload.count - used) bytes left over after the address")
        }
        return (payment, staking, payload.subdata(in: used..<payload.count))
    }

    public func toPrimitive() -> Primitive {
        return .bytes(toBytes())
    }
    
    /// Codable implementation to decode the address (both Shelley and Byron).
    /// - Parameter decoder: The decoder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        self = try Address(from: .bytes(data))
    }
    
    /// Codable implementation to encode the address.
    /// - Parameter encoder: The encoder.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toBytes())
    }
    
    /// Infer the address type from the payment part and staking part.
    /// - Parameters:
    ///   - paymentPart: The payment part of the address.
    ///   - stakingPart: The staking part of the address.
    /// - Returns: The inferred address type.
    public static func inferAddressType(paymentPart: PaymentPart?, stakingPart: StakingPart?) throws -> AddressType {
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
    
    /// Compute the header byte for the address.
    /// - Parameters:
    ///   - addressType: Type of address.
    ///   - network: Type of network.
    /// - Returns: Data containing the header byte.
    public static func computeHeaderByte(addressType: AddressType, network: NetworkId) -> Data {
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
    public static func computeHrp(addressType: AddressType, network: NetworkId) -> String {
        let prefix = (addressType == .noneKey || addressType == .noneScript) ? "stake" : "addr"
        let suffix = (network == .mainnet) ? "" : "_test"
        return prefix + suffix
    }
    
    /// The human-readable description of the address.
    ///
    /// Returns a Base58 string for Byron addresses, or a Bech32 string for Shelley addresses.
    public var description: String {
        if let byronAddr = _byronAddress {
            return byronAddr.toBase58()
        }
        do {
            return try self.toBech32()
        } catch {
            return ""
        }
    }
    
    /// Convert the address to bytes, exactly as it was read.
    ///
    /// For Byron addresses, returns the raw on-chain CBOR bytes (`CBOR([payload, crc32])`).
    /// For Shelley addresses, returns `headerByte + paymentData + stakingData`,
    /// with a pointer as it was written and any ``trailingBytes`` after it.
    /// ``ledgerBytes`` is the address as the ledger holds it.
    /// - Returns: The bytes of the address.
    public func toBytes() -> Data {
        return shelleyBytes(asWritten: true)
    }

    /// The address as the ledger holds it once decoded: without
    /// ``trailingBytes``, and with a pointer written canonically, values the
    /// ledger replaced with `Ptr 0 0 0` included (`fromCborBothAddr`, which
    /// writes a pointer address again, and `fromCborBackwardsBothAddr`, which
    /// drops the bytes after the address; `Address.hs`).
    ///
    /// The same as ``toBytes()`` for every address that is canonical
    /// (``isLedgerCanonical``).
    public var ledgerBytes: Data {
        return shelleyBytes(asWritten: false)
    }

    /// Whether ``toBytes()`` is the address as the ledger holds it, with no
    /// trailing bytes and no pointer written other than canonically.
    public var isLedgerCanonical: Bool {
        return toBytes() == ledgerBytes
    }

    private func shelleyBytes(asWritten: Bool) -> Data {
        if let byronAddr = _byronAddress {
            return byronAddr.toBytes()
        }

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
                    stakingData = asWritten ? pointerAddress.encode() : pointerAddress.ledgerBytes
            }
        } else {
            stakingData = Data()
        }
        
        return headerByte + paymentData + stakingData + (asWritten ? _trailingBytes : Data())
    }
    
    /// Equatable implementation for Address: whether the ledger holds the
    /// two as the same address. ``trailingBytes`` and how a pointer was
    /// written do not count; compare ``toBytes()`` for that.
    /// - Parameters:
    ///   - lhs: The left-hand side address.
    ///   - rhs: The right-hand side address.
    /// - Returns: True if the addresses are equal, false otherwise.
    public static func == (lhs: Address, rhs: Address) -> Bool {
        // Byron vs. Byron: compare raw bytes
        if let lByron = lhs._byronAddress, let rByron = rhs._byronAddress {
            return lByron == rByron
        }
        // Mixed Byron / Shelley: never equal
        if lhs._byronAddress != nil || rhs._byronAddress != nil {
            return false
        }

        // Both Shelley: check if paymentPart is the same
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
    ///
    /// This is the address the ledger holds, ``ledgerBytes``: an address
    /// read with trailing bytes or an oddly written pointer shows as the
    /// ledger, and chain indexers, show it.
    /// - Returns: Encoded address in Bech32.
    public func toBech32() throws -> String {
        guard let encoded =  Bech32().encode(hrp: self.hrp, witprog: self.ledgerBytes) else {
            throw CardanoCoreError.encodingError("Error encoding data: \(self.ledgerBytes)")
        }
        return encoded
    }
    
    /// Decode a bech32 string into an address object.
    /// - Parameter data: Bech32-encoded string.
    /// - Returns: Decoded address.
    /// - Throws: CardanoException when the input string is not a valid Shelley address.
    public static func fromBech32(_ data: String) throws -> Address {
        return try Address(from: .string(data))
    }
    
    /// Hashable implementation for Address: the address as the ledger
    /// holds it, as `==` compares.
    /// - Parameter hasher: The hasher.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ledgerBytes)
    }
    
    /// Save the address to a file.
    /// - Parameters:
    ///  - path: The path to save the file
    ///  - overwrite: Whether to overwrite the file if it already exists.
    /// - Throws: `CardanoCoreError.ioError` when the file already exists and overwrite is false.
    public func save(to path: String, overwrite: Bool = false) throws {
        if !overwrite, FileManager.default.fileExists(atPath: path) {
            throw CardanoCoreError.ioError("File already exists: \(path)")
        }

        let addressString: String
        if let byronAddr = _byronAddress {
            addressString = byronAddr.toBase58()
        } else {
            addressString = try toBech32()
        }
        try addressString.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    /// Load the address from a file.
    /// - Parameter path: The file path.
    /// - Returns: The address restored from the file.
    /// - Throws: `CardanoCoreError.ioError` when the file does not exist.
    public static func load(from path: String) throws -> Address {
        guard FileManager.default.fileExists(atPath: path) else {
            throw CardanoCoreError.ioError("File not found: \(path)")
        }
        
        let bech32String = try String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        return try Address(from: .string(bech32String))
    }
}
