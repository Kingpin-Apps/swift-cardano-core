import Logging

let logger = Logger(label: "com.swift-cardano-core")

// Setup Logging
private let loggingInitOnce: Void = {
    LoggingSystem.bootstrap { label in
        StreamLogHandler.standardOutput(label: label)
    }
}()

public func setupLogging() {
    _ = loggingInitOnce
}

public protocol Loggable {
    func logState()
}

public extension Loggable {
    func logState() {
        let mirror = Mirror(reflecting: self)
        let properties = mirror.children.map { "\($0.label ?? "unknown"): \($0.value)" }.joined(separator: "\n")
        logger.debug("Class: \(type(of: self)), state:\n \(properties)")
    }
}
