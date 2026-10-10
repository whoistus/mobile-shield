package io.mobileshield.detectors;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class RootBeerScoreTest {
    @Test
    public void strongEvidenceWins() {
        assertEquals(RootBeerCheck.STRONG, RootBeerCheck.score(1, 0), 0);
        assertEquals(RootBeerCheck.STRONG, RootBeerCheck.score(2, 4), 0);
    }

    @Test
    public void weakEvidenceStaysBelowTheDefaultBlockThreshold() {
        assertEquals(0, RootBeerCheck.score(0, 0), 0);
        assertEquals(RootBeerCheck.ONE_WEAK, RootBeerCheck.score(0, 1), 0);
        assertEquals(RootBeerCheck.TWO_WEAK, RootBeerCheck.score(0, 3), 0);
        assertEquals(true, RootBeerCheck.TWO_WEAK < 0.7);
    }
}
