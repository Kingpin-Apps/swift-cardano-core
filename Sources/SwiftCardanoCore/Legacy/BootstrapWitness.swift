import Foundation

// Define a struct for BootstrapWitness
public struct BootstrapWitness: CBORSerializable, Equatable, Hashable {
    public let publicKey: Data // $vkey - bytes of size 32
    public let signature: Data // $signature - bytes of size 64
    public let chainCode: Data // bytes of size 32
    public let attributes: Data // bytes of variable size
}
