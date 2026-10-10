package io.mobileshield;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;

/** One daemon thread running a check cycle every interval; cycles are skipped while backgrounded. */
final class Monitor {
    interface Cycle {
        void run();
        long intervalMs();
        boolean inForeground();
    }

    private final ScheduledExecutorService executor = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread thread = new Thread(r, "MobileShieldMonitor");
        thread.setDaemon(true);
        return thread;
    });
    private final Cycle cycle;
    private ScheduledFuture<?> next;
    private boolean running;
    // Each schedule() starts a new chain; ticks of an older chain stop instead of rescheduling,
    // so wake() during a running cycle can never leave two chains alive.
    private long chain;

    Monitor(Cycle cycle) {
        this.cycle = cycle;
    }

    synchronized void start() {
        if (running) return;
        running = true;
        schedule(cycle.intervalMs());
    }

    synchronized void stop() {
        running = false;
        chain++;
        if (next != null) next.cancel(false);
    }

    /** Runs a cycle now, e.g. when the app returns to the foreground. */
    synchronized void wake() {
        if (running) schedule(0);
    }

    private synchronized void schedule(long delayMs) {
        if (!running) return;
        if (next != null) next.cancel(false);
        final long mine = ++chain;
        next = executor.schedule(() -> tick(mine), delayMs, TimeUnit.MILLISECONDS);
    }

    private void tick(long mine) {
        if (!isCurrent(mine)) return;
        try {
            if (cycle.inForeground()) cycle.run();
        } catch (Throwable ignored) {
            // A failing cycle must never take down the host app or stop monitoring.
        }
        if (isCurrent(mine)) schedule(cycle.intervalMs());
    }

    private synchronized boolean isCurrent(long mine) {
        return running && chain == mine;
    }
}
