#!/usr/bin/env python3
"""Generate config-vectors.json: shared conformance cases for Android and iOS.

Signing uses a TEST-ONLY Ed25519 key (test-ed25519.pem) via the openssl CLI.
Canonical JSON follows RFC 8785 for the value types configs use
(objects with ASCII keys, strings, integers, finite decimals, booleans, arrays).
"""
import base64, json, os, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
KEY = os.path.join(HERE, "test-ed25519.pem")
APP_ID = "io.mobileshield.example"
NOW = 1_800_000_000_000  # fixed clock for vectors (epoch ms)

CATEGORIES = ["ROOT", "EMULATOR", "DEBUGGER", "HOOKING", "TAMPERING", "INSTALLER",
              "SCREEN_CAPTURE", "DEV_OPTIONS_ADB", "NO_DEVICE_LOCK", "VPN_PROXY"]
DEFAULTS = {
    "dev":  {c: "REPORT" for c in CATEGORIES},
    "test": {**{c: "REPORT" for c in CATEGORIES},
             "ROOT": "WARN", "DEBUGGER": "WARN", "HOOKING": "WARN", "TAMPERING": "WARN"},
    "prod": {"ROOT": "BLOCK", "EMULATOR": "BLOCK", "DEBUGGER": "WARN", "HOOKING": "WARN",
             "TAMPERING": "BLOCK", "INSTALLER": "WARN", "SCREEN_CAPTURE": "WARN",
             "DEV_OPTIONS_ADB": "WARN", "NO_DEVICE_LOCK": "WARN", "VPN_PROXY": "REPORT"},
}


def canonical(v):
    if isinstance(v, dict):
        return "{" + ",".join(json.dumps(k) + ":" + canonical(v[k]) for k in sorted(v)) + "}"
    if isinstance(v, list):
        return "[" + ",".join(canonical(x) for x in v) + "]"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return json.dumps(v, ensure_ascii=False)


def public_key_b64():
    der = subprocess.run(["openssl", "pkey", "-in", KEY, "-pubout", "-outform", "DER"],
                         check=True, capture_output=True).stdout
    return base64.b64encode(der[-32:]).decode()  # raw 32-byte key


def sign(cfg):
    body = {k: v for k, v in cfg.items() if k != "signature"}
    with tempfile.NamedTemporaryFile(delete=False) as f:
        f.write(canonical(body).encode())
        path = f.name
    try:
        sig = subprocess.run(["openssl", "pkeyutl", "-sign", "-inkey", KEY, "-rawin", "-in", path],
                             check=True, capture_output=True).stdout
    finally:
        os.unlink(path)
    return {**cfg, "signature": base64.b64encode(sig).decode()}


def cfg(seq=1, **kw):
    c = {"version": 1, "appId": APP_ID, "seq": seq, "policies": {}, "detectors": {}}
    c.update(kw)
    return c


def merged(channel, overrides=None):
    p = dict(DEFAULTS[channel]); p.update(overrides or {}); return p


V = []
def vec(name, channel, config, expect, platform="any", pubkey=False, lkg_seq=None, decisions=None):
    V.append({"name": name, "platform": platform, "channel": channel,
              "bootstrap": {"pubkey": pubkey}, "lastKnownGoodSeq": lkg_seq, "now": NOW,
              "config": config, "expect": expect, "decisions": decisions or []})

for ch in ("dev", "test", "prod"):
    vec(f"defaults-{ch}", ch, cfg(), {"result": "applied", "policies": merged(ch), "events": []})

vec("missing-channel-is-prod", None, cfg(), {"result": "applied", "policies": merged("prod"), "events": []})
vec("host-override-merges", "prod", cfg(policies={"VPN_PROXY": "WARN", "DEBUGGER": "BLOCK"}),
    {"result": "applied", "policies": merged("prod", {"VPN_PROXY": "WARN", "DEBUGGER": "BLOCK"}), "events": []})
vec("detector-disabled", "dev", cfg(detectors={"network.vpn": False}),
    {"result": "applied", "policies": merged("dev"), "disabled": ["network.vpn"], "events": []}, platform="android")
vec("unknown-category-rejected", "dev", cfg(policies={"NOPE": "BLOCK"}),
    {"result": "rejected", "reason": "schema", "events": []})
vec("unknown-action-rejected", "dev", cfg(policies={"ROOT": "EXPLODE"}),
    {"result": "rejected", "reason": "schema", "events": []})
vec("wrong-version-rejected", "dev", cfg(version=2), {"result": "rejected", "reason": "schema", "events": []})
vec("appid-mismatch-rejected", "dev", cfg(appId="com.other.app"), {"result": "rejected", "reason": "schema", "events": []})
vec("interval-below-min-rejected", "dev", cfg(monitoringIntervalMs=500), {"result": "rejected", "reason": "schema", "events": []})

