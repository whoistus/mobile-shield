import React from 'react';
import {Pressable, StyleSheet, Text, View} from 'react-native';

export function Button({title, onPress, disabled}: {title: string; onPress: () => void; disabled?: boolean}) {
  return (
    <Pressable onPress={onPress} disabled={disabled} style={[styles.button, disabled && styles.disabled]}>
      <Text style={styles.buttonText}>{title}</Text>
    </Pressable>
  );
}

export function Row({label, value}: {label: string; value: string}) {
  return (
    <View style={styles.row}>
      <Text style={styles.label}>{label}</Text>
      <Text style={styles.value}>{value}</Text>
    </View>
  );
}

export const styles = StyleSheet.create({
  screen: {padding: 16, paddingBottom: 48},
  heading: {fontSize: 18, fontWeight: '700', marginVertical: 8},
  button: {backgroundColor: '#1f6feb', borderRadius: 6, paddingVertical: 10, paddingHorizontal: 14, marginVertical: 4, alignSelf: 'flex-start'},
  disabled: {opacity: 0.4},
  buttonText: {color: '#fff', fontWeight: '600'},
  row: {flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 3},
  label: {color: '#555', flex: 1},
  value: {flex: 2, textAlign: 'right'},
  mono: {fontFamily: 'Courier', fontSize: 12},
  error: {color: '#b42318', marginVertical: 6},
});
