package io.mobileshield;

import io.mobileshield.model.ThreatEvent;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;

/**
 * Listener fan-out with a bounded backlog (same semantics as iOS EventBus): events raised while
 * nobody listens are replayed to the first listener that registers.
 */
final class EventHub {
    static final int BACKLOG_LIMIT = 64;

    private final List<MobileShield.Listener> listeners = new ArrayList<>();
    private final ArrayDeque<ThreatEvent> backlog = new ArrayDeque<>();

    void add(MobileShield.Listener listener) {
        List<ThreatEvent> pending;
        synchronized (this) {
            if (listeners.contains(listener)) return;
            pending = listeners.isEmpty() ? new ArrayList<>(backlog) : new ArrayList<ThreatEvent>();
            backlog.clear();
            listeners.add(listener);
        }
        for (ThreatEvent event : pending) deliver(listener, event);
    }

    synchronized void remove(MobileShield.Listener listener) {
        listeners.remove(listener);
    }

    void publish(List<ThreatEvent> events) {
        for (ThreatEvent event : events) {
            List<MobileShield.Listener> targets;
            synchronized (this) {
                targets = new ArrayList<>(listeners);
                if (targets.isEmpty()) {
                    backlog.addLast(event);
                    if (backlog.size() > BACKLOG_LIMIT) backlog.removeFirst();
                }
            }
            for (MobileShield.Listener target : targets) deliver(target, event);
        }
    }

    private static void deliver(MobileShield.Listener listener, ThreatEvent event) {
        try {
            listener.onThreat(event);
        } catch (RuntimeException ignored) {
            // One misbehaving listener must not starve the others or abort the cycle.
        }
    }
}
