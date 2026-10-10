export const ThreatCategory = {
  ROOT: 'ROOT',
  EMULATOR: 'EMULATOR',
  DEBUGGER: 'DEBUGGER',
  HOOKING: 'HOOKING',
  TAMPERING: 'TAMPERING',
  INSTALLER: 'INSTALLER',
  SCREEN_CAPTURE: 'SCREEN_CAPTURE',
  DEV_OPTIONS_ADB: 'DEV_OPTIONS_ADB',
  NO_DEVICE_LOCK: 'NO_DEVICE_LOCK',
  VPN_PROXY: 'VPN_PROXY',
} as const;
export type ThreatCategory = (typeof ThreatCategory)[keyof typeof ThreatCategory];

export const Action = {
  REPORT: 'REPORT',
  WARN: 'WARN',
  BLOCK: 'BLOCK',
  KILL: 'KILL',
} as const;
export type Action = (typeof Action)[keyof typeof Action];

export const Severity = {
  LOW: 'LOW',
  MEDIUM: 'MEDIUM',
  HIGH: 'HIGH',
  CRITICAL: 'CRITICAL',
} as const;
export type Severity = (typeof Severity)[keyof typeof Severity];

export const ErrorCode = {
  NativeUnavailable: 'NativeUnavailable',
  NotInitialized: 'NotInitialized',
  BootstrapMissing: 'BootstrapMissing',
  ConfigRejected: 'ConfigRejected',
  DetectorUnsupported: 'DetectorUnsupported',
  AttestationUnsupported: 'AttestationUnsupported',
} as const;
export type ErrorCode = (typeof ErrorCode)[keyof typeof ErrorCode];

export type ConfigRejectedReason = 'signature' | 'floor' | 'schema' | 'expired';

export interface RuntimeConfig {
  version: 1;
  appId: string;
  seq: number;
  signature?: string;
  expiresAt?: number;
  policies?: Partial<Record<ThreatCategory, Action>>;
  detectors?: Record<string, boolean>;
  installerAllowlist?: string[];
  monitoringIntervalMs?: number;
  killDelayMsRange?: [number, number];
  blockThreshold?: number;
}

export interface AppliedConfig {
  channel: 'dev' | 'test' | 'prod';
  policies: Record<ThreatCategory, Action>;
  disabled: string[];
  /** Fields the native floor or experimental-tier rules overrode. */
  clamped: string[];
  /** Detector ids this OS/build cannot run (reported by iOS; absent on Android). */
  unsupportedDetectors?: string[];
  blockThreshold: number;
  monitoringIntervalMs: number;
  killDelayMsRange: [number, number];
  installerAllowlist: string[];
  seq: number;
}

export interface ThreatEvent {
  category: ThreatCategory;
  severity: Severity;
  confidence: number;
  detectorId: string;
  action: Action;
  timestamp: number;
  platform: 'android' | 'ios';
  details?: Record<string, string>;
}

export interface EnvironmentInfo {
  sdkVersion: string;
  platform: 'android' | 'ios';
  osVersion: string;
  abi: string;
  isDebuggable: boolean;
  gmsAvailable: boolean;
  hmsAvailable: boolean;
  installer: string | null;
  attestationKinds: string[];
}

export interface AttestationResult {
  status: 'unsupported';
  kind: string;
}

export interface Subscription {
  remove(): void;
}
