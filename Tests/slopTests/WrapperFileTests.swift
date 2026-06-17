// Tests/slopTests/WrapperFileTests.swift
import XCTest
import Foundation

final class WrapperFileTests: XCTestCase {
    private func wrapperSource() throws -> String {
        // shell/slop.sh sits at the package root, two levels up from this test bundle's source.
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()  // slopTests
            .deletingLastPathComponent()              // Tests
            .deletingLastPathComponent()              // package root
        let url = root.appendingPathComponent("shell/slop.sh")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testWrapperHandlesEvalSentinel() throws {
        let src = try wrapperSource()
        XCTAssertTrue(src.contains("SLOP_EVAL_FILE"))
        XCTAssertTrue(src.contains("eval"))
    }
    func testWrapperDisablesGlobbing() throws {
        let src = try wrapperSource()
        // zsh path: noglob alias at the call site preserves unquoted globs.
        XCTAssertTrue(src.contains("noglob"))
    }
    func testWrapperCallsBinaryNotItself() throws {
        let src = try wrapperSource()
        XCTAssertTrue(src.contains("slop-bin"))
    }
}
