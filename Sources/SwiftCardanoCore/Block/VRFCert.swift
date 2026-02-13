import Foundation
import OrderedCollections

/// VRF certificate as defined in the Conway CDDL:
/// `vrf_cert = [bytes, bytes .size 80]`
///
/// The first element is the VRF output (arbitrary bytes),
/// and the second element is the VRF proof (80 bytes).
public struct VRFCert: Serializable {
    public var output: Data
    public var proof: Data

    public static let PROOF_SIZE = 80

    enum CodingKeys: String, CodingKey {
        case output
        case proof
    }

    public init(output: Data, proof: Data) throws {
        guard proof.count == Self.PROOF_SIZE else {
            throw CardanoCoreError.invalidArgument(
                "VRFCert proof must be \(Self.PROOF_SIZE) bytes, got \(proof.count)"
            )
        }
        self.output = output
        self.proof = proof
    }

    // MARK: - CBORSerializable

    public init(from primitive: Primitive) throws {
        guard case let .list(elements) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid VRFCert primitive: expected list")
        }

        guard elements.count == 2 else {
            throw CardanoCoreError.deserializeError(
                "VRFCert requires exactly 2 elements, got \(elements.count)"
            )
        }

        guard case let .bytes(output) = elements[0] else {
            throw CardanoCoreError.deserializeError("Invalid VRFCert output: expected bytes")
        }

        guard case let .bytes(proof) = elements[1] else {
            throw CardanoCoreError.deserializeError("Invalid VRFCert proof: expected bytes")
        }

        try self.init(output: output, proof: proof)
    }

    public func toPrimitive() throws -> Primitive {
        return .list([
            .bytes(output),
            .bytes(proof)
        ])
    }

    // MARK: - JSONSerializable

    public static func fromDict(_ primitive: Primitive) throws -> VRFCert {
        guard case let .orderedDict(dict) = primitive else {
            throw CardanoCoreError.deserializeError("Invalid VRFCert dict")
        }

        guard let outputPrimitive = dict[.string(CodingKeys.output.rawValue)],
              case let .bytes(output) = outputPrimitive else {
            throw CardanoCoreError.deserializeError("Missing or invalid output in VRFCert")
        }

        guard let proofPrimitive = dict[.string(CodingKeys.proof.rawValue)],
              case let .bytes(proof) = proofPrimitive else {
            throw CardanoCoreError.deserializeError("Missing or invalid proof in VRFCert")
        }

        return try VRFCert(output: output, proof: proof)
    }

    public func toDict() throws -> Primitive {
        var dict = OrderedDictionary<Primitive, Primitive>()
        dict[.string(CodingKeys.output.rawValue)] = .bytes(output)
        dict[.string(CodingKeys.proof.rawValue)] = .bytes(proof)
        return .orderedDict(dict)
    }

    // MARK: - Equatable

    public static func == (lhs: VRFCert, rhs: VRFCert) -> Bool {
        return lhs.output == rhs.output && lhs.proof == rhs.proof
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(output)
        hasher.combine(proof)
    }
}
