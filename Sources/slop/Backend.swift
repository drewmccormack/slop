// Sources/slop/Backend.swift
// Chooses which model backend resolves the command, and manages the one-time
// consent for sending input to the cloud.
//
// Precedence:
//   --llm=apple   -> on-device, this run only (never changes stored default)
//   --llm=openai  -> OpenAI, this run only (implies consent; does NOT store it)
//   (no flag)     -> if OPENAI_API_KEY is set, use the STORED consent default:
//                      consent granted  -> OpenAI
//                      consent declined -> on-device
//                      no stored answer -> ask once, store the answer, then act
//                    if no key          -> on-device
//
// The flags are one-shot overrides. Only the interactive first-time prompt writes
// the persistent default (~/.config/slop/consent).

import Foundation

enum Backend: Equatable {
    case apple
    case openai(apiKey: String)
}

enum Consent: Equatable { case granted, declined, unknown }

private func consentFileURL() -> URL {
    let base = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map { URL(fileURLWithPath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
    return base.appendingPathComponent("slop").appendingPathComponent("consent")
}

func readStoredConsent() -> Consent {
    guard let text = try? String(contentsOf: consentFileURL(), encoding: .utf8) else { return .unknown }
    switch text.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "granted": return .granted
    case "declined": return .declined
    default: return .unknown
    }
}

func storeConsent(_ c: Consent) {
    guard c != .unknown else { return }
    let url = consentFileURL()
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    try? Data((c == .granted ? "granted" : "declined").utf8).write(to: url)
}

/// Decide the backend for this run. `askConsent` is invoked only when a stored
/// default is needed but absent; it returns the user's answer AND is expected to
/// persist it (so it is asked once, ever). Pure selection logic otherwise — no I/O
/// beyond reading the env and the stored file — which keeps it unit-testable.
func selectBackend(
    llm: LLMChoice,
    apiKey: String?,
    storedConsent: Consent,
    askConsent: () -> Consent
) -> Backend {
    let key = (apiKey?.isEmpty == false) ? apiKey! : nil

    switch llm {
    case .apple:
        return .apple                              // one-shot override, no storage
    case .openai:
        if let key { return .openai(apiKey: key) } // one-shot override, no storage
        return .apple                              // asked for openai but no key -> fall back
    case .auto:
        guard let key else { return .apple }       // no key -> on-device
        switch storedConsent {
        case .granted: return .openai(apiKey: key)
        case .declined: return .apple
        case .unknown:
            return askConsent() == .granted ? .openai(apiKey: key) : .apple
        }
    }
}
