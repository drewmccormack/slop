// Tests/slopTests/ShellEvalTests.swift
import XCTest
@testable import slop

final class ShellEvalTests: XCTestCase {
    func testCdNeedsEval() {
        XCTAssertTrue(needsLiveShellEval("cd /tmp/project"))
    }
    func testExportNeedsEval() {
        XCTAssertTrue(needsLiveShellEval("export FOO=bar"))
    }
    func testLeadingWhitespace() {
        XCTAssertTrue(needsLiveShellEval("   cd ~/dev"))
    }
    func testLsDoesNotNeedEval() {
        XCTAssertFalse(needsLiveShellEval("ls -la"))
    }
    func testCdSubstringInOtherCommandIsNotEval() {
        XCTAssertFalse(needsLiveShellEval("cdimage --help"))
    }
    func testEmptyIsNotEval() {
        XCTAssertFalse(needsLiveShellEval(""))
    }
}
