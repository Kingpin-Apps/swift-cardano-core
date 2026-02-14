import Foundation
import PotentCBOR
import OrderedCollections

/// Manages the issue counter for Cardano Stake Pool Operational Certificates.
///
/// The counter must be incremented strictly by one for each new OpCert to avoid
/// `CounterTooSmallOCert` or `CounterOverIncrementedOCERT` errors on the node.
///
/// CDDL Specification:
/// ```
/// operational_cert_issue_counter = [
///   uint                   ; The current counter value
///   verification_key_hash, ; The hash of the pool's cold verification key
/// ]
/// ```
public struct OperationalCertificateIssueCounter: TextEnvelopable, JSONSerializable, Sendable {
    
    // MARK: - PayloadSerializable Properties
    
    public var _payload: Data
    public var _type: String
    public var _description: String
    
    public static var TYPE: String { "NodeOperationalCertificateIssueCounter" }
    public static var DESCRIPTION: String { "Next certificate issue number: 0" }
    
    /// Custom description for display (resolves protocol conflict).
    public var description: String { _description }
    
    // MARK: - Properties
    
    /// The current counter value.
    public private(set) var counterValue: UInt
    
    /// The pool's cold verification key.
    public let coldVerificationKey: StakePoolVerificationKey
    
    // MARK: - Initialization
    
    /// Creates a new `OperationalCertificateIssueCounter` with the given counter value and cold verification key.
    /// - Parameters:
    ///   - counterValue: The counter value.
    ///   - coldVerificationKey: The pool's cold verification key.
    public init(counterValue: UInt, coldVerificationKey: StakePoolVerificationKey) throws {
        self.counterValue = counterValue
        self.coldVerificationKey = coldVerificationKey
        self._type = Self.TYPE
        self._description = "Next certificate issue number: \(counterValue)"
        
        // Compute CBOR payload
        let primitive: Primitive = .list([
            .uint(counterValue),
            .bytes(coldVerificationKey.payload)
        ])
        self._payload = try CBOREncoder().encode(primitive)
    }
    
