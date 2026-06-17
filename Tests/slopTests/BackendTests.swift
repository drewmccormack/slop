// Tests/slopTests/BackendTests.swift
import XCTest
@testable import slop

final class BackendTests: XCTestCase {
    func testNoKeyAlwaysApple() {
        XCTAssertEqual(selectBackend(llm: .auto, apiKey: nil, storedConsent: .granted, askConsent: { .granted }), .apple)
        XCTAssertEqual(selectBackend(llm: .auto, apiKey: "", storedConsent: .granted, askConsent: { .granted }), .apple)
    }

    func testForceAppleIgnoresKeyAndConsent() {
        let b = selectBackend(llm: .apple, apiKey: "sk-xxx", storedConsent: .granted, askConsent: { .granted })
        XCTAssertEqual(b, .apple)
    }

    func testForceOpenAIWithKeyDoesNotConsultStoredConsent() {
        // --llm=openai is a one-shot override; works even if stored consent is declined,
        // and must NOT call the asker (which would store a default).
        var asked = false
        let b = selectBackend(llm: .openai, apiKey: "sk-xxx", storedConsent: .declined,
                              askConsent: { asked = true; return .declined })
        XCTAssertEqual(b, .openai(apiKey: "sk-xxx"))
        XCTAssertFalse(asked, "one-shot --llm=openai must not invoke consent prompt")
    }

    func testForceOpenAIWithoutKeyFallsBackToApple() {
        let b = selectBackend(llm: .openai, apiKey: nil, storedConsent: .granted, askConsent: { .granted })
        XCTAssertEqual(b, .apple)
    }

    func testAutoStoredGrantedUsesOpenAI() {
        let b = selectBackend(llm: .auto, apiKey: "sk-xxx", storedConsent: .granted, askConsent: { .declined })
        XCTAssertEqual(b, .openai(apiKey: "sk-xxx"))
    }

    func testAutoStoredDeclinedUsesAppleWithoutAsking() {
        var asked = false
        let b = selectBackend(llm: .auto, apiKey: "sk-xxx", storedConsent: .declined,
                              askConsent: { asked = true; return .granted })
        XCTAssertEqual(b, .apple)
        XCTAssertFalse(asked, "a stored 'declined' must be respected without re-asking")
    }

    func testAutoUnknownAsksAndHonoursAnswer() {
        let granted = selectBackend(llm: .auto, apiKey: "sk-xxx", storedConsent: .unknown, askConsent: { .granted })
        XCTAssertEqual(granted, .openai(apiKey: "sk-xxx"))
        let declined = selectBackend(llm: .auto, apiKey: "sk-xxx", storedConsent: .unknown, askConsent: { .declined })
        XCTAssertEqual(declined, .apple)
    }
}

final class LLMOptionTests: XCTestCase {
    func testLLMDefaultsAuto() {
        XCTAssertEqual(parseOptions(["ls"]).llm, .auto)
    }
    func testLLMOpenAIFlag() {
        XCTAssertEqual(parseOptions(["--llm=openai", "ls"]).llm, .openai)
        XCTAssertEqual(parseOptions(["--openai", "ls"]).llm, .openai)
    }
    func testLLMAppleFlag() {
        XCTAssertEqual(parseOptions(["--llm=apple", "ls"]).llm, .apple)
        XCTAssertEqual(parseOptions(["--local", "ls"]).llm, .apple)
    }
    func testLLMFlagDoesNotLeakIntoInput() {
        XCTAssertEqual(parseOptions(["--llm=openai", "delete", "stuff"]).input, "delete stuff")
    }
}
