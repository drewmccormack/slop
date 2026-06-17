// Sources/slop/SloppyCommand.swift
import FoundationModels

@Generable
enum Confidence: Equatable {
    case high
    case medium
    case low
}

@Generable
struct SloppyCommand: Equatable {
    @Guide(description: "The corrected, runnable shell command, ready to execute as-is")
    let command: String

    @Guide(description: "One short sentence in plain English describing what the command does")
    let explanation: String

    @Guide(description: "How confident you are that this command matches the user's intent")
    let confidence: Confidence

    @Guide(description: "True if the command deletes, overwrites, moves files, force-pushes, or needs sudo; false for read-only or clearly safe commands")
    let isDestructive: Bool
}
