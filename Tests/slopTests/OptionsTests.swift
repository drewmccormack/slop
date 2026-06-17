// Tests/slopTests/OptionsTests.swift
import XCTest
@testable import slop

final class OptionsTests: XCTestCase {
    func testNoFlags() {
        let o = parseOptions(["copy", "the", "m", "files"])
        XCTAssertFalse(o.dryRun)
        XCTAssertFalse(o.alwaysPrompt)
        XCTAssertEqual(o.input, "copy the m files")
    }

    func testDryRunLong() {
        let o = parseOptions(["--dry-run", "rm", "stuff"])
        XCTAssertTrue(o.dryRun)
        XCTAssertEqual(o.input, "rm stuff")
    }

    func testDryRunShort() {
        let o = parseOptions(["-n", "ls"])
        XCTAssertTrue(o.dryRun)
        XCTAssertEqual(o.input, "ls")
    }

    func testPromptLongAndShort() {
        XCTAssertTrue(parseOptions(["--prompt", "ls"]).alwaysPrompt)
        XCTAssertTrue(parseOptions(["-i", "ls"]).alwaysPrompt)
    }

    func testBothFlags() {
        let o = parseOptions(["--dry-run", "--prompt", "cp", "a", "b"])
        XCTAssertTrue(o.dryRun)
        XCTAssertTrue(o.alwaysPrompt)
        XCTAssertEqual(o.input, "cp a b")
    }

    func testFlagsOnlyRecognisedBeforeInput() {
        // A flag-looking token AFTER input is part of the input, not a flag.
        let o = parseOptions(["echo", "--dry-run"])
        XCTAssertFalse(o.dryRun)
        XCTAssertEqual(o.input, "echo --dry-run")
    }

    func testDoubleDashEndsFlags() {
        let o = parseOptions(["--", "--prompt", "is", "literal"])
        XCTAssertFalse(o.alwaysPrompt)
        XCTAssertEqual(o.input, "--prompt is literal")
    }

    func testEmpty() {
        let o = parseOptions([])
        XCTAssertEqual(o.input, "")
        XCTAssertFalse(o.dryRun)
        XCTAssertFalse(o.alwaysPrompt)
    }
}
