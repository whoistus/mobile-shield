package io.mobileshield;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import io.mobileshield.config.AppliedConfig;
import io.mobileshield.model.Action;
import io.mobileshield.model.ThreatCategory;
import io.mobileshield.model.ThreatEvent;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.json.JSONObject;
import org.junit.Test;

public class ShieldCoreTest {
    private static final class FakePlatform implements ShieldCore.Platform {
        volatile long pushedSeq = -1;
        volatile Long savedSeq;
        volatile long collectedSeq = -2;
        volatile long decidedSeq = -3;
        CountDownLatch collecting;
        CountDownLatch release;

        @Override public void push(AppliedConfig config) { pushedSeq = config.seq; }
        @Override public Long lastKnownSeq() { return savedSeq; }
        @Override public void save(JSONObject raw, long seq) { savedSeq = seq; }

        @Override public Action decide(ThreatCategory category, String detectorId, double confidence) {
            decidedSeq = pushedSeq;
            return Action.REPORT;
        }

        @Override public List<CheckRunner.Hit> collect(AppliedConfig config) {
            collectedSeq = config.seq;
            if (collecting != null) {
                collecting.countDown();
                try {
                    release.await(5, TimeUnit.SECONDS);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
            return Collections.singletonList(
                    new CheckRunner.Hit(ThreatCategory.ROOT, "root.suPaths", 0.9, Collections.<String, String>emptyMap()));
        }
    }

    private static JSONObject clampingConfig(long seq) throws Exception {
        return TestSupport.config(seq).put("detectors", new JSONObject().put("tampering.signature", false));
    }

    @Test
    public void reentrantUpdateFromListenerDoesNotRollBackTheSequence() throws Exception {
        FakePlatform platform = new FakePlatform();
        EventHub hub = new EventHub();
        final ShieldCore core = new ShieldCore(TestSupport.bootstrap("prod"), platform, hub);
        final List<String> failures = new ArrayList<>();
        hub.add(new MobileShield.Listener() {
            private boolean nested;

            @Override public void onThreat(ThreatEvent event) {
                if (nested) return;
                nested = true;
                try {
                    core.update(TestSupport.config(11), true);
                } catch (Exception e) {
                    failures.add(String.valueOf(e));
                }
            }
        });

        core.update(clampingConfig(10), false);

        assertTrue(failures.toString(), failures.isEmpty());
        assertEquals(Long.valueOf(11), platform.savedSeq);
        assertEquals(11, core.config().seq);
        assertEquals(11, platform.pushedSeq);
    }

    @Test
    public void checkCycleDecidesWithTheConfigThatCollectedTheFinding() throws Exception {
        final FakePlatform platform = new FakePlatform();
        platform.collecting = new CountDownLatch(1);
        platform.release = new CountDownLatch(1);
        final ShieldCore core = new ShieldCore(TestSupport.bootstrap("dev"), platform, new EventHub());
        core.update(TestSupport.config(1), true);

        Thread cycle = new Thread(new Runnable() {
            @Override public void run() { core.runChecks(); }
        });
        cycle.start();
        assertTrue(platform.collecting.await(5, TimeUnit.SECONDS));

        Thread update = new Thread(new Runnable() {
            @Override public void run() {
                try {
                    core.update(TestSupport.config(2), true);
                } catch (Exception ignored) {
                    // asserted through the platform state below
                }
            }
        });
        update.start();
        Thread.sleep(150);
        platform.release.countDown();
        cycle.join(5000);
        update.join(5000);

        assertEquals(1, platform.collectedSeq);
        assertEquals(1, platform.decidedSeq);
        assertEquals(2, core.config().seq);
    }

    @Test
    public void backlogIsBoundedAndReplayedToTheFirstListenerOnly() {
        EventHub hub = new EventHub();
        List<ThreatEvent> events = new ArrayList<>();
        for (int i = 0; i < EventHub.BACKLOG_LIMIT + 6; i++) {
            events.add(new ThreatEvent(ThreatCategory.ROOT, 0.5, "id" + i, Action.REPORT, i, null));
        }
        hub.publish(events);

        final List<String> first = new ArrayList<>();
        final List<String> second = new ArrayList<>();
        hub.add(new MobileShield.Listener() {
            @Override public void onThreat(ThreatEvent event) { first.add(event.detectorId); }
        });
        hub.add(new MobileShield.Listener() {
            @Override public void onThreat(ThreatEvent event) { second.add(event.detectorId); }
        });

        assertEquals(EventHub.BACKLOG_LIMIT, first.size());
        assertEquals("id6", first.get(0));
        assertTrue(second.isEmpty());
    }
}
