// Sources/slop/Decision.swift
enum Action: Equatable {
    case run
    case propose
}

func decide(_ c: SloppyCommand) -> Action {
    (c.confidence == .high && !c.isDestructive) ? .run : .propose
}
