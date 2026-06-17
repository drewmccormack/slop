// Sources/slop/Interpreter.swift
import Foundation
import FoundationModels

enum SlopError: Error, CustomStringConvertible {
    case modelUnavailable(String)
    var description: String {
        switch self {
        case .modelUnavailable(let m): return m
        }
    }
}

func interpret(input: String) async throws -> SloppyCommand {
    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
        break
    case .unavailable(let reason):
        let hint: String
        switch reason {
        case .appleIntelligenceNotEnabled:
            hint = "Apple Intelligence is not enabled. Enable it in System Settings."
        case .modelNotReady:
            hint = "The on-device model is still downloading/preparing. Try again shortly."
        case .deviceNotEligible:
            hint = "This device is not eligible for Apple Intelligence."
        @unknown default:
            hint = "The on-device model is unavailable."
        }
        throw SlopError.modelUnavailable(hint)
    }

    let session = LanguageModelSession(instructions: systemInstructions)
    let prompt = buildPrompt(input: input, context: currentContext())
    let response = try await session.respond(to: prompt, generating: SloppyCommand.self)
    return response.content
}
