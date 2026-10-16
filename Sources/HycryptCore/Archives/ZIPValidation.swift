import Foundation

/// ZIPFoundation's iterator stops on a malformed entry. Independently check the
/// declared count so a partially readable archive cannot be published as complete.
enum ZIPValidation {
    static func entryCount(at url: URL) throws -> Int {
        let input = try FileIO.openInput(url)
        defer { try? input.close() }
        let length = try input.seekToEnd()
        guard length >= 22 else { throw HycryptError.unsafeArchive }
        let tailLength = Int(min(length, 65_557))
        try input.seek(toOffset: length - UInt64(tailLength))
        let tail = try FileIO.readExactly(input, count: tailLength)
        var footer: Int?
        for offset in stride(from: tail.count - 22, through: 0, by: -1) {
            if tail[offset..<(offset + 4)].elementsEqual([0x50, 0x4b, 0x05, 0x06]),
                offset + 22 + Int(littleEndian(tail, offset + 20, 2)) == tail.count
            {
                footer = offset
                break
            }
        }
        guard let footer,
            littleEndian(tail, footer + 4, 2) == 0,
            littleEndian(tail, footer + 6, 2) == 0
        else { throw HycryptError.unsafeArchive }
        var count = littleEndian(tail, footer + 10, 2)
        let footerOffset = length - UInt64(tailLength) + UInt64(footer)
        // A ZIP64 locator can exist even when the entry count fits in 16 bits.
        if footerOffset >= 20 {
            try input.seek(toOffset: footerOffset - 20)
            let locator = try FileIO.readExactly(input, count: 20)
            if locator.prefix(4).elementsEqual([0x50, 0x4b, 0x06, 0x07]) {
                guard littleEndian(locator, 4, 4) == 0, littleEndian(locator, 16, 4) == 1 else {
                    throw HycryptError.unsafeArchive
                }
                let recordOffset = littleEndian(locator, 8, 8)
                guard length >= 56, recordOffset <= length - 56 else { throw HycryptError.unsafeArchive }
                try input.seek(toOffset: recordOffset)
                let record = try FileIO.readExactly(input, count: 56)
                guard record.prefix(4).elementsEqual([0x50, 0x4b, 0x06, 0x06]),
                    littleEndian(record, 4, 8) >= 44,
                    littleEndian(record, 16, 4) == 0, littleEndian(record, 20, 4) == 0,
                    littleEndian(record, 24, 8) == littleEndian(record, 32, 8)
                else { throw HycryptError.unsafeArchive }
                count = littleEndian(record, 32, 8)
            } else {
                guard count != 0xffff, littleEndian(tail, footer + 8, 2) == count else {
                    throw HycryptError.unsafeArchive
                }
            }
        }
        guard count > 0, count <= UInt64(DirectoryArchive.maximumEntries) else { throw HycryptError.unsafeArchive }
        return Int(count)
    }

    private static func littleEndian(_ data: Data, _ offset: Int, _ count: Int) -> UInt64 {
        data[offset..<(offset + count)].reversed().reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }
}
