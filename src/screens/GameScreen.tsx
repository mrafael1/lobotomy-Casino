import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  Pressable,
  StyleSheet,
  SafeAreaView,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Background } from '../components/Background';
import { SlotMachine } from '../components/SlotMachine';
import { NeuronBar } from '../components/NeuronBar';
import { useRunStore } from '../state/runState';
import { useMetaStore } from '../state/metaState';
import { checkEnding } from '../game/endings';
import { ECONOMY } from '../content/economy';
import { CONSUMABLES } from '../content/consumables';
import { ABILITIES } from '../content/abilities';

// Reel-targeting state for abilities and the reel-lock consumable.
type Selection =
  | { mode: 'none' }
  | { mode: 'lock' }
  | { mode: 'swap'; first: number | null }
  | { mode: 'move'; reel: number | null };

const NO_SELECTION: Selection = { mode: 'none' };

export function GameScreen() {
  const router = useRouter();

  const runPhase       = useRunStore(s => s.runPhase);
  const lastEnding     = useRunStore(s => s.lastEnding);
  const isSpinning     = useRunStore(s => s.isSpinning);
  const neurons        = useRunStore(s => s.neurons);
  const lucidityEarned = useRunStore(s => s.lucidityEarned);
  const freeSpins      = useRunStore(s => s.freeSpinsRemaining);
  const lastResult     = useRunStore(s => s.lastResult);
  const decaySkips     = useRunStore(s => s.decaySkips);
  const spin           = useRunStore(s => s.spin);
  const setSpinning    = useRunStore(s => s.setSpinning);
  const endRun         = useRunStore(s => s.endRun);
  const startNewRun    = useRunStore(s => s.startNewRun);
  const buyConsumable  = useRunStore(s => s.buyConsumable);
  const lockReel       = useRunStore(s => s.lockReel);
  const swapReels      = useRunStore(s => s.swapReels);
  const moveReel       = useRunStore(s => s.moveReel);
  const buyOverrideFreeSpin = useRunStore(s => s.buyOverrideFreeSpin);

  const lucidityWallet  = useMetaStore(s => s.lucidityWallet);
  const ownedPermanents = useMetaStore(s => s.ownedPermanents);
  const bankRun         = useMetaStore(s => s.bankRun);

  const [selection, setSelection] = useState<Selection>(NO_SELECTION);

  // Auto-start first run once meta has hydrated from MMKV.
  // Hydration is synchronous with MMKV, so ownedPermanents is ready on mount.
  useEffect(() => {
    if (runPhase === 'idle') {
      startNewRun(ownedPermanents);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const handleSpin = useCallback(() => {
    setSelection(NO_SELECTION);
    spin();
  }, [spin]);

  // Run-over transition AND banking both happen here, explicitly, after the
  // last reel animation settles. Single-fire — impossible to double-bank.
  const handleAllReelsDone = useCallback(() => {
    setSpinning(false);
    const runNow = useRunStore.getState();
    const ending = checkEnding(runNow, useMetaStore.getState());
    if (ending) {
      bankRun(runNow, ending);
      endRun(ending);
    }
  }, [setSpinning, bankRun, endRun]);

  const handleNewRun = useCallback(() => {
    setSelection(NO_SELECTION);
    startNewRun(ownedPermanents);
  }, [startNewRun, ownedPermanents]);

  // ── Reel targeting ──
  const handleReelPress = useCallback((i: number) => {
    setSelection(prev => {
      switch (prev.mode) {
        case 'lock':
          lockReel(i);
          return NO_SELECTION;
        case 'swap':
          if (prev.first === null) return { mode: 'swap', first: i };
          if (prev.first !== i) swapReels(prev.first, i);
          return NO_SELECTION;
        case 'move':
          return { mode: 'move', reel: i };
        default:
          return prev;
      }
    });
  }, [lockReel, swapReels]);

  const handleConsumable = useCallback((id: string) => {
    const outcome = buyConsumable(id);
    if (outcome === 'needsReelPick') setSelection({ mode: 'lock' });
  }, [buyConsumable]);

  const handleMoveDirection = useCallback((direction: -1 | 1) => {
    setSelection(prev => {
      if (prev.mode === 'move' && prev.reel !== null) {
        moveReel(prev.reel, direction);
      }
      return NO_SELECTION;
    });
  }, [moveReel]);

  // Free spins bypass the neuron minimum
  const canSpin =
    runPhase === 'running' &&
    !isSpinning &&
    (freeSpins > 0 || neurons >= ECONOMY.MIN_NEURONS_TO_SPIN);

  const abilitiesUsable = runPhase === 'running' && !isSpinning && lastResult !== null;

  const winLabel = lastResult
    ? lastResult.winType === 'jackpot'
      ? `JACKPOT  +${lastResult.lucidityEarned}`
      : lastResult.winType === 'triple'
        ? `TRIPLE  +${lastResult.lucidityEarned}`
        : lastResult.winType === 'pair'
          ? `PAIR  +${lastResult.lucidityEarned}`
          : null
    : null;

  const selectionHint =
    selection.mode === 'lock' ? 'TAP A REEL TO LOCK IT'
    : selection.mode === 'swap' && selection.first === null ? 'TAP FIRST REEL TO SWAP'
    : selection.mode === 'swap' ? 'TAP SECOND REEL'
    : selection.mode === 'move' && selection.reel === null ? 'TAP A REEL TO SHIFT'
    : null;

  const selectedReels =
    selection.mode === 'swap' && selection.first !== null ? [selection.first]
    : selection.mode === 'move' && selection.reel !== null ? [selection.reel]
    : [];

  const reelsTappable = selection.mode !== 'none';

  return (
    <Background>
      <SafeAreaView style={styles.safe}>

        {/* ── HUD ── */}
        <View style={styles.hud}>
          <View style={styles.hudItem}>
            <Text style={styles.hudLabel}>WALLET</Text>
            <Text style={styles.hudValue}>{lucidityWallet}</Text>
          </View>
          <View style={styles.hudCenter}>
            <Text style={styles.title}>LOBOTOMY</Text>
          </View>
          <View style={styles.hudItem}>
            <Text style={styles.hudLabel}>THIS RUN</Text>
            <Text style={styles.hudValue}>{lucidityEarned}</Text>
          </View>
        </View>

        {/* ── Slot machine ── */}
        <View style={styles.machineWrap}>
          <SlotMachine
            onAllReelsDone={handleAllReelsDone}
            onReelPress={reelsTappable ? handleReelPress : undefined}
            selectedReels={selectedReels}
          />
        </View>

        {/* ── Neuron health bar ── */}
        <NeuronBar />

        {/* ── Win label / selection hint ── */}
        <View style={styles.winRow}>
          {selectionHint ? (
            <Text style={styles.selectionHint}>{selectionHint}</Text>
          ) : winLabel ? (
            <Text style={[
              styles.winLabel,
              lastResult?.winType === 'jackpot' && styles.winJackpot,
            ]}>
              {winLabel}
            </Text>
          ) : <View style={styles.winPlaceholder} />}
        </View>

        {/* ── Status badges ── */}
        <View style={styles.badgeRow}>
          {freeSpins > 0 && (
            <Text style={styles.freeSpinBadge}>
              FREE SPIN{freeSpins > 1 ? ` ×${freeSpins}` : ''}
            </Text>
          )}
          {decaySkips > 0 && (
            <Text style={styles.stasisBadge}>STASIS ×{decaySkips}</Text>
          )}
        </View>

        {/* ── Move direction picker ── */}
        {selection.mode === 'move' && selection.reel !== null ? (
          <View style={styles.moveDirRow}>
            <Pressable style={styles.moveDirBtn} onPress={() => handleMoveDirection(-1)}>
              <Text style={styles.moveDirText}>▲ UP</Text>
            </Pressable>
            <Pressable style={styles.moveDirBtn} onPress={() => handleMoveDirection(1)}>
              <Text style={styles.moveDirText}>▼ DOWN</Text>
            </Pressable>
            <Pressable style={styles.cancelBtn} onPress={() => setSelection(NO_SELECTION)}>
              <Text style={styles.cancelText}>CANCEL</Text>
            </Pressable>
          </View>
        ) : selection.mode !== 'none' ? (
          <View style={styles.moveDirRow}>
            <Pressable style={styles.cancelBtn} onPress={() => setSelection(NO_SELECTION)}>
              <Text style={styles.cancelText}>CANCEL</Text>
            </Pressable>
          </View>
        ) : (
          <>
            {/* ── Abilities ── */}
            <View style={styles.itemRow}>
              <Pressable
                style={[styles.itemBtn, (!abilitiesUsable || lucidityEarned < ABILITIES.swap.cost) && styles.itemBtnDisabled]}
                disabled={!abilitiesUsable || lucidityEarned < ABILITIES.swap.cost}
                onPress={() => setSelection({ mode: 'swap', first: null })}
              >
                <Text style={styles.itemName}>SWAP</Text>
                <Text style={styles.itemCost}>{ABILITIES.swap.cost}</Text>
              </Pressable>
              <Pressable
                style={[styles.itemBtn, (!abilitiesUsable || lucidityEarned < ABILITIES.moveColumn.cost) && styles.itemBtnDisabled]}
                disabled={!abilitiesUsable || lucidityEarned < ABILITIES.moveColumn.cost}
                onPress={() => setSelection({ mode: 'move', reel: null })}
              >
                <Text style={styles.itemName}>SHIFT</Text>
                <Text style={styles.itemCost}>{ABILITIES.moveColumn.cost}</Text>
              </Pressable>
              <Pressable
                style={[styles.itemBtn, (!abilitiesUsable || lucidityEarned < ABILITIES.freeSpinAbility.cost) && styles.itemBtnDisabled]}
                disabled={!abilitiesUsable || lucidityEarned < ABILITIES.freeSpinAbility.cost}
                onPress={buyOverrideFreeSpin}
              >
                <Text style={styles.itemName}>OVERRIDE</Text>
                <Text style={styles.itemCost}>{ABILITIES.freeSpinAbility.cost}</Text>
              </Pressable>
            </View>

            {/* ── Consumables ── */}
            <View style={styles.itemRow}>
              {CONSUMABLES.map(c => {
                const disabled =
                  runPhase !== 'running' || isSpinning || lucidityEarned < c.cost;
                return (
                  <Pressable
                    key={c.id}
                    style={[styles.itemBtn, disabled && styles.itemBtnDisabled]}
                    disabled={disabled}
                    onPress={() => handleConsumable(c.id)}
                  >
                    <Text style={styles.itemName} numberOfLines={1}>
                      {c.name.split(' ')[0].toUpperCase()}
                    </Text>
                    <Text style={styles.itemCost}>{c.cost}</Text>
                  </Pressable>
                );
              })}
            </View>
          </>
        )}

        {/* ── Spin button ── */}
        <View style={styles.controls}>
          <Pressable
            style={[styles.spinBtn, !canSpin && styles.spinBtnDisabled]}
            onPress={handleSpin}
            disabled={!canSpin}
          >
            <Text style={styles.spinBtnText}>
              {freeSpins > 0 ? 'FREE SPIN' : 'SPIN'}
            </Text>
          </Pressable>
        </View>

      </SafeAreaView>

      {/* ── Run-over overlay ── */}
      {runPhase === 'over' && (
        <View style={styles.overlay}>
          {lastEnding === 'wealth' ? (
            <>
              <Text style={[styles.overlayTitle, styles.wealthTitle]}>WEALTH</Text>
              <Text style={styles.overlayBody}>
                You have everything.{'\n'}It isn't enough.
              </Text>
            </>
          ) : (
            <Text style={styles.overlayTitle}>FLATLINE</Text>
          )}
          <Text style={styles.overlayBody}>
            {lucidityEarned} Lucidity banked
          </Text>
          <Pressable style={styles.restartBtn} onPress={handleNewRun}>
            <Text style={styles.restartText}>START AGAIN</Text>
          </Pressable>
          <Pressable style={styles.shopBtn} onPress={() => router.push('/shop')}>
            <Text style={styles.shopText}>VISIT THE DEALER</Text>
          </Pressable>
        </View>
      )}
    </Background>
  );
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
  },

  // HUD
  hud: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: 8,
    paddingBottom: 4,
  },
  hudItem: {
    flex: 1,
    alignItems: 'center',
  },
  hudCenter: {
    flex: 2,
    alignItems: 'center',
  },
  hudLabel: {
    color: '#94a3b8',
    fontSize: 9,
    fontWeight: '700',
    letterSpacing: 2,
  },
  hudValue: {
    color: '#00e5ff',
    fontSize: 18,
    fontWeight: '800',
    letterSpacing: 1,
  },
  title: {
    color: '#ff2d78',
    fontSize: 20,
    fontWeight: '900',
    letterSpacing: 6,
  },

  // Machine
  machineWrap: {
    alignItems: 'center',
    flex: 1,
    justifyContent: 'center',
  },

  // Win label
  winRow: {
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
  winLabel: {
    color: '#fbbf24',
    fontSize: 16,
    fontWeight: '800',
    letterSpacing: 3,
  },
  winJackpot: {
    color: '#ff2d78',
    fontSize: 20,
  },
  winPlaceholder: {
    height: 28,
  },
  selectionHint: {
    color: '#00e5ff',
    fontSize: 13,
    fontWeight: '800',
    letterSpacing: 2,
  },

  // Status badges
  badgeRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 16,
    minHeight: 18,
  },
  freeSpinBadge: {
    color: '#00e5ff',
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 2,
  },
  stasisBadge: {
    color: '#a855f7',
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 2,
  },

  // Abilities + consumables
  itemRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 8,
    paddingHorizontal: 16,
    paddingTop: 6,
  },
  itemBtn: {
    flex: 1,
    backgroundColor: 'rgba(168,85,247,0.18)',
    borderColor: 'rgba(168,85,247,0.5)',
    borderWidth: 1,
    borderRadius: 6,
    paddingVertical: 6,
    alignItems: 'center',
  },
  itemBtnDisabled: {
    opacity: 0.35,
  },
  itemName: {
    color: '#e2e8f0',
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 1,
  },
  itemCost: {
    color: '#fbbf24',
    fontSize: 10,
    fontWeight: '700',
  },

  // Move direction picker
  moveDirRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 10,
    paddingTop: 6,
    minHeight: 64,
    alignItems: 'center',
  },
  moveDirBtn: {
    backgroundColor: 'rgba(0,229,255,0.15)',
    borderColor: '#00e5ff',
    borderWidth: 1,
    borderRadius: 6,
    paddingVertical: 10,
    paddingHorizontal: 22,
  },
  moveDirText: {
    color: '#00e5ff',
    fontSize: 13,
    fontWeight: '800',
  },
  cancelBtn: {
    paddingVertical: 10,
    paddingHorizontal: 18,
  },
  cancelText: {
    color: '#94a3b8',
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 2,
  },

  // Spin button
  controls: {
    paddingHorizontal: 24,
    paddingBottom: 16,
    paddingTop: 8,
  },
  spinBtn: {
    backgroundColor: '#ff2d78',
    borderRadius: 8,
    paddingVertical: 16,
    alignItems: 'center',
  },
  spinBtnDisabled: {
    backgroundColor: 'rgba(255,45,120,0.25)',
  },
  spinBtnText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '900',
    letterSpacing: 6,
  },

  // Game over overlay
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.88)',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 16,
  },
  overlayTitle: {
    color: '#ef4444',
    fontSize: 48,
    fontWeight: '900',
    letterSpacing: 8,
  },
  wealthTitle: {
    color: '#fbbf24',
  },
  overlayBody: {
    color: '#94a3b8',
    fontSize: 16,
    letterSpacing: 2,
    textAlign: 'center',
  },
  restartBtn: {
    marginTop: 24,
    backgroundColor: '#ff2d78',
    paddingVertical: 14,
    paddingHorizontal: 40,
    borderRadius: 8,
  },
  restartText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '900',
    letterSpacing: 4,
  },
  shopBtn: {
    paddingVertical: 12,
    paddingHorizontal: 32,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#a855f7',
  },
  shopText: {
    color: '#a855f7',
    fontSize: 13,
    fontWeight: '800',
    letterSpacing: 3,
  },
});
