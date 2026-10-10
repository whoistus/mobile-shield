export type Tier = 'prod' | 'exp';
export type DetectorPlatform = 'android' | 'ios';
export interface DetectorEntry {
  id: string;
  platform: DetectorPlatform;
  tier: Tier;
}

const entries = (platform: DetectorPlatform, tier: Tier, ids: string[]): DetectorEntry[] =>
  ids.map(id => ({id, platform, tier}));

// Registry from design.md: 22 Android + 17 iOS = 39 entries (devicelock.absent, screen.captured and hooking.prologue exist on both).
export const DETECTORS: DetectorEntry[] = [
  ...entries('android', 'prod', [
    'root.suPaths', 'root.magiskMounts', 'root.rootbeer', 'emulator.scored', 'debugger.tracerPid',
    'debugger.javaDebugger', 'tampering.signature', 'tampering.debuggable', 'tampering.nativeVsJava',
    'installer.source', 'screen.captured', 'devoptions.adb', 'devicelock.absent', 'network.vpn',
  ]),
  ...entries('android', 'exp', [
    'root.buildTags', 'hooking.fridaThreads', 'hooking.fridaFd', 'hooking.fridaMaps', 'hooking.dbusProbe',
    'hooking.prologue', 'hooking.libIntegrity', 'tampering.memDump',
  ]),
  ...entries('ios', 'prod', [
    'jailbreak.paths', 'jailbreak.rootlessPaths', 'jailbreak.urlSchemes', 'jailbreak.sandboxWrite',
    'debugger.ptraced', 'tampering.bundleId', 'tampering.teamId', 'simulator', 'devicelock.absent',
    'network.proxy', 'screen.captured',
  ]),
  ...entries('ios', 'exp', [
    'jailbreak.dyldImages', 'jailbreak.dyldEnv', 'hooking.fridaImages', 'hooking.fridaPort',
    'hooking.prologue', 'tampering.provisioning',
  ]),
];
