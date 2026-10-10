enum Tier { prod, exp }

class DetectorEntry {
  const DetectorEntry(this.id, this.tier);

  final String id;
  final Tier tier;
}

const androidDetectors = <DetectorEntry>[
  DetectorEntry('root.suPaths', Tier.prod),
  DetectorEntry('root.magiskMounts', Tier.prod),
  DetectorEntry('root.rootbeer', Tier.prod),
  DetectorEntry('emulator.scored', Tier.prod),
  DetectorEntry('debugger.tracerPid', Tier.prod),
  DetectorEntry('debugger.javaDebugger', Tier.prod),
  DetectorEntry('tampering.signature', Tier.prod),
  DetectorEntry('tampering.debuggable', Tier.prod),
  DetectorEntry('tampering.nativeVsJava', Tier.prod),
  DetectorEntry('installer.source', Tier.prod),
  DetectorEntry('screen.captured', Tier.prod),
  DetectorEntry('devoptions.adb', Tier.prod),
  DetectorEntry('devicelock.absent', Tier.prod),
  DetectorEntry('network.vpn', Tier.prod),
  DetectorEntry('root.buildTags', Tier.exp),
  DetectorEntry('hooking.fridaThreads', Tier.exp),
  DetectorEntry('hooking.fridaFd', Tier.exp),
  DetectorEntry('hooking.fridaMaps', Tier.exp),
  DetectorEntry('hooking.dbusProbe', Tier.exp),
  DetectorEntry('hooking.prologue', Tier.exp),
  DetectorEntry('hooking.libIntegrity', Tier.exp),
  DetectorEntry('tampering.memDump', Tier.exp),
];

const iosDetectors = <DetectorEntry>[
  DetectorEntry('jailbreak.paths', Tier.prod),
  DetectorEntry('jailbreak.rootlessPaths', Tier.prod),
  DetectorEntry('jailbreak.urlSchemes', Tier.prod),
  DetectorEntry('jailbreak.sandboxWrite', Tier.prod),
  DetectorEntry('debugger.ptraced', Tier.prod),
  DetectorEntry('tampering.bundleId', Tier.prod),
  DetectorEntry('tampering.teamId', Tier.prod),
  DetectorEntry('simulator', Tier.prod),
  DetectorEntry('devicelock.absent', Tier.prod),
  DetectorEntry('network.proxy', Tier.prod),
  DetectorEntry('screen.captured', Tier.prod),
  DetectorEntry('jailbreak.dyldImages', Tier.exp),
  DetectorEntry('jailbreak.dyldEnv', Tier.exp),
  DetectorEntry('hooking.fridaImages', Tier.exp),
  DetectorEntry('hooking.fridaPort', Tier.exp),
  DetectorEntry('hooking.prologue', Tier.exp),
  DetectorEntry('tampering.provisioning', Tier.exp),
];
