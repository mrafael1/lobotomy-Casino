import type { SymbolId } from '../content/symbols';
import type { AbilityId } from '../content/abilities';

export type { SymbolId, AbilityId };

export type UpgradeId = string;
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
  readonly bookWeight: number;          // 0 = no book; >0 = Learning owned, book active
  readonly brainWeightBonus: number;    // extra weight for brain (upgrades + Syringe boost)
  readonly guaranteedWin: boolean;      // Pill (legacy): force at least a pair this spin
  readonly pattern23Triple: boolean;    // Pattern Fabrication: 2/3 match -> doubled pair payout
  readonly learningActive: boolean;     // Learning: book pays out and +10/book visible
  // Consumable reel transforms (issue #32). All optional and no-op at their defaults,
  // so every pinned vector (which omits them) scores exactly as before.
  readonly forceAllSymbol?: SymbolId | null;              // Pill: force every reel to this symbol
  readonly forceTripleFrom?: ReadonlyArray<SymbolId> | null; // Pill: force a triple from these
  readonly excludeSymbol?: SymbolId | null;               // Serum: the banned / guaranteed-absent symbol
  readonly banExcluded?: boolean;                         // Serum: replace excludeSymbol reels
  readonly guaranteeNonExcluded?: boolean;                // Serum: ensure >=1 non-excluded reel
  readonly symbolToBrainCount?: number;                   // Potion: convert first N reels to brain
  readonly pairScoreMult?: number;                        // Tobacco: multiply pair payout
  readonly hiddenReelCount?: number;                      // Tobacco: score only the visible remainder
}

export interface SpinResult {
  readonly reels: ReelResult;
  // Effective score multiplier this spin was scored at (lucidity × next-spin
  // boost × bet, with brain-boost halving applied). Powers re-score modified
  // reels at this same multiplier so a power-formed win pays like a natural one.
  readonly scoreMultiplier: number;
  readonly scoreEarned: number;         // in-run score (multiplied) — drives the wealth ending
  readonly coinsEarned: number;         // flat lucidity coins banked to the wallet
  readonly neuronsAfter: number;
  readonly freeSpinsGranted: number;    // always 0 if isFreeSpin === true
  readonly freeSpinsAfter: number;
  readonly isJackpot: boolean;
  readonly isFreeSpin: boolean;
  readonly winType: WinType;
  // Visual-only: true when the Cocktail rarity bonus (sum of every visible
  // symbol's rarityScore) was folded into scoreEarned this spin. Lets the UI show
  // each reel's own score on a loss; never affects payout.
  readonly cocktailApplied?: boolean;
}

export interface RunState {
  readonly neurons: number;
  readonly startingNeurons: number;
  readonly scoreEarned: number;         // accumulated in-run score (for wealth ending)
  readonly lucidityCoins: number;       // accumulated flat coins this run (banks to wallet)
  readonly freeSpinsRemaining: number;
  readonly maxFreeSpins: number;
  readonly lucidityMultiplier: number;
  readonly nextSpinLucidityMultiplier: number; // from consumable, resets after spin
  readonly isSpinning: boolean;
  readonly lastResult: SpinResult | null;
  readonly lockedReels: [boolean, boolean, boolean];
  readonly lockedReelSpins: [number, number, number]; // Memory: per-reel spins left before each lock expires (0 = unlocked)
  readonly runConsumables: Partial<Record<string, number>>;
  readonly abilitiesUsed: ReadonlyArray<AbilityId>;
  readonly ownedUpgrades: ReadonlyArray<UpgradeId>;
  readonly spinCount: number;
  readonly isFreeSpin: boolean;
  readonly betMultiplier: 1 | 2 | 3;
  // Dealer state
  readonly dealerCount: number;
  readonly dealerLastSpinCount: number;
  readonly dealer65SafetyFired: boolean;
  readonly dealer35SafetyFired: boolean;
  readonly dealerIncoming: boolean;
  readonly dealerPending: boolean;
  readonly dealerOfferIds: [string, string] | null;
  // Active effects from consumables / dealer items
  readonly brainBoostSpins: number;
  readonly forcedRandomBetSpins: number;
  readonly guaranteedWinSpins: number;
  readonly blockPowersSpins: number;
  readonly hideNeuronsSpins: number;
  readonly cocktailBoostSpins: number;
  readonly compulsiveSpinSkips: number;
  readonly pendingCompulsiveSpinSkips: number;
  readonly decaySkips: number;
  // Consumable roster effects (issue #32).
  readonly pairBoostSpins: number;          // Tobacco: hidden reel + pair multiplier active
  readonly pairBoostMult: number;           // Tobacco: pair payout multiplier while active
  readonly pairBoostHiddenReels: number;    // Tobacco: reels hidden from scoring while active
  readonly guaranteeSymbolSpins: number;    // Serum: force a non-excluded symbol to appear
  readonly banBrainSpins: number;           // Serum: brain banned from the reels
  readonly potionSpins: number;             // Potion: one random pool effect per spin
  readonly forceFlatlineSpins: number;      // Pill: force an all-flatline spin
  readonly guaranteedTripleSpins: number;   // Pill: force a triple the spin after the flatline
  readonly hideResultSpins: number;         // White Powder: hide the next spin's result
}

export interface RunHistory {
  readonly runsPlayed: number;
  readonly bestScoreRun: number;       // highest single-run score achieved
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
  readonly pendingConsumables: Partial<Record<string, number>>;
  readonly is_first_launch: boolean;
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