# Floor (prod only).
vec("floor-android-signature-cannot-disable", "prod", cfg(detectors={"tampering.signature": False}),
    {"result": "clamped", "reason": "floor", "policies": merged("prod"), "disabled": [],
     "events": [{"category": "TAMPERING", "detectorId": "policy.floor", "confidence": 0.5, "action": "WARN"}]},
    platform="android")
vec("floor-ios-bundleid-cannot-disable", "prod", cfg(detectors={"tampering.bundleId": False}),
    {"result": "clamped", "reason": "floor", "policies": merged("prod"), "disabled": [],
     "events": [{"category": "TAMPERING", "detectorId": "policy.floor", "confidence": 0.5, "action": "WARN"}]},
    platform="ios")
vec("floor-tampering-min-warn", "prod", cfg(policies={"TAMPERING": "REPORT"}),
    {"result": "clamped", "reason": "floor", "policies": merged("prod", {"TAMPERING": "WARN"}),
     "events": [{"category": "TAMPERING", "detectorId": "policy.floor", "confidence": 0.5, "action": "WARN"}]})
vec("no-floor-outside-prod", "dev", cfg(policies={"TAMPERING": "REPORT"}, detectors={"tampering.signature": False}),
    {"result": "applied", "policies": merged("dev"), "disabled": ["tampering.signature"], "events": []}, platform="android")

# Freshness against last-known-good.
vec("stale-seq-rejected", "dev", cfg(seq=4), {"result": "rejected", "reason": "expired", "events": []}, lkg_seq=5)
vec("equal-seq-accepted", "dev", cfg(seq=5), {"result": "applied", "policies": merged("dev"), "events": []}, lkg_seq=5)
vec("expired-rejected", "dev", cfg(expiresAt=NOW - 1), {"result": "rejected", "reason": "expired", "events": []})
vec("not-yet-expired-accepted", "dev", cfg(expiresAt=NOW + 60_000), {"result": "applied", "policies": merged("dev"), "events": []})

# Signatures (bootstrap pubkey present => signature required).
good = sign(cfg(seq=7, policies={"VPN_PROXY": "WARN"}))
vec("signature-valid", "prod", good,
    {"result": "applied", "policies": merged("prod", {"VPN_PROXY": "WARN"}), "events": []}, pubkey=True)
bad = dict(good); bad["policies"] = {"VPN_PROXY": "BLOCK"}
bad_event = [{"category": "TAMPERING", "detectorId": "policy.badSignature", "confidence": 0.5, "action": "WARN"}]
vec("signature-tampered-body", "prod", bad, {"result": "rejected", "reason": "signature", "events": bad_event}, pubkey=True)
vec("signature-missing", "prod", cfg(seq=7), {"result": "rejected", "reason": "signature", "events": bad_event}, pubkey=True)

# Schema edge cases.
rej_schema = {"result": "rejected", "reason": "schema", "events": []}
vec("threshold-zero-accepted", "dev", cfg(blockThreshold=0), {"result": "applied", "policies": merged("dev"), "events": []})
vec("threshold-one-accepted", "dev", cfg(blockThreshold=1), {"result": "applied", "policies": merged("dev"), "events": []})
vec("threshold-above-one-rejected", "dev", cfg(blockThreshold=1.5), rej_schema)
vec("threshold-negative-rejected", "dev", cfg(blockThreshold=-0.1), rej_schema)
vec("kill-range-valid-accepted", "dev", cfg(killDelayMsRange=[100, 200]), {"result": "applied", "policies": merged("dev"), "events": []})
vec("kill-range-inverted-rejected", "dev", cfg(killDelayMsRange=[5, 1]), rej_schema)
vec("kill-range-wrong-length-rejected", "dev", cfg(killDelayMsRange=[5]), rej_schema)
vec("installer-allowlist-custom-accepted", "dev", cfg(installerAllowlist=["com.corp.mdm"]),
    {"result": "applied", "policies": merged("dev"), "events": []})
vec("installer-allowlist-empty-entry-rejected", "dev", cfg(installerAllowlist=[""]), rej_schema)
vec("detector-flag-not-boolean-rejected", "dev", cfg(detectors={"network.vpn": "no"}), rej_schema)
no_seq = cfg(); del no_seq["seq"]
vec("seq-missing-rejected", "dev", no_seq, rej_schema)
vec("expires-not-a-number-rejected", "dev", cfg(expiresAt="soon"), rej_schema)
# Exact JSON types: a wrong type is a schema rejection, never a silent default or coercion.
vec("policies-array-rejected", "dev", cfg(policies=[]), rej_schema)
vec("policies-null-rejected", "dev", cfg(policies=None), rej_schema)
vec("policy-value-not-string-rejected", "dev", cfg(policies={"ROOT": 2}), rej_schema)
vec("detectors-array-rejected", "dev", cfg(detectors=[]), rej_schema)
vec("seq-fraction-rejected", "dev", cfg(seq=1.5), rej_schema)
vec("seq-string-rejected", "dev", cfg(seq="1"), rej_schema)
vec("seq-bool-rejected", "dev", cfg(seq=True), rej_schema)
vec("version-string-rejected", "dev", cfg(version="1"), rej_schema)
vec("interval-fraction-rejected", "dev", cfg(monitoringIntervalMs=5000.5), rej_schema)
vec("interval-integral-float-accepted", "dev", cfg(monitoringIntervalMs=5000.0),
    {"result": "applied", "policies": merged("dev"), "events": []})