    /// Creates a new `OperationalCertificateIssueCounter` from a CBOR payload.
    /// - Parameters:
    ///   - payload: The CBOR-encoded payload.
    ///   - type: Optional type string (defaults to `TYPE`).
    ///   - description: Optional description string.
    /// - Throws: `CardanoCoreError.deserializeError` if the payload is invalid.
    public init(payload: Data, type: String?, description: String?) throws {
        let primitive = try CBORDecoder().decode(Primitive.self, from: payload)
        
        guard case let .list(elements) = primitive, elements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "Invalid OperationalCertificateIssueCounter CBOR: expected array of 2 elements"
            )
        }
        
        let counter: UInt
        switch elements[0] {
        case .uint(let value):
            counter = value
        case .int(let value) where value >= 0:
            counter = UInt(value)
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid counter value: expected uint, got \(elements[0])"
            )
        }
        
        guard case let .bytes(vkey) = elements[1] else {
            throw CardanoCoreError.deserializeError(
                "Invalid verification key: expected bytes, got \(elements[1])"
            )
        }
        
        self.counterValue = counter
        self.coldVerificationKey = try StakePoolVerificationKey(payload: vkey)
        self._payload = payload
        self._type = type ?? Self.TYPE
        self._description = description ?? "Next certificate issue number: \(counter)"
    }
    
    // MARK: - Factory Methods
    
    /// Creates a new counter with value 0 for the given cold verification key.
    /// - Parameter coldVerificationKey: The pool's cold verification key.
    /// - Returns: A new `OperationalCertificateIssueCounter` with counter value 0.
    public static func createNewCounter(coldVerificationKey: StakePoolVerificationKey) throws -> OperationalCertificateIssueCounter {
        return try OperationalCertificateIssueCounter(
            counterValue: 0,
            coldVerificationKey: coldVerificationKey
        )
    }
    
    // MARK: - Counter Operations
    
    /// Increments the counter value by 1.
    /// - Throws: `CardanoCoreError` if CBOR encoding fails.
    public mutating func increment() throws {
        counterValue += 1
        _description = "Next certificate issue number: \(counterValue)"
        
        // Recompute CBOR payload
        let primitive: Primitive = .list([
            .uint(counterValue),
            .bytes(coldVerificationKey.payload)
        ])
        _payload = try CBOREncoder().encode(primitive)
    }
    
    // MARK: - Validation
    
    /// Validates that the cold verification key matches the given verification key.
    /// - Parameter verificationKey: The verification key to validate against.
    /// - Returns: `true` if the keys match, `false` otherwise.
    public func validateVerificationKey(_ verificationKey: StakePoolVerificationKey) -> Bool {
        return coldVerificationKey == verificationKey
    }
    
    // MARK: - CBORSerializable
    
    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive, elements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "Invalid OperationalCertificateIssueCounter CBOR: expected array of 2 elements"
            )
        }
        
        let counter: UInt
        switch elements[0] {
        case .uint(let value):
            counter = value
        case .int(let value) where value >= 0:
            counter = UInt(value)
        default:
            throw CardanoCoreError.deserializeError(
                "Invalid counter value: expected uint, got \(elements[0])"
            )
        }
        
        guard case let .bytes(vkey) = elements[1] else {
            throw CardanoCoreError.deserializeError(
                "Invalid verification key: expected bytes, got \(elements[1])"
            )
        }
        
        self.counterValue = counter
        self.coldVerificationKey = try StakePoolVerificationKey(payload: vkey)
        self._type = Self.TYPE
        self._description = "Next certificate issue number: \(counter)"
        self._payload = try CBOREncoder().encode(primitive)
    }
    
    public func toPrimitive() throws -> Primitive {
        return .list([
            .uint(counterValue),
            .bytes(coldVerificationKey.payload)
        ])
    }
    
    // MARK: - JSONSerializable
    
    public static func fromDict(_ dict: Primitive) throws -> OperationalCertificateIssueCounter {
        guard case let .orderedDict(dictValue) = dict else {
            throw CardanoCoreError.deserializeError("Invalid OperationalCertificateIssueCounter dict")
        }
        
        let counter: UInt
        if case let .uint(value)? = dictValue[.string("counter")] {
            counter = value
        } else if case let .int(value)? = dictValue[.string("counter")], value >= 0 {
            counter = UInt(value)
        } else {
            throw CardanoCoreError.deserializeError("Missing or invalid counter value")
        }
        
        let vkey: StakePoolVerificationKey
        if case let .bytes(vkeyData)? = dictValue[.string("coldVerificationKey")] {
            vkey = try StakePoolVerificationKey(payload: vkeyData)
        } else if case let .string(vkeyHex)? = dictValue[.string("coldVerificationKey")] {
            vkey = try StakePoolVerificationKey(payload: vkeyHex.hexStringToData)
        } else {
            throw CardanoCoreError.deserializeError("Missing or invalid coldVerificationKey")
        }
        
        return try OperationalCertificateIssueCounter(
            counterValue: counter,
            coldVerificationKey: vkey
        )
    }
    
    public func toDict() throws -> Primitive {
        var dict: OrderedDictionary<Primitive, Primitive> = [:]
        dict[.string("counter")] = .uint(counterValue)
        dict[.string("coldVerificationKey")] = .string(coldVerificationKey.payload.toHex)
        return .orderedDict(dict)
    }
    
    // MARK: - Equatable & Hashable
    
    public static func == (lhs: OperationalCertificateIssueCounter, rhs: OperationalCertificateIssueCounter) -> Bool {
        return lhs.counterValue == rhs.counterValue &&
               lhs.coldVerificationKey == rhs.coldVerificationKey
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(counterValue)
        hasher.combine(coldVerificationKey)
    }
}

