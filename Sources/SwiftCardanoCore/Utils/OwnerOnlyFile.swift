import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// Writes `data` to `path` as a file only its owner can read or write
/// (mode `0600`) from the moment it exists.
///
/// Text envelopes can hold signing keys, so no saver leaves another local
/// account a window in which to open the file:
/// - With `overwrite` false the file is created with `O_CREAT | O_EXCL |
///   O_NOFOLLOW`, so an existing file or a symbolic link at `path` is never
///   written through, and the existence check cannot race the write.
/// - With `overwrite` true the data goes to a new `0600` file in the same
///   directory, which is then renamed over `path`. A reader sees the old
///   file or the new one, never a partial one, and an existing file's
///   looser mode is not kept.
///
/// WASI has no file modes and no atomic rename through Foundation, so there
/// the file is written plainly after the existence check.
///
/// - Parameters:
///   - data: The bytes to write.
///   - path: The file to write.
///   - overwrite: Whether to replace a file that already exists.
/// - Throws: `CardanoCoreError.ioError` when the file exists and `overwrite`
///   is false, or when it cannot be written.
func writeOwnerOnlyFile(_ data: Data, to path: String, overwrite: Bool) throws {
    #if os(WASI)
    if !overwrite, FileManager.default.fileExists(atPath: path) {
        throw CardanoCoreError.ioError("File already exists: \(path)")
    }
    try data.write(to: URL(fileURLWithPath: path))
    #else
    if !overwrite {
        let fd = open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else {
            let code = errno
            if code == EEXIST {
                throw CardanoCoreError.ioError("File already exists: \(path)")
            }
            throw CardanoCoreError.ioError("Cannot create \(path): \(String(cString: strerror(code)))")
        }
        do {
            try writeAll(data, to: fd, path: path)
        } catch {
            unlink(path)
            throw error
        }
        return
    }

    let url = URL(fileURLWithPath: path)
    let temporary = url.deletingLastPathComponent()
        .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp").path
    let fd = open(temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard fd >= 0 else {
        throw CardanoCoreError.ioError(
            "Cannot create a temporary file next to \(path): \(String(cString: strerror(errno)))")
    }
    do {
        try writeAll(data, to: fd, path: path)
        guard rename(temporary, path) == 0 else {
            throw CardanoCoreError.ioError("Cannot replace \(path): \(String(cString: strerror(errno)))")
        }
    } catch {
        unlink(temporary)
        throw error
    }
    #endif
}

#if !os(WASI)
/// Sets mode `0600` on the open file `fd` (the umask may have narrowed it
/// further), writes all of `data`, flushes it to disk and closes `fd`.
///
/// `fd` is closed whether or not this throws.
private func writeAll(_ data: Data, to fd: Int32, path: String) throws {
    defer { close(fd) }
    guard fchmod(fd, 0o600) == 0 else {
        throw CardanoCoreError.ioError("Cannot set the mode of \(path): \(String(cString: strerror(errno)))")
    }
    try data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
        guard var pointer = buffer.baseAddress else { return }
        var remaining = buffer.count
        while remaining > 0 {
            let written = write(fd, pointer, remaining)
            if written < 0 {
                if errno == EINTR { continue }
                throw CardanoCoreError.ioError("Cannot write \(path): \(String(cString: strerror(errno)))")
            }
            pointer += written
            remaining -= written
        }
    }
    guard fsync(fd) == 0 else {
        throw CardanoCoreError.ioError("Cannot write \(path): \(String(cString: strerror(errno)))")
    }
}
#endif
