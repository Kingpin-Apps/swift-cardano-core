import Testing
@testable import SwiftCardanoCore

struct ErrorsTests {

    @Test func testEncodingError() async throws {
        let description = "Encoding failed"
        let error: CardanoCoreError = .encodingError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }
    
    @Test func testDecodingError() async throws {
        let description = "Decoding failed"
        let error: CardanoCoreError = .decodingError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testInvalidKeyTypeError() async throws {
        let description = "Invalid key type"
        let error: CardanoCoreError = .invalidKeyTypeError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testInvalidAddressInputError() async throws {
        let description = "Invalid address input"
        let error: CardanoCoreError = .invalidAddressInputError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testInvalidDataError() async throws {
        let description = "Invalid data"
        let error: CardanoCoreError = .invalidDataError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testInvalidArgumentError() async throws {
        let description = "Invalid argument"
        let error: CardanoCoreError = .invalidArgument(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testInvalidOperationError() async throws {
        let description = "Invalid operation"
        let error: CardanoCoreError = .invalidOperation(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testSerializeError() async throws {
        let description = "Serialization failed"
        let error: CardanoCoreError = .serializeError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testDeserializeError() async throws {
        let description = "Deserialization failed"
        let error: CardanoCoreError = .deserializeError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testInvalidTransactionError() async throws {
        let description = "Invalid transaction"
        let error: CardanoCoreError = .invalidTransaction(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testTransactionFailedError() async throws {
        let description = "Transaction failed"
        let error: CardanoCoreError = .transactionFailederror(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testInsufficientUTxOBalanceError() async throws {
        let description = "Insufficient UTxO balance"
        let error: CardanoCoreError = .insufficientUTxOBalanceError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testMaxInputCountExceededError() async throws {
        let description = "Max input count exceeded"
        let error: CardanoCoreError = .maxInputCountExceedederror(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testInputUTxODepletedError() async throws {
        let description = "Input UTxO depleted"
        let error: CardanoCoreError = .inputUTxODepletedError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testBackendError() async throws {
        let description = "Backend error"
        let error: CardanoCoreError = .backendError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testInvalidLanguageError() async throws {
        let description = "Invalid language"
        let error: CardanoCoreError = .invalidLanguage(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testValueError() async throws {
        let description = "Incorrect value"
        let error: CardanoCoreError = .valueError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testIOError() async throws {
        let description = "IO error"
        let error: CardanoCoreError = .ioError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testTypeError() async throws {
        let description = "Type error"
        let error: CardanoCoreError = .typeError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }

    @Test func testNotImplementedError() async throws {
        let description = "Not implemented"
        let error: CardanoCoreError = .notImplementedError(description)

        #expect(error.description == description)
        #expect(throws: CardanoCoreError.self) {
            throw error
        }
    }
}
