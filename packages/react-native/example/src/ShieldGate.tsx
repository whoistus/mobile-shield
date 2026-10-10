import React from 'react';
import {ActivityIndicator, AppState, Linking, StyleSheet, Text, View} from 'react-native';
import MobileShield, {
  MobileShieldError,
  type EnvironmentInfo,
  type ThreatEvent,
} from '@whoistus/react-native-mobile-shield';
import {baseConfig} from './shield';

export type GateState = 'checking' | 'ready' | 'blocked' | 'unavailable';

export interface ShieldContextValue {
  env: EnvironmentInfo | null;
  events: ThreatEvent[];
  clearEvents(): void;
  recheck(): Promise<void>;
  initError: string | null;
}

export const ShieldContext = React.createContext<ShieldContextValue>({
  env: null,
  events: [],
  clearEvents: () => {},
  recheck: async () => {},
  initError: null,
});

const MAX_EVENTS = 100;

/**
 * Root-level gate. Everything below renders only while native isBlocked() is false.
 * The flag is re-read from native on start, on foreground, on every incoming deep link
 * and on every BLOCK/KILL event, so a hooked JS layer cannot keep the app unlocked.
 */
export function ShieldGate({children}: {children: React.ReactNode}) {
  const [state, setState] = React.useState<GateState>('checking');
  const [env, setEnv] = React.useState<EnvironmentInfo | null>(null);
  const [events, setEvents] = React.useState<ThreatEvent[]>([]);
  const [initError, setInitError] = React.useState<string | null>(null);

  // Only the init path may grant readiness (after the first native pass completes);
  // foreground / deep-link rechecks can only revoke it.
  const recheck = React.useCallback(async (grant = false) => {
    try {
      const blocked = await MobileShield.isBlocked();
      setState(current => (blocked ? 'blocked' : grant && current === 'checking' ? 'ready' : current));
    } catch (error) {
      setState(error instanceof MobileShieldError && error.code === 'NativeUnavailable' ? 'unavailable' : 'blocked');
    }
  }, []);

  React.useEffect(() => {
    let subscription: {remove(): void} | undefined;
    let cancelled = false;
    try {
      subscription = MobileShield.onThreat(event => {
        setEvents(previous => [event, ...previous].slice(0, MAX_EVENTS));
        if (event.action === 'BLOCK' || event.action === 'KILL') setState('blocked');
      });
    } catch {
      setState('unavailable');
      return;
    }
    (async () => {
      try {
        setEnv(await MobileShield.init(baseConfig()));
      } catch (error) {
        // ConfigRejected leaves the SDK initialised on defaults / last-known-good; anything else is fatal.
        const rejected = error instanceof MobileShieldError && error.code === 'ConfigRejected';
        setInitError(String(error));
        if (!rejected) {
          if (!cancelled) setState(error instanceof MobileShieldError && error.code === 'NativeUnavailable' ? 'unavailable' : 'blocked');
          return;
        }
      }
      if (cancelled) return;
      await recheck(true);
      if (!(await MobileShield.isBlocked())) await MobileShield.startMonitoring();
    })().catch(() => setState('blocked'));

    const appState = AppState.addEventListener('change', next => { if (next === 'active') recheck(false); });
    const link = Linking.addEventListener('url', () => { recheck(false); });
    return () => {
      cancelled = true;
      subscription?.remove();
      appState.remove();
      link.remove();
      MobileShield.stopMonitoring().catch(() => {});
    };
  }, [recheck]);

  const value = React.useMemo(
    () => ({env, events, clearEvents: () => setEvents([]), recheck, initError}),
    [env, events, recheck, initError],
  );

  if (state === 'checking') return <View style={styles.center}><ActivityIndicator /></View>;
  if (state === 'blocked') return <Notice title="Blocked" body="The device or app failed a security policy. Protected features are unavailable." />;
  if (state === 'unavailable') return <Notice title="Security module missing" body="The native MobileShield module is not available in this build. Protected UI is withheld." />;
  return <ShieldContext.Provider value={value}>{children}</ShieldContext.Provider>;
}

function Notice({title, body}: {title: string; body: string}) {
  return (
    <View style={styles.center}>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.body}>{body}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  center: {flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24},
  title: {fontSize: 22, fontWeight: '700', marginBottom: 8},
  body: {fontSize: 15, textAlign: 'center'},
});
