import Foundation
import HycryptCore

/// A single source of truth: success, errors and cancellation cannot coexist.
enum OperationState: Equatable {
    case idle
    case running(OperationProgress)
    case cancelling
    case succeeded(URL)
    case failed(String)
    case cancelled

    var isBusy: Bool {
        switch self {
        case .running, .cancelling: true
        default: false
        }
    }
}
