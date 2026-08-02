import Foundation

/// Minimal ZIP arxiv yozuvchisi (STORE — siqilmagan).
/// `.xlsx` aslida OOXML XML fayllarining ZIP'i. Foundation'da zip API yoʻq,
/// shuning uchun oʻzimiz yozamiz. STORE metodi bilan ham fayl toʻliq amal qiladi.
struct ZipArchive {
    private struct Entry { let name: String; let size: Int; let crc: UInt32; let offset: Int }
    private var entries: [Entry] = []
    private var buffer = Data()

    /// Arxivga fayl qoʻshadi.
    mutating func add(_ name: String, _ data: Data) {
        let crc = CRC32.checksum(data)
        let offset = buffer.count
        let nameBytes = Data(name.utf8)

        // Lokal fayl sarlavhasi
        var header = Data()
        header.append(le32: 0x0403_4b50)          // signature
        header.append(le16: 20)                    // version needed
        header.append(le16: 0)                     // flags
        header.append(le16: 0)                     // method: 0 = store
        header.append(le16: 0)                     // mod time
        header.append(le16: 0x21)                  // mod date (yaroqli qiymat)
        header.append(le32: crc)
        header.append(le32: UInt32(data.count))    // compressed size
        header.append(le32: UInt32(data.count))    // uncompressed size
        header.append(le16: UInt16(nameBytes.count))
        header.append(le16: 0)                     // extra length
        header.append(nameBytes)

        buffer.append(header)
        buffer.append(data)
        entries.append(Entry(name: name, size: data.count, crc: crc, offset: offset))
    }

    /// Markaziy katalog va EOCD qoʻshib, tugallangan arxiv baytlarini qaytaradi.
    mutating func finalize() -> Data {
        let centralStart = buffer.count
        var central = Data()

        for e in entries {
            let nameBytes = Data(e.name.utf8)
            central.append(le32: 0x0201_4b50)      // central dir signature
            central.append(le16: 20)               // version made by
            central.append(le16: 20)               // version needed
            central.append(le16: 0)                // flags
            central.append(le16: 0)                // method
            central.append(le16: 0)                // time
            central.append(le16: 0x21)             // date
            central.append(le32: e.crc)
            central.append(le32: UInt32(e.size))
            central.append(le32: UInt32(e.size))
            central.append(le16: UInt16(nameBytes.count))
            central.append(le16: 0)                // extra
            central.append(le16: 0)                // comment
            central.append(le16: 0)                // disk number
            central.append(le16: 0)                // internal attrs
            central.append(le32: 0)                // external attrs
            central.append(le32: UInt32(e.offset)) // local header offset
            central.append(nameBytes)
        }
        buffer.append(central)
        let centralSize = buffer.count - centralStart

        // End Of Central Directory
        var eocd = Data()
        eocd.append(le32: 0x0605_4b50)
        eocd.append(le16: 0)                        // disk number
        eocd.append(le16: 0)                        // central dir disk
        eocd.append(le16: UInt16(entries.count))
        eocd.append(le16: UInt16(entries.count))
        eocd.append(le32: UInt32(centralSize))
        eocd.append(le32: UInt32(centralStart))
        eocd.append(le16: 0)                        // comment length
        buffer.append(eocd)

        return buffer
    }
}

/// CRC-32 (ZIP/PNG standarti).
enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1) }
        return c
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

/// Little-endian baytlarni qoʻshish uchun yordamchi.
private extension Data {
    mutating func append(le16 value: UInt16) {
        append(contentsOf: [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)])
    }
    mutating func append(le32 value: UInt32) {
        append(contentsOf: [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF)
        ])
    }
}
