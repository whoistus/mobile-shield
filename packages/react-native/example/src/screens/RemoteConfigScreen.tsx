import React from 'react';
import {Platform, ScrollView, Switch, Text, View} from 'react-native';
import MobileShield, {
  Action,
  MobileShieldError,
  ThreatCategory,
  type AppliedConfig,
  type RuntimeConfig,
} from '@whoistus/react-native-mobile-shield';
import {DETECTORS} from '../detectors';
import {baseConfig} from '../shield';
import {Button, Row, styles} from '../ui';

const ACTIONS = Object.values(Action);
const CATEGORIES = Object.values(ThreatCategory);

export function RemoteConfigScreen() {
  const [enabled, setEnabled] = React.useState<Record<string, boolean>>(
    () => Object.fromEntries(DETECTORS.map(d => [d.id, true])),
  );
  const [actions, setActions] = React.useState<Partial<Record<ThreatCategory, Action>>>({});
  const [applied, setApplied] = React.useState<AppliedConfig | null>(null);
  const [requestedOff, setRequestedOff] = React.useState<string[]>([]);
  const [error, setError] = React.useState('');
  const [onlyThisPlatform, setOnlyThisPlatform] = React.useState(true);

  const refresh = async () => {
    try {
      setApplied(await MobileShield.getConfig());
      setError('');
    } catch (e) {
      setError(String(e));
    }
  };

  const apply = async () => {
    const config: RuntimeConfig = {...baseConfig(), detectors: enabled, policies: actions};
    try {
      setApplied(await MobileShield.updateConfig(config));
      setRequestedOff(Object.keys(enabled).filter(id => !enabled[id]));
      setError('');
    } catch (e) {
      setError(e instanceof MobileShieldError ? `${e.code}${e.reason ? `(${e.reason})` : ''}: ${e.message}` : String(e));
      await refresh();
    }
  };

  const cycle = (category: ThreatCategory) =>
    setActions(prev => {
      const next = ACTIONS[(ACTIONS.indexOf(prev[category] ?? 'REPORT') + 1) % ACTIONS.length];
      return {...prev, [category]: next};
    });

  const visible = DETECTORS.filter(d => !onlyThisPlatform || d.platform === Platform.OS);

  return (
    <ScrollView contentContainerStyle={styles.screen}>
      <Text style={styles.heading}>Policies (tap to cycle)</Text>
      {CATEGORIES.map(category => (
        <Button key={category} title={`${category}: ${actions[category] ?? 'default'}`} onPress={() => cycle(category)} />
      ))}
      <Text style={styles.heading}>Detectors ({visible.length} of {DETECTORS.length} entries)</Text>
      <Row label="Show this platform only" value="" />
      <Switch value={onlyThisPlatform} onValueChange={setOnlyThisPlatform} />
      {visible.map(d => {
        const keptByNative = requestedOff.includes(d.id) && applied != null && !applied.disabled.includes(d.id);
        const unsupported = applied?.unsupportedDetectors?.includes(d.id);
        return (
          <View key={`${d.platform}-${d.id}`} style={styles.row}>
            <Text style={[styles.label, styles.mono]}>
              {d.id} [{d.platform}/{d.tier}]{keptByNative ? ' CLAMPED ON' : ''}{unsupported ? ' UNSUPPORTED' : ''}
            </Text>
            <Switch value={enabled[d.id]} onValueChange={v => setEnabled(prev => ({...prev, [d.id]: v}))} />
          </View>
        );
      })}
      <Button title="updateConfig(...)" onPress={apply} />
      <Button title="getConfig()" onPress={refresh} />
      {error ? <Text style={styles.error}>{error}</Text> : null}
      {applied ? (
        <>
          <Text style={styles.heading}>Applied by native</Text>
          <Row label="channel" value={applied.channel} />
          <Row label="seq" value={String(applied.seq)} />
          <Row label="blockThreshold" value={String(applied.blockThreshold)} />
          <Row label="monitoringIntervalMs" value={String(applied.monitoringIntervalMs)} />
          <Text style={styles.mono}>clamped: {JSON.stringify(applied.clamped)}</Text>
          <Text style={styles.mono}>disabled: {JSON.stringify(applied.disabled)}</Text>
          {applied.unsupportedDetectors ? <Text style={styles.mono}>unsupported: {JSON.stringify(applied.unsupportedDetectors)}</Text> : null}
          <Text style={styles.mono}>policies: {JSON.stringify(applied.policies)}</Text>
        </>
      ) : null}
    </ScrollView>
  );
}
