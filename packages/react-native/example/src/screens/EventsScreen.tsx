import React from 'react';
import {ScrollView, Text, View} from 'react-native';
import MobileShield from '@whoistus/react-native-mobile-shield';
import {ShieldContext} from '../ShieldGate';
import {Button, styles} from '../ui';

export function EventsScreen() {
  const {events, clearEvents, recheck} = React.useContext(ShieldContext);
  const [monitoring, setMonitoring] = React.useState(true);
  const [error, setError] = React.useState('');

  const run = async (fn: () => Promise<unknown>) => {
    try {
      setError('');
      await fn();
    } catch (e) {
      setError(String(e));
    }
    await recheck();
  };

  return (
    <ScrollView contentContainerStyle={styles.screen}>
      <Text style={styles.heading}>Controls</Text>
      <Button title="runChecks()" onPress={() => run(() => MobileShield.runChecks())} />
      <Button
        title={monitoring ? 'stopMonitoring()' : 'startMonitoring()'}
        onPress={() => run(async () => {
          if (monitoring) await MobileShield.stopMonitoring(); else await MobileShield.startMonitoring();
          setMonitoring(!monitoring);
        })}
      />
      <Button title="Clear list" onPress={clearEvents} />
      {error ? <Text style={styles.error}>{error}</Text> : null}
      <Text style={styles.heading}>onThreat events ({events.length})</Text>
      {events.map((event, index) => (
        <View key={`${event.timestamp}-${event.detectorId}-${index}`} style={{marginBottom: 6}}>
          <Text style={styles.mono}>
            {event.action} {event.category} {event.detectorId} conf={event.confidence.toFixed(2)} {event.severity}
          </Text>
          {event.details ? <Text style={styles.mono}>{JSON.stringify(event.details)}</Text> : null}
        </View>
      ))}
    </ScrollView>
  );
}
