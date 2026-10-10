import React from 'react';
import {Button, ScrollView, Text, View, Platform} from 'react-native';
import MobileShield, {ThreatEvent} from '@whoistus/react-native-mobile-shield';

export default function App() {
  const [status, setStatus] = React.useState('Starting security checks');
  const [events, setEvents] = React.useState<ThreatEvent[]>([]);
  const [blocked, setBlocked] = React.useState(false);
  React.useEffect(() => {
    const subscription = MobileShield.onThreat(event => {
      setEvents(previous => [event, ...previous].slice(0, 25));
      if (event.action === 'BLOCK' || event.action === 'KILL') setBlocked(true);
    });
    MobileShield.init({version: 1, appId: Platform.select({android: 'com.msrn072', default: 'org.reactjs.native.example.MsRn072'}), seq: 1})
      .then(info => MobileShield.isBlocked().then(value => {
        setBlocked(value);
        setStatus(`${info.sdkVersion} · ${info.platform} · GMS ${info.gmsAvailable}`);
        return MobileShield.startMonitoring();
      }))
      .catch(error => { setBlocked(true); setStatus(String(error)); });
    return () => { subscription.remove(); MobileShield.stopMonitoring(); };
  }, []);
  return <ScrollView style={{padding: 24}}>
    <Text>{status}</Text>
    <Text>{blocked ? 'Protected operations blocked' : 'Ready'}</Text>
    <Button title="Run checks" onPress={() => MobileShield.runChecks().then(setEvents)} />
    {events.map((event, index) => <View key={`${event.detectorId}-${index}`}><Text>{event.detectorId}: {event.action} ({event.confidence})</Text></View>)}
  </ScrollView>;
}
