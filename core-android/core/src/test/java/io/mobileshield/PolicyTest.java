package io.mobileshield;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import io.mobileshield.config.Defaults;
import io.mobileshield.detectors.Detector;
import io.mobileshield.detectors.Detectors;
import io.mobileshield.model.Action;
import io.mobileshield.model.Severity;
import io.mobileshield.model.ThreatCategory;
import io.mobileshield.model.ThreatEvent;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.Test;

/** Channel defaults, launch tiers and the detector registry must agree with design.md and the specs. */
public class PolicyTest {
    private static final Path CPP = Paths.get("src", "main", "cpp");
    private static final Path DOCS = Paths.get("..", "..", "docs", "detectors");

    private static String read(Path p) throws Exception {
        return new String(Files.readAllBytes(p), StandardCharsets.UTF_8);
    }

    private static Set<String> quoted(String text, Pattern p) {
        Set<String> out = new TreeSet<>();
        Matcher m = p.matcher(text);
        while (m.find()) out.add(m.group(1));
        return out;
    }

    private static Set<String> nativeIds() throws Exception {
        Set<String> ids = new TreeSet<>();
        Pattern p = Pattern.compile("id\\(\\) const override \\{ return \"([^\"]+)\"");
        for (String header : new String[] {"RootDetect.h", "AntiDebug.h", "AntiDump.h", "FridaDetect.h", "LibIntegrity.h"}) {
            ids.addAll(quoted(read(CPP.resolve("detectors").resolve(header)), p));
        }
        return ids;
    }

    private static Set<String> androidIds() throws Exception {
        Set<String> ids = new TreeSet<>(nativeIds());
        for (Detector d : Detectors.all()) ids.add(d.id());
        ids.add("screen.captured");
        return ids;
    }

    @Test
    public void prodDefaultsMatchDesign() {
        Map<ThreatCategory, Action> p = Defaults.policies("prod");
        assertEquals(Action.BLOCK, p.get(ThreatCategory.ROOT));
        assertEquals(Action.BLOCK, p.get(ThreatCategory.EMULATOR));
        assertEquals(Action.WARN, p.get(ThreatCategory.DEBUGGER));
        assertEquals(Action.WARN, p.get(ThreatCategory.HOOKING));
        assertEquals(Action.BLOCK, p.get(ThreatCategory.TAMPERING));
        assertEquals(Action.WARN, p.get(ThreatCategory.INSTALLER));
        assertEquals(Action.REPORT, p.get(ThreatCategory.VPN_PROXY));
    }

    @Test
    public void devAndTestDefaultsAreLenient() {
        for (Action a : Defaults.policies("dev").values()) assertEquals(Action.REPORT, a);
        Map<ThreatCategory, Action> t = Defaults.policies("test");
        assertEquals(Action.WARN, t.get(ThreatCategory.ROOT));
        assertEquals(Action.REPORT, t.get(ThreatCategory.EMULATOR));
    }

    @Test
    public void unknownOrMissingChannelFailsClosedToProd() {
        assertEquals("prod", Defaults.channel(null));
        assertEquals("prod", Defaults.channel("staging"));
        assertEquals(Defaults.policies("prod"), Defaults.policies(null));
    }

    @Test
    public void killIsNeverADefault() {
        for (String channel : new String[] {"dev", "test", "prod"}) {
            assertFalse(channel, Defaults.policies(channel).containsValue(Action.KILL));
        }
    }

    @Test
    public void actionsOrderByStrictness() {
        assertTrue(Action.REPORT.ordinal() < Action.WARN.ordinal());
        assertTrue(Action.WARN.ordinal() < Action.BLOCK.ordinal());
        assertTrue(Action.BLOCK.ordinal() < Action.KILL.ordinal());
        assertEquals(Action.REPORT, Action.fromOrdinal(-1));
        assertEquals(Action.REPORT, Action.fromOrdinal(99));
        assertNull(Action.parse("block"));
    }

    @Test
    public void threatEventClampsConfidenceAndDerivesSeverity() {
        ThreatEvent high = new ThreatEvent(ThreatCategory.HOOKING, 7d, "hooking.x", Action.WARN, 1L, null);
        ThreatEvent low = new ThreatEvent(ThreatCategory.ROOT, -3d, "root.x", Action.REPORT, 1L, null);
        assertEquals(1d, high.confidence, 0);
        assertEquals(0d, low.confidence, 0);
        assertEquals(Severity.CRITICAL, high.severity);
        assertTrue(high.details.isEmpty());
        assertTrue(high.toJson().toString().contains("\"platform\":\"android\""));
    }

    @Test
    public void experimentalIdsMatchNativeTiersHeader() throws Exception {
        Set<String> header = quoted(read(CPP.resolve("policy").resolve("Tiers.h")), Pattern.compile("\"([a-zA-Z]+\\.[a-zA-Z]+)\""));
        assertEquals(new TreeSet<>(Defaults.EXPERIMENTAL_IDS), header);
        assertEquals(8, header.size());
    }

    @Test
    public void floorNeverContainsExperimentalIds() {
        Set<String> overlap = new HashSet<>(Defaults.FLOOR_IDS);
        overlap.retainAll(Defaults.EXPERIMENTAL_IDS);
        assertTrue(overlap.isEmpty());
        assertEquals(new HashSet<>(Arrays.asList("tampering.signature", "tampering.nativeVsJava")), Defaults.FLOOR_IDS);
    }

    @Test
    public void registryHasAll22AndroidIds() throws Exception {
        Set<String> ids = androidIds();
        assertEquals(ids.toString(), 22, ids.size());
        assertEquals(10, nativeIds().size());
        assertEquals(11, Detectors.all().size());
    }

    @Test
    public void everyIdHasASpecWhoseTierMatchesTheCode() throws Exception {
        Pattern tier = Pattern.compile("\\| Tier \\| (prod|exp) \\|");
        for (String id : androidIds()) {
            Path spec = DOCS.resolve(id + ".md");
            assertTrue("missing spec " + id, Files.exists(spec));
            Matcher m = tier.matcher(read(spec));
            assertTrue("no Tier row in " + id, m.find());
            assertEquals("tier of " + id, Defaults.EXPERIMENTAL_IDS.contains(id), "exp".equals(m.group(1)));
        }
    }

    @Test
    public void javaDetectorsAreUniqueAndCategorised() {
        List<Detector> all = Detectors.all();
        Set<String> seen = new HashSet<>();
        for (Detector d : all) {
            assertTrue("duplicate " + d.id(), seen.add(d.id()));
            assertTrue(d.id() + " needs a category", d.category() != null);
        }
    }
}
