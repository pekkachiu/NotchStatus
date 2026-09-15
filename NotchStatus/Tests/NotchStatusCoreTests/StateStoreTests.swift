import Foundation
import Testing
@testable import NotchStatusCore

@Suite struct StateStoreTests {
    private func makeDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("notch-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ content: String, _ name: String, in dir: URL) throws {
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    @Test func missingDirectoryIsEmpty() {
        let dir = URL(fileURLWithPath: "/nonexistent/notch-\(UUID().uuidString)")
        #expect(StateStore.load(from: dir).isEmpty)
    }

    @Test func loadsEveryValidSessionFile() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try write(#"{"state":"working","project":"a","ts":1}"#, "s1.json", in: dir)
        try write(#"{"state":"done","project":"b","ts":2}"#, "s2.json", in: dir)

        let projects = StateStore.load(from: dir).map(\.project).sorted()
        #expect(projects == ["a", "b"])
    }

    @Test func skipsTempFilesOtherExtensionsAndMalformedJSON() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try write(#"{"state":"working","project":"good","ts":1}"#, "ok.json", in: dir)
        try write(#"{"state":"waiting","project":"tmp","ts":1}"#, ".s2.json.tmp", in: dir)
        try write(#"{"state":"waiting","project":"hidden","ts":1}"#, ".hidden.json", in: dir)
        try write(#"{"state":"waiting","project":"txt","ts":1}"#, "notes.txt", in: dir)
        try write("{broken", "bad.json", in: dir)

        #expect(StateStore.load(from: dir).map(\.project) == ["good"])
    }

    @Test func deletesFilesOfDeadSessionsAndKeepsTheRest() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try write(#"{"state":"working","project":"alive","ts":1,"pid":100}"#, "alive.json", in: dir)
        try write(#"{"state":"done","project":"dead","ts":1,"pid":200}"#, "dead.json", in: dir)
        try write(#"{"state":"done","project":"legacy","ts":1}"#, "legacy.json", in: dir)

        let loaded = StateStore.load(from: dir, isAlive: { $0 == 100 })

        #expect(loaded.map(\.project).sorted() == ["alive", "legacy"])
        let remaining = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        #expect(remaining == ["alive.json", "legacy.json"])
    }
}

@Suite struct ProcessLivenessTests {
    @Test func currentProcessIsAlive() {
        #expect(ProcessLiveness.isAlive(getpid()))
    }

    @Test func nonexistentProcessIsNotAlive() {
        // macOS 的 pid 上限遠小於此值
        #expect(!ProcessLiveness.isAlive(99_999_999))
    }

    @Test func invalidPidsAreNotAlive() {
        // kill(0, …) / kill(-1, …) 代表整個 process group，不能當成單一行程
        #expect(!ProcessLiveness.isAlive(0))
        #expect(!ProcessLiveness.isAlive(-1))
    }
}
