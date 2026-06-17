import XCTest
@testable import slop

final class PromptTests: XCTestCase {
    func testInstructionsMentionBothModes() {
        XCTAssertTrue(systemInstructions.contains("repair"))
        XCTAssertTrue(systemInstructions.lowercased().contains("english"))
    }
    func testBuildPromptEmbedsInputAndContext() {
        let p = buildPrompt(input: "cp *.m dir/", context: "PWD: /tmp")
        XCTAssertTrue(p.contains("cp *.m dir/"))
        XCTAssertTrue(p.contains("PWD: /tmp"))
    }
    func testCurrentContextIncludesPwdAndShell() {
        let ctx = currentContext()
        XCTAssertTrue(ctx.contains("PWD:"))
        XCTAssertTrue(ctx.contains("SHELL:"))
    }
}
