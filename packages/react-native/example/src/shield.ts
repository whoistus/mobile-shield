import {Platform} from 'react-native';
import MobileShield, {type RuntimeConfig} from '@whoistus/react-native-mobile-shield';

export const APP_ID = Platform.select({
  android: 'io.mobileshield.example',
  default: 'org.reactjs.native.example.MobileShieldExample',
});

// Monotonic per run; native rejects a seq older than the persisted last-known-good.
export const nextSeq = (): number => Math.floor(Date.now() / 1000);

export const baseConfig = (): RuntimeConfig => ({version: 1, appId: APP_ID, seq: nextSeq()});

/**
 * Ask native, never JS state, before a protected operation. Call this for restored
 * sessions, deep links, push-opened routes and biometric quick login, not only at login.
 */
export async function ensureNotBlocked(): Promise<void> {
  if (await MobileShield.isBlocked()) throw new Error('Blocked by MobileShield');
}
