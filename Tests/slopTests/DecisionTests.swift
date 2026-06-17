// Tests/slopTests/DecisionTests.swift
import XCTest
@testable import slop

final class DecisionTests: XCTestCase {
    private func cmd(_ conf: Confidence, _ destructive: Bool) -> SloppyCommand {
        SloppyCommand(command: "ls", explanation: "list", confidence: conf, isDestructive: destructive)
    }

    func testHighConfidenceSafeRuns() {
        XCTAssertEqual(decide(cmd(.high, false)), .run)
    }
    func testHighConfidenceDestructiveProposes() {
        XCTAssertEqual(decide(cmd(.high, true)), .propose)
    }
    func testMediumSafeProposes() {
        XCTAssertEqual(decide(cmd(.medium, false)), .propose)
    }
    func testLowSafeProposes() {
        XCTAssertEqual(decide(cmd(.low, false)), .propose)
    }
    func testLowDestructiveProposes() {
        XCTAssertEqual(decide(cmd(.low, true)), .propose)
    }
}
