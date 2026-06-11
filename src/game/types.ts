import type { SymbolId } from '../content/symbols';
import type { AbilityId } from '../content/abilities';

export type { SymbolId, AbilityId };

export type UpgradeId = string;
export type ConsumableId = string;
export type EndingType = 'flatline' | 'wealth' | 'exit';

export type ReelResult = [SymbolId, SymbolId, SymbolId];
export type WinType = 'jackpot' | 'triple' | 'pair' | 'miss';

export interface SpinInput {
  readonly neurons: number;
  readonly neuronDecayAmount: number;  // pre-computed by state layer from upgrades
  readonly freeSpinsRemaining: number;
  readonly maxFreeSpins: number;
  readonly lucidityMultiplier: number; // combined from all active effects
  readonly isFreeSpin: boolean;
  readonly lockedReels: ReadonlyArray<boolean>; // [r0, r1, r2] — locked reels keep previous symbol
  readonly previousReels: ReelResult | null;    // needed when lockedReels has any true
  readonly rng: () => number;
}

export interface SpinResult {
  readonly reels: ReelResult;
  readonly lucidityEarned: number;
  readonly neuronsAfter: number;
  readonly freeSpinsGranted: number;  // always 0 if isFreeSpin === true
  readonly freeSpinsAfter: number;
  readonly isJackpot: boolean;
  readonly isFreeSpin: boolean;
  readonly winType: WinType;
}

export interface RunState {
  readonly neurons: number;
  readonly startingNeurons: number;
  readonly lucidityEarned: number;
  readonly freeSpinsRemaining: number;
  readonly maxFreeSpins: number;
  readonly lucidityMultiplier: number;
  readonly nextSpinLucidityMultiplier: number; // from consumable, resets after spin
  readonly isSpinning: boolean;
  readonly lastResult: SpinResult | null;
  readonly lockedReels: [boolean, boolean, boolean];
  readonly activeAbilities: ReadonlyArray<AbilityId>;
  readonly ownedConsumables: ReadonlyArray<ConsumableId>;
  readonly ownedUpgrades: ReadonlyArray<UpgradeId>;
  readonly spinCount: number;
  readonly isFreeSpin: boolean;
  readonly betMultiplier: 1 | 2 | 3;
}

export interface RunHistory {
  readonly runsPlayed: number;
  readonly bestLucidityRun: number;
  readonly wealthEndingReachedAt?: number;
  readonly exitEndingReachedAt?: number;
}

export interface MetaState {
  readonly schemaVersion: number;
  readonly lucidityWallet: number;
  readonly ownedPermanents: ReadonlyArray<UpgradeId>;
  readonly corruptionEverUsed: boolean;
  readonly endingsReached: ReadonlyArray<EndingType>;
  readonly history: RunHistory;
}

export interface SaveSlot {
  readonly schemaVersion: number;
  readonly id: string;
  readonly createdAt: number;
  readonly meta: MetaState;
}

export interface GlobalState {
  readonly schemaVersion: number;
  readonly act2Unlocked: boolean;
  readonly settings: AppSettings;
}

export interface AppSettings {
  readonly sfxVolume: number;    // 0..1
  readonly musicVolume: number;  // 0..1
  readonly haptics: boolean;
}
