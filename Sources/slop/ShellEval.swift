// Sources/slop/ShellEval.swift
import Foundation

func needsLiveShellEval(_ command: String) -> Bool {
    let trimmed = command.trimmingCharacters(in: .whitespaces)
    let first = trimmed.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
    return first == "cd" || first == "export"
}
