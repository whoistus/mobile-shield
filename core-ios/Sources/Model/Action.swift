enum Action: String, Comparable {
    case report = "REPORT"
    case warn = "WARN"
    case block = "BLOCK"
    case kill = "KILL"

    private var rank: Int {
        switch self {
        case .report: return 0
        case .warn: return 1
        case .block: return 2
        case .kill: return 3
        }
    }

    static func < (lhs: Action, rhs: Action) -> Bool { lhs.rank < rhs.rank }

    var isEnforcing: Bool { self >= .block }
}
