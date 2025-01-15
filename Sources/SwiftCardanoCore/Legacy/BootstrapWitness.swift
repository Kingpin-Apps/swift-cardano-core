import Foundation

// Define a struct for BootstrapWitness
struct BootstrapWitness: Codable {
    let publicKey: Data // $vkey - bytes of size 32
    let signature: Data // $signature - bytes of size 64
    let chainCode: Data // bytes of size 32
    let attributes: Data // bytes of variable size
}
