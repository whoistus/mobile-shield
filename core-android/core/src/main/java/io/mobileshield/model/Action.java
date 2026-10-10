package io.mobileshield.model;

/** Action applied for a threat. Ordinal order is strictness: REPORT &lt; WARN &lt; BLOCK &lt; KILL. */
public enum Action {
    REPORT, WARN, BLOCK, KILL;

    /** Returns the action for {@code name}, or null when unknown. */
    public static Action parse(String name) {
        for (Action a : values()) {
            if (a.name().equals(name)) return a;
        }
        return null;
    }

    public static Action fromOrdinal(int ordinal) {
        Action[] all = values();
        return ordinal >= 0 && ordinal < all.length ? all[ordinal] : REPORT;
    }
}
