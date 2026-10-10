package io.mobileshield.config;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import org.json.JSONArray;
import org.json.JSONObject;

/**
 * RFC 8785 (JCS) canonical JSON for the value types configs use: objects, arrays, strings,
 * booleans, null and finite numbers. Keys sort by UTF-16 code units (String.compareTo).
 */
public final class CanonicalJson {
    private CanonicalJson() {}

    public static String of(Object value) {
        StringBuilder sb = new StringBuilder();
        write(sb, value);
        return sb.toString();
    }

    private static void write(StringBuilder sb, Object v) {
        if (v == null || v == JSONObject.NULL) {
            sb.append("null");
        } else if (v instanceof JSONObject) {
            JSONObject o = (JSONObject) v;
            List<String> keys = new ArrayList<>();
            for (Iterator<String> it = o.keys(); it.hasNext(); ) keys.add(it.next());
            Collections.sort(keys);
            sb.append('{');
            for (int i = 0; i < keys.size(); i++) {
                if (i > 0) sb.append(',');
                string(sb, keys.get(i));
                sb.append(':');
                write(sb, o.opt(keys.get(i)));
            }
            sb.append('}');
        } else if (v instanceof JSONArray) {
            JSONArray a = (JSONArray) v;
            sb.append('[');
            for (int i = 0; i < a.length(); i++) {
                if (i > 0) sb.append(',');
                write(sb, a.opt(i));
            }
            sb.append(']');
        } else if (v instanceof Boolean) {
            sb.append(((Boolean) v) ? "true" : "false");
        } else if (v instanceof Number) {
            number(sb, (Number) v);
        } else {
            string(sb, v.toString());
        }
    }

    /**
     * ECMAScript Number-to-String (RFC 8785 section 3.2.2.3). The shortest digit string that
     * round-trips is found by rounding the exact value to 1..17 digits, so the result does not
     * depend on the JVM's Double.toString implementation.
     */
    private static void number(StringBuilder sb, Number n) {
        double d = n.doubleValue();
        if (Double.isNaN(d) || Double.isInfinite(d)) throw new IllegalArgumentException("non-finite number");
        if (d == 0) {
            sb.append('0');
            return;
        }
        if (d < 0) {
            sb.append('-');
            d = -d;
        }
        BigDecimal exact = new BigDecimal(d);
        BigDecimal shortest = exact;
        for (int precision = 1; precision <= 17; precision++) {
            BigDecimal candidate = exact.round(new MathContext(precision, RoundingMode.HALF_EVEN));
            if (Double.parseDouble(candidate.toString()) == d) {
                shortest = candidate;
                break;
            }
        }
        shortest = shortest.stripTrailingZeros();
        String digits = shortest.unscaledValue().toString();
        int k = digits.length();
        int pointPos = k - shortest.scale();
        if (k <= pointPos && pointPos <= 21) {
            sb.append(digits);
            for (int i = 0; i < pointPos - k; i++) sb.append('0');
        } else if (0 < pointPos && pointPos <= 21) {
            sb.append(digits, 0, pointPos).append('.').append(digits, pointPos, k);
        } else if (-6 < pointPos && pointPos <= 0) {
            sb.append("0.");
            for (int i = 0; i < -pointPos; i++) sb.append('0');
            sb.append(digits);
        } else {
            int exponent = pointPos - 1;
            sb.append(digits.charAt(0));
            if (k > 1) sb.append('.').append(digits, 1, k);
            sb.append('e').append(exponent < 0 ? '-' : '+').append(Math.abs(exponent));
        }
    }

    private static void string(StringBuilder sb, String s) {
        sb.append('"');
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"': sb.append("\\\""); break;
                case '\\': sb.append("\\\\"); break;
                case '\b': sb.append("\\b"); break;
                case '\f': sb.append("\\f"); break;
                case '\n': sb.append("\\n"); break;
                case '\r': sb.append("\\r"); break;
                case '\t': sb.append("\\t"); break;
                default:
                    if (c < 0x20) sb.append(String.format("\\u%04x", (int) c));
                    else sb.append(c);
            }
        }
        sb.append('"');
    }
}
