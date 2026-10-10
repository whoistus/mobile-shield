import React from 'react';
import {ScrollView, Text} from 'react-native';
import MobileShield, {MobileShieldError} from '@whoistus/react-native-mobile-shield';
import {ShieldContext} from '../ShieldGate';
import {ensureNotBlocked} from '../shield';
import {Button, Row, styles} from '../ui';

export function EnvironmentScreen() {
  const {env, initError, recheck} = React.useContext(ShieldContext);
  const [sdkVersion, setSdkVersion] = React.useState('...');
  const [message, setMessage] = React.useState('');

  React.useEffect(() => {
    MobileShield.getSdkVersion().then(setSdkVersion, e => setSdkVersion(String(e)));
  }, []);

  const restoreSession = async () => {
    try {
      await ensureNotBlocked();
      setMessage('Restored session: native says not blocked');
    } catch (e) {
      setMessage(String(e));
      await recheck();
    }
  };

  const attest = async () => {
    try {
      const result = await MobileShield.attestEnrol('play-integrity', 'nonce');
      setMessage(`attestEnrol: ${JSON.stringify(result)}`);
    } catch (e) {
      setMessage(e instanceof MobileShieldError ? `${e.code} ${e.reason ?? ''}` : String(e));
    }
  };

  return (
    <ScrollView contentContainerStyle={styles.screen}>
      <Text style={styles.heading}>Environment</Text>
      <Row label="getSdkVersion()" value={sdkVersion} />
      {env ? (
        <>
          <Row label="platform" value={env.platform} />
          <Row label="osVersion" value={env.osVersion} />
          <Row label="abi" value={env.abi} />
          <Row label="isDebuggable" value={String(env.isDebuggable)} />
          <Row label="gmsAvailable" value={String(env.gmsAvailable)} />
          <Row label="hmsAvailable" value={String(env.hmsAvailable)} />
          <Row label="installer" value={env.installer ?? 'null'} />
          <Row label="attestationKinds" value={env.attestationKinds.join(',') || '[]'} />
        </>
      ) : (
        <Text style={styles.error}>init did not return EnvironmentInfo{initError ? `: ${initError}` : ''}</Text>
      )}
      <Text style={styles.heading}>Gating</Text>
      <Button title="Restore session (re-checks native isBlocked)" onPress={restoreSession} />
      <Button title="attestEnrol (expects unsupported)" onPress={attest} />
      {message ? <Text style={styles.mono}>{message}</Text> : null}
    </ScrollView>
  );
}
