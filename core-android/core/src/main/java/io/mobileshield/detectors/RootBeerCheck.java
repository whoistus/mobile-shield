package io.mobileshield.detectors;

import com.scottyab.rootbeer.RootBeer;
import io.mobileshield.model.ThreatCategory;

/**
 * root.rootbeer: RootBeer's individual checks scored by evidence strength. The aggregate
 * isRooted*() is deliberately not used: it includes detectTestKeys() (custom ROMs, experimental
 * root.buildTags) and the busybox check (not root). See docs/detectors/root.rootbeer.md.
 */
public final class RootBeerCheck implements Detector {
    static final double STRONG = 0.85;
    static final double TWO_WEAK = 0.6;
    static final double ONE_WEAK = 0.4;

    interface Probe { boolean check(RootBeer beer); }

    private static final Probe[] STRONG_PROBES = {
        RootBeer::checkForSuBinary, RootBeer::checkForMagiskBinary, RootBeer::checkForRootNative,
        RootBeer::checkSuExists, RootBeer::detectRootManagementApps,
    };
    private static final Probe[] WEAK_PROBES = {
        RootBeer::checkForDangerousProps, RootBeer::checkForRWPaths,
        RootBeer::detectPotentiallyDangerousApps, RootBeer::detectRootCloakingApps,
    };

    @Override public String id() { return "root.rootbeer"; }
    @Override public ThreatCategory category() { return ThreatCategory.ROOT; }

    @Override public Finding run(DetectorEnv env) {
        try {
            RootBeer beer = new RootBeer(env.context);
            return Finding.hit(score(countHits(beer, STRONG_PROBES), countHits(beer, WEAK_PROBES)));
        } catch (Throwable t) {
            return Finding.UNSUPPORTED;
        }
    }

    static double score(int strongHits, int weakHits) {
        if (strongHits > 0) return STRONG;
        if (weakHits >= 2) return TWO_WEAK;
        return weakHits == 1 ? ONE_WEAK : 0;
    }

    private static int countHits(RootBeer beer, Probe[] probes) {
        int hits = 0;
        for (Probe probe : probes) {
            try {
                if (probe.check(beer)) hits++;
            } catch (Throwable ignored) {
                // One failing probe (e.g. native helper missing) must not discard the others.
            }
        }
        return hits;
    }
}
