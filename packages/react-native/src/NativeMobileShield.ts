import {NativeEventEmitter, NativeModules} from 'react-native';
import {ErrorCode, type ConfigRejectedReason} from './types';

export const THREAT_EVENT = 'MobileShield.onThreat';

export class MobileShieldError extends Error {
  readonly code: ErrorCode;
  readonly reason?: ConfigRejectedReason;
  constructor(code: ErrorCode, message: string, reason?: ConfigRejectedReason) {
    super(message);
    this.name = 'MobileShieldError';
    this.code = code;
    this.reason = reason;
    Object.setPrototypeOf(this, MobileShieldError.prototype);
  }
}

export interface NativeMobileShieldModule {
  getSdkVersion(): Promise<string>;
  init(configJson: string): Promise<string>;
  updateConfig(configJson: string): Promise<string>;
  getConfig(): Promise<string>;
  runChecks(): Promise<string>;
  startMonitoring(): Promise<void>;
  stopMonitoring(): Promise<void>;
  isBlocked(): Promise<boolean>;
  attestEnrol(kind: string, nonce: string): Promise<string>;
  attestAssert(kind: string, nonce: string, requestHash: string): Promise<string>;
  addListener(eventName: string): void;
  removeListeners(count: number): void;
}

const CODES = Object.values(ErrorCode) as string[];
const REASONS = ['signature', 'floor', 'schema', 'expired'];

export function toMobileShieldError(error: unknown): MobileShieldError {
  if (error instanceof MobileShieldError) return error;
  const e = (error ?? {}) as {code?: unknown; message?: unknown; userInfo?: {reason?: unknown}};
  const message = typeof e.message === 'string' ? e.message : String(error);
  const [head, tail] = typeof e.code === 'string' ? e.code.split('.') : [];
  if (head && CODES.includes(head)) {
    const raw = e.userInfo?.reason ?? tail;
    const reason =
      head === ErrorCode.ConfigRejected && typeof raw === 'string' && REASONS.includes(raw)
        ? (raw as ConfigRejectedReason)
        : undefined;
    return new MobileShieldError(head as ErrorCode, message, reason);
  }
  return new MobileShieldError(ErrorCode.NativeUnavailable, message);
}

const unavailable = (why: string) => new MobileShieldError(ErrorCode.NativeUnavailable, `MobileShield: ${why}`);

function nativeModule(): NativeMobileShieldModule {
  const native = (NativeModules as {MobileShield?: Partial<NativeMobileShieldModule>}).MobileShield;
  if (!native || typeof native.getSdkVersion !== 'function') {
    throw unavailable('native module is not linked (JS shipped ahead of the native binary?)');
  }
  return native as NativeMobileShieldModule;
}

let verified: Promise<NativeMobileShieldModule> | undefined;

/** Module presence + getSdkVersion() probe; cached after the first success. */
export function readyModule(): Promise<NativeMobileShieldModule> {
  if (!verified) {
    verified = (async () => {
      const native = nativeModule();
      const version = await native.getSdkVersion();
      if (typeof version !== 'string' || version.length === 0) throw unavailable('native module reports no SDK version');
      return native;
    })().catch(error => {
      verified = undefined;
      throw toMobileShieldError(error);
    });
  }
  return verified;
}

let emitter: NativeEventEmitter | undefined;

export function threatEmitter(): NativeEventEmitter {
  if (!emitter) emitter = new NativeEventEmitter(nativeModule() as never);
  return emitter;
}
