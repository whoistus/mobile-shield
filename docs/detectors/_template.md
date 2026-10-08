# <detector id>

| Field | Value |
|---|---|
| Id | `<category>.<name>` |
| Platform | android / ios |
| Category | one of ThreatCategory |
| Tier | prod / exp |
| Floor | yes / no (prod channel only; yes means cannot be disabled) |

## Supported range
OS versions and ABIs where the detector runs.

## Evidence used
Signals read, at module level (what class of evidence, not how to evade it).

## Baseline source
Where the expected value comes from (build-time pin, system image, bootstrap).

## Known benign matches
Devices, ROMs, tools or configurations that trigger it legitimately.

## Cost
CPU, I/O and timing per run; synchronous or background.

## Confidence rule
How evidence maps to a 0..1 confidence and severity; which combinations may reach `blockThreshold`.

## Unsupported behaviour
What is returned when the detector cannot run (OS/ABI/permission); must not raise a threat.

## Limitations
Known bypass classes at a high level and what covers them.
