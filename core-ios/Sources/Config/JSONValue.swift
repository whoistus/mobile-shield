import Foundation

enum JSONValue {
    static func isBool(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    static func isNumber(_ value: Any?) -> Bool {
        guard let value = value, value is NSNumber else { return false }
        return !isBool(value)
    }

    static func double(_ value: Any?) -> Double? {
        guard isNumber(value), let d = (value as? NSNumber)?.doubleValue, d.isFinite else { return nil }
        return d
    }

    /// Whole numbers only; 5000.5 is not an integer config value.
    static func int64(_ value: Any?) -> Int64? {
        guard let d = double(value) else { return nil }
        return Int64(exactly: d)
    }
}
