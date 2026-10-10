import React from 'react';
import {Pressable, SafeAreaView, StyleSheet, Text, View} from 'react-native';
import {ShieldGate} from './src/ShieldGate';
import {EnvironmentScreen} from './src/screens/EnvironmentScreen';
import {EventsScreen} from './src/screens/EventsScreen';
import {RemoteConfigScreen} from './src/screens/RemoteConfigScreen';

const TABS = {Environment: EnvironmentScreen, Events: EventsScreen, 'Remote config': RemoteConfigScreen};
type Tab = keyof typeof TABS;

export default function App() {
  const [tab, setTab] = React.useState<Tab>('Environment');
  const Screen = TABS[tab];
  return (
    <SafeAreaView style={styles.root}>
      <ShieldGate>
        <View style={styles.tabs}>
          {(Object.keys(TABS) as Tab[]).map(name => (
            <Pressable key={name} onPress={() => setTab(name)} style={[styles.tab, tab === name && styles.active]}>
              <Text>{name}</Text>
            </Pressable>
          ))}
        </View>
        <Screen />
      </ShieldGate>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: '#fff'},
  tabs: {flexDirection: 'row', borderBottomWidth: StyleSheet.hairlineWidth},
  tab: {flex: 1, padding: 12, alignItems: 'center'},
  active: {backgroundColor: '#dbe9ff'},
});
