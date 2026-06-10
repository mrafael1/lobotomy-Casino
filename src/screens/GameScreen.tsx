import React, { useCallback, useEffect } from 'react';
import {
  View,
  Text,
  Pressable,
  StyleSheet,
  SafeAreaView,
} from 'react-native';
import { Background } from '../components/Background';
import { SlotMachine } from '../components/SlotMachine';
import { NeuronBar } from '../components/NeuronBar';
import { useRunStore } from '../state/runState';
import { useMetaStore } from '../state/metaState';
import { ECONOMY } from '../content/economy';

export function GameScreen() {
  const runPhase      = useRunStore(s => s.runPhase);
  const isSpinning    = useRunStore(s => s.isSpinning);
  const neurons       = useRunStore(s => s.neurons);
  const lucidityEarned = useRunStore(s => s.lucidityEarned);
  const freeSpins     = useRunStore(s => s.freeSpinsRemaining);
  const lastResult    = useRunStore(s => s.lastResult);
  const spin          = useRunStore(s => s.spin);
  const setSpinning   = useRunStore(s => s.setSpinning);
  const endRun        = useRunStore(s => s.endRun);
  const startNewRun   = useRunStore(s => s.startNewRun);

  const lucidityWallet = useMetaStore(s => s.lucidityWallet);
  const ownedPermanents = useMetaStore(s => s.ownedPermanents);
  const bankRun        = useMetaStore(s => s.bankRun);

  // Auto-start first run once meta has hydrated from MMKV.
  // Hydration is synchronous with MMKV, so ownedPermanents is ready on mount.
  useEffect(() => {
    if (runPhase === 'idle') {
      startNewRun(ownedPermanents);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const handleSpin = useCallback(() => {
    spin();
  }, [spin]);

  // Fix 2 + 3: run-over transition AND banking both happen here, explicitly,
  // after the last reel animation settles. Single-fire — impossible to double-bank.
  const handleAllReelsDone = useCallback(() => {
    setSpinning(false);
    const { neurons: n } = useRunStore.getState();
    if (n <= 0) {
      bankRun(useRunStore.getState(), 'flatline');
      endRun();
    }
  }, [setSpinning, bankRun, endRun]);

  const handleNewRun = useCallback(() => {
    startNewRun(ownedPermanents);
  }, [startNewRun, ownedPermanents]);

  // Fix 1: free spins bypass the neuron minimum
  const canSpin =
    runPhase === 'running' &&
    !isSpinning &&
    (freeSpins > 0 || neurons >= ECONOMY.MIN_NEURONS_TO_SPIN);

  const winLabel = lastResult
    ? lastResult.winType === 'jackpot'
      ? `JACKPOT  +${lastResult.lucidityEarned}`
      : lastResult.winType === 'triple'
        ? `TRIPLE  +${lastResult.lucidityEarned}`
        : lastResult.winType === 'pair'
          ? `PAIR  +${lastResult.lucidityEarned}`
          : null
    : null;

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
          <SlotMachine onAllReelsDone={handleAllReelsDone} />
        </View>

        {/* ── Neuron health bar ── */}
        <NeuronBar />

        {/* ── Win label ── */}
        <View style={styles.winRow}>
          {winLabel ? (
            <Text style={[
              styles.winLabel,
              lastResult?.winType === 'jackpot' && styles.winJackpot,
            ]}>
              {winLabel}
            </Text>
          ) : <View style={styles.winPlaceholder} />}
        </View>

        {/* ── Free spin indicator ── */}
        {freeSpins > 0 && (
          <Text style={styles.freeSpinBadge}>
            FREE SPIN{freeSpins > 1 ? ` ×${freeSpins}` : ''}
          </Text>
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
          <Text style={styles.overlayTitle}>FLATLINE</Text>
          <Text style={styles.overlayBody}>
            {lucidityEarned} Lucidity banked
          </Text>
          <Pressable style={styles.restartBtn} onPress={handleNewRun}>
            <Text style={styles.restartText}>START AGAIN</Text>
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

  // Free spin
  freeSpinBadge: {
    textAlign: 'center',
    color: '#00e5ff',
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 2,
    marginBottom: 4,
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
  overlayBody: {
    color: '#94a3b8',
    fontSize: 16,
    letterSpacing: 2,
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
});
