import Foundation
import Testing
@testable import NotchStatusCore

@Suite struct SessionStatusDecodingTests {
    @Test func decodesHookOutput() throws {
        let json = #"{"state":"waiting","project":"ai_status","ts":1789400064}"#
        let status = SessionStatus(jsonData: Data(json.utf8))
        #expect(status == SessionStatus(state: .waiting, project: "ai_status", ts: 1789400064))
    }

    @Test(arguments: ["working", "waiting", "idle", "done"])
    func decodesEveryState(raw: String) {
        let json = #"{"state":"\#(raw)","project":"p","ts":1}"#
        #expect(SessionStatus(jsonData: Data(json.utf8))?.state.rawValue == raw)
    }

    @Test func decodesPid() {
        let json = #"{"state":"done","project":"p","ts":1,"pid":71552}"#
        #expect(SessionStatus(jsonData: Data(json.utf8))?.pid == 71552)
    }

    @Test(arguments: [#"{"state":"done","project":"p","ts":1}"#, #"{"state":"done","project":"p","ts":1,"pid":null}"#])
    func pidIsOptional(json: String) {
        let status = SessionStatus(jsonData: Data(json.utf8))
        #expect(status != nil)
        #expect(status?.pid == nil)
    }

    @Test func rejectsUnknownState() {
        let json = #"{"state":"sleeping","project":"p","ts":1}"#
        #expect(SessionStatus(jsonData: Data(json.utf8)) == nil)
    }

    @Test(arguments: ["", "{", #"{"state":"done"}"#, "not json"])
    func rejectsMalformedJSON(json: String) {
        #expect(SessionStatus(jsonData: Data(json.utf8)) == nil)
    }
}
