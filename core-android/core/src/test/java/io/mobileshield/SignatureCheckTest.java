package io.mobileshield;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import io.mobileshield.config.Bootstrap;
import io.mobileshield.detectors.SignatureCheck;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import org.junit.Test;

public class SignatureCheckTest {
    @Test
    public void sha256HexIsLowercaseAndKnown() throws Exception {
        assertEquals("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", SignatureCheck.sha256Hex(new byte[0]));
    }

    @Test
    public void matchingPinPasses() {
        assertTrue(SignatureCheck.matches(Collections.singleton("aa"), "aa"));
    }

    @Test
    public void differentPinFails() {
        assertFalse(SignatureCheck.matches(Collections.singleton("aa"), "bb"));
    }

    @Test
    public void rotationPinsAcceptEitherCertificate() {
        assertTrue(SignatureCheck.matches(Collections.singleton("old"), "old,new"));
        assertTrue(SignatureCheck.matches(Collections.singleton("new"), "old, new"));
    }

    @Test
    public void everySignerMustBePinned() {
        assertFalse(SignatureCheck.matches(new HashSet<>(Arrays.asList("aa", "extra")), "aa"));
        assertTrue(SignatureCheck.matches(new HashSet<>(Arrays.asList("aa", "bb")), "aa,bb"));
    }

    @Test
    public void missingPinOrSignersNeverMatch() {
        assertFalse(SignatureCheck.matches(Collections.singleton("aa"), null));
        assertFalse(SignatureCheck.matches(Collections.<String>emptySet(), "aa"));
        assertFalse(SignatureCheck.matches(Collections.singleton("aa"), " , "));
    }

    @Test
    public void bootstrapNormalisesPinFormats() {
        Bootstrap b = new Bootstrap("prod", null, "AA:BB:CC, dd:ee", "x");
        assertEquals("aabbcc,ddee", b.signingSha256);
        assertNull(new Bootstrap("prod", null, " , ", "x").signingSha256);
        assertNull(new Bootstrap("prod", null, null, "x").signingSha256);
    }
}
