// Sources/slop/OpenAIInterpreter.swift
// Cloud backend: resolve a SloppyCommand via OpenAI's Chat Completions API using
// Structured Outputs (a strict JSON schema), so the result is guaranteed to parse
// into the same fields the on-device path produces.
import Foundation

let defaultOpenAIModel = "gpt-5.5"

func openAIModel() -> String {
    let m = ProcessInfo.processInfo.environment["SLOP_OPENAI_MODEL"] ?? ""
    return m.isEmpty ? defaultOpenAIModel : m
}

/// Decoded shape of the model's JSON reply (mirrors SloppyCommand).
private struct OpenAIResult: Decodable {
    let command: String
    let explanation: String
    let confidence: String   // "high" | "medium" | "low"
    let isDestructive: Bool
}

func interpretWithOpenAI(input: String, apiKey: String) async throws -> SloppyCommand {
    let schema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["command", "explanation", "confidence", "isDestructive"],
        "properties": [
            "command": ["type": "string", "description": "The corrected, directly runnable shell command"],
            "explanation": ["type": "string", "description": "One short sentence describing what the command does"],
            "confidence": ["type": "string", "enum": ["high", "medium", "low"],
                           "description": "high only when sure the command matches the user's intent"],
            "isDestructive": ["type": "boolean",
                              "description": "true if it could lose data, need sudo, rewrite git history, or affect anything outside the current directory"],
        ],
    ]

    let body: [String: Any] = [
        "model": openAIModel(),
        "messages": [
            ["role": "system", "content": systemInstructions],
            ["role": "user", "content": buildPrompt(input: input, context: currentContext())],
        ],
        "response_format": [
            "type": "json_schema",
            "json_schema": [
                "name": "sloppy_command",
                "strict": true,
                "schema": schema,
            ],
        ],
    ]

    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    request.timeoutInterval = 30

    let (data, response): (Data, URLResponse)
    do {
        (data, response) = try await URLSession.shared.data(for: request)
    } catch {
        throw SlopError.modelUnavailable("Could not reach OpenAI: \(error.localizedDescription)")
    }

    guard let http = response as? HTTPURLResponse else {
        throw SlopError.modelUnavailable("OpenAI returned no HTTP response.")
    }
    guard http.statusCode == 200 else {
        let detail = String(data: data, encoding: .utf8) ?? ""
        throw SlopError.modelUnavailable("OpenAI HTTP \(http.statusCode): \(detail.prefix(300))")
    }

    // Chat Completions envelope: choices[0].message.content is the JSON string.
    guard
        let top = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let choices = top["choices"] as? [[String: Any]],
        let message = choices.first?["message"] as? [String: Any],
        let content = message["content"] as? String,
        let contentData = content.data(using: .utf8),
        let parsed = try? JSONDecoder().decode(OpenAIResult.self, from: contentData)
    else {
        throw SlopError.modelUnavailable("Could not parse OpenAI response.")
    }

    let confidence: Confidence
    switch parsed.confidence.lowercased() {
    case "high": confidence = .high
    case "low": confidence = .low
    default: confidence = .medium
    }

    return SloppyCommand(
        command: parsed.command,
        explanation: parsed.explanation,
        confidence: confidence,
        isDestructive: parsed.isDestructive
    )
}
