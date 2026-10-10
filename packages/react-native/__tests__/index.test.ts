const listeners: Record<string, Array<(payload: string) => void>> = {};
const addListener = jest.fn((name: string, cb: (payload: string) => void) => {
  (listeners[name] ||= []).push(cb);
  return {remove: jest.fn(() => { listeners[name] = listeners[name].filter(l => l !== cb); })};
});
const nativeModules: Record<string, unknown> = {};

jest.mock('react-native', () => ({
  NativeModules: nativeModules,
  NativeEventEmitter: jest.fn().mockImplementation(() => ({addListener})),
}));

const EVENT = 'MobileShield.onThreat';

function fakeNative(overrides: Record<string, unknown> = {}) {
  return {
    getSdkVersion: jest.fn().mockResolvedValue('0.1.0'),
    init: jest.fn().mockResolvedValue(JSON.stringify({sdkVersion: '0.1.0', platform: 'android'})),
    updateConfig: jest.fn().mockResolvedValue(JSON.stringify({channel: 'prod', clamped: ['policies.TAMPERING']})),
    getConfig: jest.fn().mockResolvedValue(JSON.stringify({channel: 'prod', seq: 3})),
    runChecks: jest.fn().mockResolvedValue(JSON.stringify([{detectorId: 'root.suPaths', action: 'BLOCK'}])),
    startMonitoring: jest.fn().mockResolvedValue(undefined),
    stopMonitoring: jest.fn().mockResolvedValue(undefined),
    isBlocked: jest.fn().mockResolvedValue(false),
    attestEnrol: jest.fn().mockResolvedValue(JSON.stringify({status: 'unsupported', kind: 'k'})),
    attestAssert: jest.fn().mockResolvedValue(JSON.stringify({status: 'unsupported', kind: 'k'})),
    addListener: jest.fn(),
    removeListeners: jest.fn(),
    ...overrides,
  };
}

function load(native?: ReturnType<typeof fakeNative>) {
  jest.resetModules();
  for (const key of Object.keys(nativeModules)) delete nativeModules[key];
  for (const key of Object.keys(listeners)) delete listeners[key];
  if (native) nativeModules.MobileShield = native;
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  return require('../src') as typeof import('../src');
}

const config = {version: 1 as const, appId: 'com.example', seq: 7, detectors: {'root.suPaths': false}};

describe('config passthrough', () => {
  it('serialises the exact config as JSON for init and updateConfig', async () => {
    const native = fakeNative();
    const {MobileShield} = load(native);
    const info = await MobileShield.init(config);
    expect(JSON.parse(native.init.mock.calls[0][0])).toEqual(config);
    expect(info.platform).toBe('android');
    const applied = await MobileShield.updateConfig(config);
    expect(JSON.parse(native.updateConfig.mock.calls[0][0])).toEqual(config);
    expect(applied.clamped).toEqual(['policies.TAMPERING']);
    expect(native.init.mock.calls[0][0]).toContain('"seq":7');
  });

  it('forwards arguments and parses native results', async () => {
    const native = fakeNative({isBlocked: jest.fn().mockResolvedValue(true)});
    const {MobileShield} = load(native);
    expect(await MobileShield.getConfig()).toEqual({channel: 'prod', seq: 3});
    expect(await MobileShield.runChecks()).toEqual([{detectorId: 'root.suPaths', action: 'BLOCK'}]);
    expect(await MobileShield.isBlocked()).toBe(true);
    await MobileShield.startMonitoring();
    await MobileShield.stopMonitoring();
    expect(native.startMonitoring).toHaveBeenCalledTimes(1);
    expect(native.stopMonitoring).toHaveBeenCalledTimes(1);
    expect(await MobileShield.attestEnrol('k', 'n')).toEqual({status: 'unsupported', kind: 'k'});
    await MobileShield.attestAssert('k', 'n', 'h');
    expect(native.attestAssert).toHaveBeenCalledWith('k', 'n', 'h');
  });
});

