# Licensing decision

Decided 2026-10-08.

## Positioning

mobile-shield is an in-house, proprietary SDK for internal use. It is not open source. `LICENSE` is an internal-use notice. Third-party notices still ship in every package because some components are redistributed.

## Ownership

- The C++ detector modules and the secure-API header are in-house work, owned by the company. They move into this repository as-is, with author credit in file headers. Written confirmation of ownership from the company is recorded outside this repository. Without it, the modules are rewritten clean-room.

## Exclusions

- The GPL-licensed ELF symbol helper (derived from LSPosed) is not carried over. Distributing a binary to other apps is distribution, so GPL code would taint the SDK.
- The module that depends on that helper is not carried over either. The library-patch detector is rewritten over `dl_iterate_phdr`.
- No code or binaries from IOSSecuritySuite (custom EULA) or freeRASP (proprietary parts). Their feature lists are used only as checklists.

## Redistributed third-party components

| Component | License | Notice |
|---|---|---|
| RootBeer | Apache-2.0 | THIRD_PARTY_NOTICES.md |
| musl libc syscall headers | MIT | THIRD_PARTY_NOTICES.md |
| Obfuscate | Unlicense | THIRD_PARTY_NOTICES.md |

## Enforcement

`scripts/check-forbidden-strings.sh` runs in CI: no GPL markers or LSPosed references under `core-android` / `core-ios`, and no internal product or company names anywhere in the repository (notices file excluded).
