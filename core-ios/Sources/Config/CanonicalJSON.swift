import Foundation

/// RFC 8785 (JCS) canonical JSON for Foundation JSON values: objects, arrays, strings, booleans,
/// null and finite numbers. Keys sort by UTF-16 code units; numbers use ES6 Number#toString.
enum CanonicalJSON {
    struct Unsupported: Error {}

    static func string(from value: Any) throws -> String {
        var out = ""
        try write(value, into: &out)
        return out
    }

    private static func write(_ value: Any, into out: inout String) throws {
        if let text = value as? String {
            writeString(text, into: &out)
        } else if value is NSNull {
            out += "null"
        } else if JSONValue.isBool(value) {
            out += (value as? NSNumber)?.boolValue == true ? "true" : "false"
        } else if let number = value as? NSNumber {
            guard number.doubleValue.isFinite else { throw Unsupported() }
            out += numberString(number.doubleValue)
        } else if let object = value as? [String: Any] {
            let keys = object.keys.sorted { Array($0.utf16).lexicographicallyPrecedes(Array($1.utf16)) }
            out += "{"
            for (index, key) in keys.enumerated() {
                if index > 0 { out += "," }
                writeString(key, into: &out)
                out += ":"
                try write(object[key] as Any, into: &out)
            }
            out += "}"
        } else if let array = value as? [Any] {
            out += "["
            for (index, item) in array.enumerated() {
                if index > 0 { out += "," }
                try write(item, into: &out)
            }
            out += "]"
        } else {
            throw Unsupported()
        }
    }

    private static func writeString(_ text: String, into out: inout String) {
        out += "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += "\\u" + String(format: "%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        out += "\""
    }

    /// Shortest round-trip digits (Swift's `description`) re-laid out per ES6 Number::toString.
    static func numberString(_ value: Double) -> String {
        if value == 0 { return "0" }
        let text = abs(value).description
        var mantissa = text
        var exponent = 0
        if let marker = text.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            mantissa = String(text[..<marker])
            exponent = Int(text[text.index(after: marker)...]) ?? 0
        }
        let parts = mantissa.split(separator: ".", omittingEmptySubsequences: false)
        var digits = String(parts[0]) + (parts.count > 1 ? String(parts[1]) : "")
        var point = parts[0].count + exponent
        while digits.hasPrefix("0") { digits.removeFirst(); point -= 1 }
        while digits.hasSuffix("0") { digits.removeLast() }
        guard !digits.isEmpty else { return "0" }

        let k = digits.count
        var out = value < 0 ? "-" : ""
        if k <= point && point <= 21 {
            out += digits + String(repeating: "0", count: point - k)
        } else if 0 < point && point <= 21 {
            out += digits.prefix(point) + "." + digits.dropFirst(point)
        } else if -6 < point && point <= 0 {
            out += "0." + String(repeating: "0", count: -point) + digits
        } else {
            let e = point - 1
            let sign = e < 0 ? "-" : "+"
            let head = digits.prefix(1)
            let tail = k > 1 ? "." + digits.dropFirst() : ""
            out += head + tail + "e" + sign + String(abs(e))
        }
        return out
    }
}