vec("threshold-string-rejected", "dev", cfg(blockThreshold="0.5"), rej_schema)
vec("threshold-bool-rejected", "dev", cfg(blockThreshold=True), rej_schema)
vec("kill-range-not-array-rejected", "dev", cfg(killDelayMsRange={"min": 1, "max": 2}), rej_schema)
vec("kill-range-fraction-rejected", "dev", cfg(killDelayMsRange=[1.5, 3]), rej_schema)
vec("kill-range-string-element-rejected", "dev", cfg(killDelayMsRange=["1", 3]), rej_schema)
vec("installer-allowlist-not-array-rejected", "dev", cfg(installerAllowlist="com.corp.mdm"), rej_schema)
vec("installer-allowlist-non-string-rejected", "dev", cfg(installerAllowlist=["com.corp.mdm", 5]), rej_schema)
vec("expires-fraction-rejected", "dev", cfg(expiresAt=NOW + 0.5), rej_schema)
vec("kill-policy-accepted-when-asked", "prod", cfg(policies={"HOOKING": "KILL"}),
    {"result": "applied", "policies": merged("prod", {"HOOKING": "KILL"}), "events": []})

# Floor edge cases.
vec("floor-tighten-tampering-accepted", "prod", cfg(policies={"TAMPERING": "KILL"}),
    {"result": "applied", "policies": merged("prod", {"TAMPERING": "KILL"}), "events": []})
vec("floor-several-violations-one-event", "prod",
    cfg(policies={"TAMPERING": "REPORT"}, detectors={"tampering.signature": False, "tampering.nativeVsJava": False}),
    {"result": "clamped", "reason": "floor", "policies": merged("prod", {"TAMPERING": "WARN"}), "disabled": [],
     "events": [{"category": "TAMPERING", "detectorId": "policy.floor", "confidence": 0.5, "action": "WARN"}]},
    platform="android")
vec("floor-experimental-ids-may-be-disabled", "prod", cfg(detectors={"hooking.prologue": False, "root.buildTags": False}),
    {"result": "applied", "policies": merged("prod"), "disabled": ["hooking.prologue", "root.buildTags"], "events": []},
    platform="android")
vec("floor-missing-channel-is-prod", None, cfg(policies={"TAMPERING": "REPORT"}),
    {"result": "clamped", "reason": "floor", "policies": merged("prod", {"TAMPERING": "WARN"}),
     "events": [{"category": "TAMPERING", "detectorId": "policy.floor", "confidence": 0.5, "action": "WARN"}]})

# More signature cases (RFC 8785 canonicalisation: non-ASCII strings, decimals, nested arrays).
rich = sign(cfg(seq=9, blockThreshold=0.8, killDelayMsRange=[500, 3000],
                installerAllowlist=["com.example.caf\u00e9", "com.corp.mdm"],
                policies={"ROOT": "WARN", "VPN_PROXY": "WARN"}, detectors={"network.vpn": False}))
vec("signature-valid-canonical-types", "prod", rich,
    {"result": "applied", "policies": merged("prod", {"ROOT": "WARN", "VPN_PROXY": "WARN"}), "events": []}, pubkey=True)
vec("signature-valid-but-stale-seq-rejected", "prod", sign(cfg(seq=3)),
    {"result": "rejected", "reason": "expired", "events": []}, pubkey=True, lkg_seq=5)
vec("signature-valid-but-wrong-appid-rejected", "prod", sign(cfg(appId="com.other.app")), rej_schema, pubkey=True)
vec("signature-empty-rejected", "prod", {**cfg(seq=7), "signature": ""},
    {"result": "rejected", "reason": "signature", "events": bad_event}, pubkey=True)
vec("signature-not-base64-rejected", "prod", {**cfg(seq=7), "signature": "%%%not-base64%%%"},
    {"result": "rejected", "reason": "signature", "events": bad_event}, pubkey=True)
vec("signature-checked-before-schema", "prod", cfg(version=2),
    {"result": "rejected", "reason": "signature", "events": bad_event}, pubkey=True)
