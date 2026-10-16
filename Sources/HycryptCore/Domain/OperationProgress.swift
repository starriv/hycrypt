/// Domain events, independent of UI copy or localization.
public struct OperationProgress: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case preparing
        case derivingKey
        case encrypting
        case decrypting
        case archiving(String)
        case restoring(String)
        case saving
        case finished
    }

    public let phase: Phase
    public let fraction: Double?

    public init(_ phase: Phase, fraction: Double? = nil) {
        self.phase = phase
        self.fraction = fraction.map { $0.isFinite ? min(max($0, 0), 1) : 0 }
    }
}

public typealias ProgressHandler = @Sendable (OperationProgress) -> Void
