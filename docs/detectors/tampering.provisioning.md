# tampering.provisioning

| Field | Value |
|---|---|
| Id | `tampering.provisioning` |
| Platform | ios |
| Category | TAMPERING |
| Tier | exp |
| Floor | no |

## Supported range
iOS 13+, device builds. Simulator: `unsupported`.

## Evidence used
Distribution mode inferred from `embedded.mobileprovision` and the receipt file name: profile with `ProvisionsAllDevices` = enterprise; `get-task-allow` = development; `ProvisionedDevices` = ad hoc; no profile and `sandboxReceipt` = TestFlight; no profile and `receipt` = App Store; otherwise unknown.

## Baseline source
Allowed modes per channel: prod = appStore, testFlight; dev and test = all known modes. Override with Info.plist `MobileShieldDistribution` (comma list of `appStore,testFlight,enterprise,adHoc,development`), for example `enterprise` for an in-house build.

## Known benign matches
Internal enterprise or ad hoc distribution on a prod channel without the override; builds sideloaded by testers.

## Cost
One profile read and one receipt URL lookup per cycle.

## Confidence rule
Expected results (prod channel, no override): App Store clear; TestFlight clear; enterprise 0.60; ad hoc 0.60; development 0.70; unknown 0.50. dev/test channels: every known mode clear, unknown 0.50. Experimental: always REPORT.

## Unsupported behaviour
Simulator: `unsupported`.

## Limitations
Receipt file names are an App Store convention, not a security boundary; a re-signer can embed any profile. Evidence only.
