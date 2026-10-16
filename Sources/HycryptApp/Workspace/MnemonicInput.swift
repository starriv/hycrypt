import Foundation
import HycryptCore

/// Bounded draft; never persists words or accepts fuzzy/autocorrected replacements.
struct MnemonicInput {
    private(set) var words = Array(repeating: "", count: BIP39.wordCount)
    var activeIndex: Int?
    private(set) var focusRequest = 0
    private(set) var inputError: String?

    var isEmpty: Bool { words.allSatisfy(\.isEmpty) }
    var phrase: String { words.joined(separator: " ") }
    var suggestions: [String] {
        guard let activeIndex, words.indices.contains(activeIndex) else { return [] }
        let word = words[activeIndex]
        return BIP39.contains(word) ? [] : BIP39.suggestions(for: word)
    }
    var validationMessage: String? {
        if let inputError { return inputError }
        guard words.allSatisfy({ !$0.isEmpty }) else { return "请输入 24 个单词。" }
        do { try BIP39.validate(words: words, requiredWordCount: BIP39.wordCount) } catch {
            return error.localizedDescription
        }
        return nil
    }

    mutating func loadGenerated(_ words: [String]) throws {
        try BIP39.validate(words: words, requiredWordCount: BIP39.wordCount)
        self = MnemonicInput()
        self.words = words
    }

    mutating func edit(_ value: String, at index: Int) {
        guard words.indices.contains(index), value.utf8.count <= 256 else {
            inputError = "输入过长。"
            return
        }
        let pieces = value.split(whereSeparator: \.isWhitespace).map(String.init)
        if pieces.count > 1 {
            // Whole-phrase paste is atomic. A failed import never leaves a partially replaced draft.
            guard pieces.count == BIP39.wordCount else {
                inputError = "粘贴内容需为完整的 24 个单词。"
                return
            }
            do { try BIP39.validate(words: pieces, requiredWordCount: BIP39.wordCount) } catch {
                inputError = error.localizedDescription
                return
            }
            words = pieces
        } else {
            let word = pieces.first ?? ""
            guard word.utf8.count <= BIP39.maximumWordLength,
                word.utf8.allSatisfy({ (97...122).contains($0) })
            else {
                inputError = "请输入 BIP39 英文小写单词。"
                return
            }
            words[index] = word
        }
        inputError = nil
    }

    mutating func choose(_ word: String) {
        guard let activeIndex, suggestions.contains(word), BIP39.contains(word) else { return }
        words[activeIndex] = word
        inputError = nil
        advance(from: activeIndex)
    }

    mutating func advance(from index: Int, backwards: Bool = false) {
        guard words.indices.contains(index), backwards || BIP39.contains(words[index]) else { return }
        activeIndex = min(max(index + (backwards ? -1 : 1), 0), words.count - 1)
        focusRequest += 1
    }

    mutating func clear() { self = MnemonicInput() }
}
