// Tests/slopTests/ExecutorTests.swift
import XCTest
@testable import slop

final class ExecutorTests: XCTestCase {
    func testRunsSafeCommandAndReturnsExitCode() {
        let outcome = execute("true", shell: "/bin/sh")
        XCTAssertEqual(outcome, .ran(exitCode: 0))
    }
    func testNonZeroExitPassesThrough() {
        let outcome = execute("exit 3", shell: "/bin/sh")
        XCTAssertEqual(outcome, .ran(exitCode: 3))
    }
    func testCdEmitsForEvalInsteadOfRunning() {
        let outcome = execute("cd /tmp", shell: "/bin/sh")
        XCTAssertEqual(outcome, .emitForEval("cd /tmp"))
    }
}
