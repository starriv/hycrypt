import HycryptCore

/// Local UI heuristic, advisory only, never an encryption requirement.
/// Retains no password and performs no network or breach-database lookup.
struct PasswordStrength {
    let level: Int

    var title: String {
        switch level {
        case 0: "尚未输入"
        case 1: "弱"
        case 2: "一般"
        case 3: "较好"
        default: "强"
        }
    }

    init(_ password: String) {
        guard !password.isEmpty else {
            level = 0
            return
        }
        guard password.count >= 16 else {
            level = 1
            return
        }
        // Bound UI work for oversized pasted input; encryption rejects it separately.
        guard password.utf8.count <= SecretPolicy.maximumPasswordBytes else {
            level = 1
            return
        }
        let characters = Array(password)
        let unique = Set(characters).count
        // Repeating a short pattern must not become "strong" just by adding length.
        let repeats = (1...min(16, characters.count / 2)).contains { period in
            characters.indices.allSatisfy { characters[$0] == characters[$0 % period] }
        }
        let lowered = password.lowercased()
        let commonPattern = ["password", "qwerty", "123456", "abcdef", "letmein"]
            .contains { lowered.contains($0) }
        if repeats || commonPattern || unique < 6 {
            level = 1
        } else if characters.count < 20 || unique < 8 {
            level = 2
        } else if characters.count < 28 || unique < 12 {
            level = 3
        } else {
            level = 4
        }
    }
}