vec("signature-not-required-without-bootstrap-key", "prod", cfg(seq=7),
    {"result": "applied", "policies": merged("prod"), "events": []}, pubkey=False)

# Decisions: blockThreshold and experimental tier.
vec("decisions-prod", "prod", cfg(blockThreshold=0.7),
    {"result": "applied", "policies": merged("prod"), "events": []},
    decisions=[
        {"category": "ROOT", "detectorId": "root.suPaths", "confidence": 0.9, "action": "BLOCK", "platform": "android"},
        {"category": "ROOT", "detectorId": "root.suPaths", "confidence": 0.5, "action": "WARN", "platform": "android"},
        {"category": "ROOT", "detectorId": "root.buildTags", "confidence": 1.0, "action": "REPORT", "platform": "android"},
        {"category": "ROOT", "detectorId": "jailbreak.paths", "confidence": 0.9, "action": "BLOCK", "platform": "ios"},
        {"category": "ROOT", "detectorId": "jailbreak.dyldImages", "confidence": 1.0, "action": "REPORT", "platform": "ios"},
        {"category": "VPN_PROXY", "detectorId": "network.vpn", "confidence": 1.0, "action": "REPORT", "platform": "android"},
        {"category": "TAMPERING", "detectorId": "policy.floor", "confidence": 0.5, "action": "WARN", "platform": "any"},
    ])
vec("decisions-kill-opt-in", "prod", cfg(policies={"HOOKING": "KILL"}),
    {"result": "applied", "policies": merged("prod", {"HOOKING": "KILL"}), "events": []},
    decisions=[
        {"category": "HOOKING", "detectorId": "hooking.fridaThreads", "confidence": 1.0, "action": "REPORT", "platform": "android"},
        {"category": "HOOKING", "detectorId": "hooking.fridaImages", "confidence": 1.0, "action": "REPORT", "platform": "ios"},
        {"category": "HOOKING", "detectorId": "hooking.custom", "confidence": 0.8, "action": "KILL", "platform": "any"},
        {"category": "HOOKING", "detectorId": "hooking.custom", "confidence": 0.6, "action": "WARN", "platform": "any"},
    ])

out = {
    "schemaVersion": 1,
    "appId": APP_ID,
    "testPublicKeyEd25519": public_key_b64(),
    "rules": {
        "blockThresholdDefault": 0.7,
        "belowThreshold": "BLOCK or KILL with confidence < blockThreshold is applied as WARN",
        "experimentalTier": "experimental ids are always REPORT",
        "unknownDetectorIds": "treated as prod tier (host-defined ids)",
        "clamped": "config is applied with floor values; updateConfig reports ConfigRejected(floor)",
        "rejected": "config is not applied; last-known-good stays active",
    },
    "experimental": {
        "android": ["root.buildTags", "hooking.fridaThreads", "hooking.fridaFd", "hooking.fridaMaps",
                    "hooking.dbusProbe", "hooking.prologue", "hooking.libIntegrity", "tampering.memDump"],
        "ios": ["jailbreak.dyldImages", "jailbreak.dyldEnv", "hooking.fridaImages", "hooking.fridaPort",
                "hooking.prologue", "tampering.provisioning"],
    },
    "floor": {"android": ["tampering.signature", "tampering.nativeVsJava"],
              "ios": ["tampering.bundleId", "tampering.teamId"], "minTampering": "WARN"},
    "vectors": V,
}
with open(os.path.join(HERE, "config-vectors.json"), "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")
# C++ include for the native policy host test: one row per decision applicable to Android.
CAT = {c: i for i, c in enumerate(CATEGORIES)}
ACT = {"REPORT": 0, "WARN": 1, "BLOCK": 2, "KILL": 3}
rows = []
for v in V:
    pol = v["expect"].get("policies")
    for d in v["decisions"]:
        if d["platform"] not in ("any", "android") or pol is None:
            continue
        acts = ", ".join(str(ACT[pol[c]]) for c in CATEGORIES)
        thr = v["config"].get("blockThreshold", 0.7)
        rows.append(f'    {{"{v["name"]}", {{{acts}}}, {thr}, {CAT[d["category"]]}, "{d["detectorId"]}", '
                    f'{d["confidence"]}, {ACT[d["action"]]}}},')
inc = os.path.join(HERE, "..", "..", "core-android", "core", "src", "test", "cpp", "decision_vectors.inc")
os.makedirs(os.path.dirname(inc), exist_ok=True)
with open(inc, "w") as f:
    f.write("// GENERATED by scripts/fixtures/gen-config-vectors.py. Do not edit.\n")
    f.write("// {name, actions[10], blockThreshold, category, detectorId, confidence, expectedAction}\n")
    f.write("\n".join(rows) + "\n")
print(f"wrote {len(V)} vectors, {len(rows)} android decision rows")
