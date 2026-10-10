import Foundation
import MachO

/// Reads the code-signing identifier of the main executable from its in-memory LC_CODE_SIGNATURE
/// blob. Every offset is bounds-checked against the blob; malformed data yields nil, never a crash.
enum CodeSignature {
    static let mainExecutableIdentifier: String? = readIdentifier()

    private static func readIdentifier() -> String? {
        guard let header = _dyld_get_image_header(0) else { return nil }
        let base = UnsafeRawPointer(header)
        let machHeader = base.load(as: mach_header_64.self)
        guard machHeader.magic == MH_MAGIC_64 else { return nil }

        var linkedit: segment_command_64?
        var signature: linkedit_data_command?
        var cursor = base + MemoryLayout<mach_header_64>.size
        for _ in 0..<machHeader.ncmds {
            let command = cursor.load(as: load_command.self)
            guard command.cmdsize >= UInt32(MemoryLayout<load_command>.size) else { return nil }
            if command.cmd == UInt32(LC_SEGMENT_64) {
                let segment = cursor.load(as: segment_command_64.self)
                if segmentName(segment) == "__LINKEDIT" { linkedit = segment }
            } else if command.cmd == UInt32(LC_CODE_SIGNATURE) {
                signature = cursor.load(as: linkedit_data_command.self)
            }
            cursor += Int(command.cmdsize)
        }
        guard let seg = linkedit, let sig = signature, sig.datasize >= 12,
              UInt64(sig.dataoff) >= seg.fileoff,
              UInt64(sig.dataoff) + UInt64(sig.datasize) <= seg.fileoff + seg.filesize else { return nil }

        let slide = _dyld_get_image_vmaddr_slide(0)
        let address = Int(seg.vmaddr) + slide + Int(UInt64(sig.dataoff) - seg.fileoff)
        guard let blob = UnsafeRawPointer(bitPattern: address) else { return nil }
        return identifier(in: blob, length: Int(sig.datasize))
    }

    static func identifier(in blob: UnsafeRawPointer, length: Int) -> String? {
        func word(_ offset: Int) -> Int? {
            guard offset >= 0, offset + 4 <= length else { return nil }
            return Int(UInt32(bigEndian: blob.loadUnaligned(fromByteOffset: offset, as: UInt32.self)))
        }
        guard word(0) == 0xFADE_0CC0, let count = word(8), count <= 64 else { return nil }
        for index in 0..<count {
            guard let type = word(12 + index * 8), let offset = word(16 + index * 8), type == 0,
                  word(offset) == 0xFADE_0C02, let identOffset = word(offset + 20) else { continue }
            var bytes: [UInt8] = []
            var position = offset + identOffset
            while position < length, bytes.count < 256 {
                let byte = blob.load(fromByteOffset: position, as: UInt8.self)
                if byte == 0 { return String(bytes: bytes, encoding: .utf8) }
                bytes.append(byte)
                position += 1
            }
        }
        return nil
    }

    private static func segmentName(_ segment: segment_command_64) -> String {
        withUnsafeBytes(of: segment.segname) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