describe('event mapping', () => {
  it('parses native JSON payloads and returns a removable subscription', () => {
    const {MobileShield} = load(fakeNative());
    const seen: unknown[] = [];
    const subscription = MobileShield.onThreat(e => seen.push(e));
    expect(addListener).toHaveBeenCalledWith(EVENT, expect.any(Function));
    const event = {category: 'ROOT', detectorId: 'root.suPaths', action: 'BLOCK', confidence: 0.9};
    listeners[EVENT][0](JSON.stringify(event));
    expect(seen).toEqual([event]);
    subscription.remove();
    expect(listeners[EVENT]).toHaveLength(0);
  });

  it('drops malformed payloads without throwing', () => {
    const {MobileShield} = load(fakeNative());
    const cb = jest.fn();
    MobileShield.onThreat(cb);
    expect(() => listeners[EVENT][0]('not json')).not.toThrow();
    expect(cb).not.toHaveBeenCalled();
  });
});

describe('missing-module guard', () => {
  it('rejects every call with NativeUnavailable when the module is absent', async () => {
    const {MobileShield, MobileShieldError} = load();
    await expect(MobileShield.init(config)).rejects.toMatchObject({code: 'NativeUnavailable'});
    await expect(MobileShield.isBlocked()).rejects.toBeInstanceOf(MobileShieldError);
    await expect(MobileShield.getSdkVersion()).rejects.toMatchObject({code: 'NativeUnavailable'});
  });

  it('throws NativeUnavailable synchronously from onThreat', () => {
    const {MobileShield} = load();
    let thrown: unknown;
    try { MobileShield.onThreat(() => {}); } catch (e) { thrown = e; }
    expect(thrown).toMatchObject({code: 'NativeUnavailable'});
  });

  it('treats an empty getSdkVersion as unavailable and does not cache the failure', async () => {
    const native = fakeNative({getSdkVersion: jest.fn().mockResolvedValueOnce('').mockResolvedValue('0.1.0')});
    const {MobileShield} = load(native);
    await expect(MobileShield.isBlocked()).rejects.toMatchObject({code: 'NativeUnavailable'});
    await expect(MobileShield.isBlocked()).resolves.toBe(false);
  });

  it('probes getSdkVersion once after success', async () => {
    const native = fakeNative();
    const {MobileShield} = load(native);
    await MobileShield.isBlocked();
    await MobileShield.getConfig();
    expect(native.getSdkVersion).toHaveBeenCalledTimes(1);
  });
});

describe('error mapping', () => {
  const rejectWith = (code: string, userInfo?: {reason: string}) =>
    jest.fn().mockRejectedValue(Object.assign(new Error('native: ' + code), {code, userInfo}));

  it.each(['NotInitialized', 'BootstrapMissing', 'DetectorUnsupported', 'AttestationUnsupported', 'NativeUnavailable'])(
    'maps %s',
    async code => {
      const {MobileShield, MobileShieldError} = load(fakeNative({getConfig: rejectWith(code)}));
      const error = await MobileShield.getConfig().catch(e => e);
      expect(error).toBeInstanceOf(MobileShieldError);
      expect(error.code).toBe(code);
      expect(error.reason).toBeUndefined();
    },
  );

  it.each(['signature', 'floor', 'schema', 'expired'])('maps ConfigRejected reason %s', async reason => {
    const {MobileShield} = load(fakeNative({updateConfig: rejectWith('ConfigRejected', {reason})}));
    const error = await MobileShield.updateConfig(config).catch(e => e);
    expect(error).toMatchObject({code: 'ConfigRejected', reason});
  });

  it('accepts the dotted ConfigRejected.<reason> code form', async () => {
    const {MobileShield} = load(fakeNative({init: rejectWith('ConfigRejected.floor')}));
    await expect(MobileShield.init(config)).rejects.toMatchObject({code: 'ConfigRejected', reason: 'floor'});
  });

  it('maps unknown native failures to NativeUnavailable', async () => {
    const {MobileShield} = load(fakeNative({runChecks: jest.fn().mockRejectedValue(new Error('boom'))}));
    await expect(MobileShield.runChecks()).rejects.toMatchObject({code: 'NativeUnavailable', message: 'boom'});
  });
});
