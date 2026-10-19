// Runs fontaine-helper (Helper/fontaine-helper.c) as root, the way TrollStore documents it (a
// persona override, which the persona entitlement allows): iPadOS installs only fonts inside the
// app's bundle, and only root can write there.

import Darwin
import Foundation

enum RootHelper {
    struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ reason: String) { errorDescription = reason }
    }

    static var executable: URL { Bundle.main.bundleURL.appendingPathComponent("fontaine-helper") }

    /// Where the helper puts fonts, and the system takes them from.
    static var fontsFolder: URL { Bundle.main.bundleURL.appendingPathComponent("Fonts", isDirectory: true) }

    static var placement: FontPlacement {
        FontPlacement(folder: fontsFolder,
                      put: { try run(["put", $0.lastPathComponent], input: $0) },
                      delete: { try run(["delete", $0], input: nil) })
    }

    private typealias SetPersona = @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>, uid_t, UInt32) -> Int32
    private typealias SetID = @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>, uid_t) -> Int32

    /// Private libSystem functions (not in the SDK), looked up when needed.
    private static func function<T>(_ name: String, _: T.Type) -> T? {
        dlsym(UnsafeMutableRawPointer(bitPattern: -2), name).map { unsafeBitCast($0, to: T.self) } // RTLD_DEFAULT
    }

    /// Runs the helper as root with `input` as its standard input; its message if it fails.
    static func run(_ arguments: [String], input: URL?) throws {
        guard let setPersona = function("posix_spawnattr_set_persona_np", SetPersona.self),
              let setUID = function("posix_spawnattr_set_persona_uid_np", SetID.self),
              let setGID = function("posix_spawnattr_set_persona_gid_np", SetID.self) else {
            throw Failure("persona")
        }
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        _ = setPersona(&attributes, 99, 1) // POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE
        _ = setUID(&attributes, 0)
        _ = setGID(&attributes, 0)

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        var inputFD: Int32 = -1
        defer { if inputFD >= 0 { close(inputFD) } }
        if let input {
            inputFD = open(input.path, O_RDONLY)
            guard inputFD >= 0 else { throw Failure(String(cString: strerror(errno))) }
            posix_spawn_file_actions_adddup2(&actions, inputFD, STDIN_FILENO)
        }
        var errorPipe: [Int32] = [-1, -1]
        guard pipe(&errorPipe) == 0 else { throw Failure(String(cString: strerror(errno))) }
        defer { close(errorPipe[0]) }
        posix_spawn_file_actions_adddup2(&actions, errorPipe[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&actions, errorPipe[0])

        let argv = ([executable.path] + arguments).map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }
        let envp: [UnsafeMutablePointer<CChar>?] = [strdup("PATH=/usr/bin:/bin"), nil]
        defer { envp.forEach { free($0) } }
        var pid: pid_t = 0
        let spawned = posix_spawn(&pid, executable.path, &actions, &attributes, argv, envp)
        close(errorPipe[1])
        guard spawned == 0 else { throw Failure(String(cString: strerror(spawned))) }

        let message = String(decoding: FileHandle(fileDescriptor: errorPipe[0], closeOnDealloc: false).readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var status: Int32 = 0
        var waited: pid_t
        repeat { waited = waitpid(pid, &status, 0) } while waited == -1 && errno == EINTR
        guard waited == pid else { throw Failure(String(cString: strerror(errno))) }
        let exited = status & 0x7F == 0, code = (status >> 8) & 0xFF
        guard exited, code == 0 else { throw Failure(message.isEmpty ? "fontaine-helper \(code)" : message) }
    }
}
