import {THREAT_EVENT, MobileShieldError, readyModule, threatEmitter, toMobileShieldError} from './NativeMobileShield';
import type {
  AppliedConfig,
  AttestationResult,
  EnvironmentInfo,
  RuntimeConfig,
  Subscription,
  ThreatEvent,
} from './types';

export * from './types';
export {MobileShieldError};

async function call<T>(fn: (native: Awaited<ReturnType<typeof readyModule>>) => Promise<T>): Promise<T> {
  try {
    return await fn(await readyModule());
  } catch (error) {
    throw toMobileShieldError(error);
  }
}

const parse = <T>(raw: string): T => JSON.parse(raw) as T;

/**
 * JS only forwards config, subscribes to events and reads native state. Enforcement
 * (policy, floor, blocking) is decided natively; gate protected flows on isBlocked().
 */
export const MobileShield = {
  getSdkVersion: (): Promise<string> => call(n => n.getSdkVersion()),

  async init(config: RuntimeConfig): Promise<EnvironmentInfo> {
    return parse(await call(n => n.init(JSON.stringify(config))));
  },

  async updateConfig(config: RuntimeConfig): Promise<AppliedConfig> {
    return parse(await call(n => n.updateConfig(JSON.stringify(config))));
  },

  async getConfig(): Promise<AppliedConfig> {
    return parse(await call(n => n.getConfig()));
  },

  async runChecks(): Promise<ThreatEvent[]> {
    return parse(await call(n => n.runChecks()));
  },

  async startMonitoring(): Promise<void> {
    await call(n => n.startMonitoring());
  },

  async stopMonitoring(): Promise<void> {
    await call(n => n.stopMonitoring());
  },

  isBlocked: (): Promise<boolean> => call(async n => (await n.isBlocked()) === true),

  async attestEnrol(kind: string, nonce: string): Promise<AttestationResult> {
    return parse(await call(n => n.attestEnrol(kind, nonce)));
  },

  async attestAssert(kind: string, nonce: string, requestHash: string): Promise<AttestationResult> {
    return parse(await call(n => n.attestAssert(kind, nonce, requestHash)));
  },

  /** Throws NativeUnavailable synchronously when the native module is missing. */
  onThreat(callback: (event: ThreatEvent) => void): Subscription {
    let emitter;
    try {
      emitter = threatEmitter();
    } catch (error) {
      throw toMobileShieldError(error);
    }
    const subscription = emitter.addListener(THREAT_EVENT, (raw: string) => {
      let event: ThreatEvent;
      try {
        event = parse<ThreatEvent>(raw);
      } catch {
        return;
      }
      callback(event);
    });
    return {remove: () => subscription.remove()};
  },
};

export default MobileShield;
