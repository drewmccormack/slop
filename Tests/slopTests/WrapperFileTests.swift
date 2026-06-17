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
        XCTAssertTrue(src.contains("__SLOP_EVAL__"))
        XCTAssertTrue(src.contains("eval"))
    }
    func testWrapperDisablesGlobbing() throws {
        let src = try wrapperSource()
        // Must neutralise globbing one way or another for unquoted globs to survive.
        XCTAssertTrue(src.contains("noglob") || src.contains("set -f"))
    }
    func testWrapperCallsBinaryNotItself() throws {
        let src = try wrapperSource()
        XCTAssertTrue(src.contains("slop-bin"))
    }
}
