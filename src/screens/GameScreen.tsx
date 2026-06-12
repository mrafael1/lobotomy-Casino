import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  Pressable,
  StyleSheet,
  SafeAreaView,
  Animated,
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
import { IN_RUN_ITEM_MAP } from '../content/inRunItems';

// Reel-targeting state for abilities and consumable interactions.
type Selection =
  | { mode: 'none' }
  | { mode: 'reroll' }
  | { mode: 'lock' }
  | { mode: 'move'; reel: number | null }
  | { mode: 'copy_source'; consumableId: string }       // charge NOT yet consumed
  | { mode: 'copy_target'; sourceReel: number; consumableId: string }; // charge NOT yet consumed

const NO_SELECTION: Selection = { mode: 'none' };

export function GameScreen() {
  const router = useRouter();

  const runPhase            = useRunStore(s => s.runPhase);
  const lastEnding          = useRunStore(s => s.lastEnding);
  const isSpinning          = useRunStore(s => s.isSpinning);
  const neurons             = useRunStore(s => s.neurons);
  const lucidityEarned      = useRunStore(s => s.lucidityEarned);
  const freeSpins           = useRunStore(s => s.freeSpinsRemaining);
  const lastResult          = useRunStore(s => s.lastResult);
  const decaySkips          = useRunStore(s => s.decaySkips);
  const betMultiplier       = useRunStore(s => s.betMultiplier);
  const runConsumables      = useRunStore(s => s.runConsumables);
  const abilitiesUsed       = useRunStore(s => s.abilitiesUsed);
  const blockPowersSpins    = useRunStore(s => s.blockPowersSpins);
  const brainBoostSpins     = useRunStore(s => s.brainBoostSpins);
  const forcedRandomBetSpins = useRunStore(s => s.forcedRandomBetSpins);
  const guaranteedWinSpins  = useRunStore(s => s.guaranteedWinSpins);
  const dealerIncoming      = useRunStore(s => s.dealerIncoming);
  const dealerPending       = useRunStore(s => s.dealerPending);
  const dealerOfferIds      = useRunStore(s => s.dealerOfferIds);
  const pendingGiftId       = useRunStore(s => s.pendingGiftConsumableId);

  const spin               = useRunStore(s => s.spin);
  const setSpinning        = useRunStore(s => s.setSpinning);
  const setBetMultiplier   = useRunStore(s => s.setBetMultiplier);
  const endRun             = useRunStore(s => s.endRun);
  const startNewRun        = useRunStore(s => s.startNewRun);
  const useConsumable      = useRunStore(s => s.useConsumable);
  const lockReel           = useRunStore(s => s.lockReel);
  const rerollReel         = useRunStore(s => s.rerollReel);
  const moveReel           = useRunStore(s => s.moveReel);
  const copyReel           = useRunStore(s => s.copyReel);
  const checkDealerTrigger = useRunStore(s => s.checkDealerTrigger);
  const revealDealer       = useRunStore(s => s.revealDealer);
  const acceptDealerOffer  = useRunStore(s => s.acceptDealerOffer);
  const declineDealerOffer = useRunStore(s => s.declineDealerOffer);
  const discardConsumableForGift = useRunStore(s => s.discardConsumableForGift);
  const dismissGift        = useRunStore(s => s.dismissGift);

  const lucidityWallet         = useMetaStore(s => s.lucidityWallet);
  const ownedPermanents        = useMetaStore(s => s.ownedPermanents);
  const bankRun                = useMetaStore(s => s.bankRun);
  const getPendingConsumables  = useMetaStore(s => s.getPendingConsumables);

  const [selection, setSelection] = useState<Selection>(NO_SELECTION);
  const [rerollingReelIndex, setRerollingReelIndex] = useState<number | null>(null);

  const tapAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (!dealerIncoming) return;
    tapAnim.setValue(0);
    Animated.sequence([
      Animated.timing(tapAnim, { toValue:  7, duration: 70,  useNativeDriver: true }),
      Animated.timing(tapAnim, { toValue:  0, duration: 70,  useNativeDriver: true }),
      Animated.timing(tapAnim, { toValue:  7, duration: 70,  useNativeDriver: true }),
      Animated.timing(tapAnim, { toValue:  0, duration: 70,  useNativeDriver: true }),
      Animated.timing(tapAnim, { toValue:  7, duration: 70,  useNativeDriver: true }),
      Animated.timing(tapAnim, { toValue:  0, duration: 200, useNativeDriver: true }),
    ]).start(() => revealDealer());
  }, [dealerIncoming]);

  useEffect(() => {
    if (runPhase === 'idle') {
      startNewRun(ownedPermanents, getPendingConsumables());
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const handleSpin = useCallback(() => {
    setSelection(NO_SELECTION);
    spin();
  }, [spin]);

  const handleAllReelsDone = useCallback(() => {
    setSpinning(false);
    const runNow = useRunStore.getState();
    // End check runs first — if the run is over the Dealer should not appear.
    const ending = checkEnding(runNow, useMetaStore.getState());
    if (ending) {
      bankRun(runNow, ending);
      endRun(ending);
    } else {
      checkDealerTrigger();
    }
  }, [setSpinning, bankRun, endRun, checkDealerTrigger]);

  const handleNewRun = useCallback(() => {
    setSelection(NO_SELECTION);
    startNewRun(ownedPermanents, getPendingConsumables());
  }, [startNewRun, ownedPermanents, getPendingConsumables]);

  // ── Reel targeting ──
  const handleReelPress = useCallback((i: number) => {
    if (selection.mode === 'reroll') {
      if (rerollReel(i)) {
        setRerollingReelIndex(i);
      }
      setSelection(NO_SELECTION);
    } else if (selection.mode === 'lock') {
      lockReel(i);
      setSelection(NO_SELECTION);
    } else if (selection.mode === 'move') {
      setSelection({ mode: 'move', reel: i });
    } else if (selection.mode === 'copy_source') {
      setSelection({ mode: 'copy_target', sourceReel: i, consumableId: selection.consumableId });
    } else if (selection.mode === 'copy_target') {
      if (i !== selection.sourceReel) {
        if (useConsumable(selection.consumableId)) {
          copyReel(selection.sourceReel, i);
        }
        setSelection(NO_SELECTION);
      }
    }
  }, [selection, lockReel, rerollReel, copyReel, useConsumable]);

  const handleConsumable = useCallback((id: string) => {
    const consumable = CONSUMABLES.find(c => c.id === id);
    if (!consumable) return;

    if (consumable.effect.type === 'copyReel') {
      // White Powder: enter selection without consuming the charge yet.
      // The charge is consumed only when source + target are both confirmed.
      setSelection({ mode: 'copy_source', consumableId: id });
    } else {
      useConsumable(id);
    }
  }, [useConsumable]);

  const handleMoveDirection = useCallback((direction: -1 | 1) => {
    setSelection(prev => {
      if (prev.mode === 'move' && prev.reel !== null) {
        moveReel(prev.reel, direction);
      }
      return NO_SELECTION;
    });
  }, [moveReel]);

  const runBusy =
    isSpinning ||
    rerollingReelIndex !== null ||
    dealerIncoming ||
    dealerPending ||
    pendingGiftId !== null;

  const canSpin = runPhase === 'running' && !runBusy && (freeSpins > 0 || neurons >= 1);

  const spinNeuronCost = freeSpins > 0 ? 0 : Math.min(betMultiplier * ECONOMY.NEURON_DECAY_PER_SPIN, neurons);
  const _base = ECONOMY.NEURON_DECAY_PER_SPIN;
  const spinLabel =
    freeSpins > 0
      ? 'FREE SPIN'
      : forcedRandomBetSpins > 0
      ? `SPIN  ${_base}–${_base * 3}N`
      : decaySkips > 0
      ? 'SPIN  0N'
      : `SPIN  -${spinNeuronCost}N`;

  // Abilities blocked while game is busy, powers blocked (Pill), or no result yet
  const powersBlocked = blockPowersSpins > 0;
  const abilitiesUsable = runPhase === 'running' && !runBusy && lastResult !== null && !powersBlocked;

  const hasShift  = ownedPermanents.includes('perm_shift');
  const hasMemory = ownedPermanents.includes('perm_memory');

  // Consumables with at least 1 charge this run
  const activeConsumables = CONSUMABLES.filter(c => (runConsumables[c.id] ?? 0) > 0);

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
    selection.mode === 'reroll'      ? 'TAP A REEL TO REROLL'
    : selection.mode === 'lock'      ? 'TAP A REEL TO LOCK IT'
    : selection.mode === 'move' && selection.reel === null ? 'TAP A REEL TO SHIFT'
    : selection.mode === 'copy_source' ? 'TAP THE REEL TO COPY FROM'
    : selection.mode === 'copy_target' ? 'TAP THE REEL TO COPY ONTO'
    : null;

  const selectedReels =
    selection.mode === 'move' && selection.reel !== null ? [selection.reel]
    : selection.mode === 'copy_target' ? [selection.sourceReel]
    : [];

  const reelsTappable = selection.mode !== 'none' && !runBusy;

  const dealerItems = dealerOfferIds
    ? dealerOfferIds.map(id => IN_RUN_ITEM_MAP[id]).filter(Boolean)
    : [];

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

        {/* ── Neuron health bar ── */}
        <NeuronBar />

        {/* ── Slot machine ── */}
        <Animated.View style={[styles.machineWrap, { transform: [{ translateX: tapAnim }] }]}>
          <SlotMachine
            onAllReelsDone={handleAllReelsDone}
            onReelPress={reelsTappable ? handleReelPress : undefined}
            selectedReels={selectedReels}
            shiftTargetReel={selection.mode === 'move' ? selection.reel : null}
            onShiftDirection={handleMoveDirection}
            rerollingReelIndex={rerollingReelIndex}
            onRerollDone={() => setRerollingReelIndex(null)}
          />
        </Animated.View>

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
            <Text style={styles.stasisBadge}>NO DECAY ×{decaySkips}</Text>
          )}
          {brainBoostSpins > 0 && (
            <Text style={styles.boostBadge}>BRAIN BOOST ×{brainBoostSpins}</Text>
          )}
          {forcedRandomBetSpins > 0 && (
            <Text style={styles.energyBadge}>RANDOM BET ×{forcedRandomBetSpins}</Text>
          )}
          {guaranteedWinSpins > 0 && (
            <Text style={styles.pillBadge}>WIN GUARANTEED</Text>
          )}
          {powersBlocked && (
            <Text style={styles.blockBadge}>POWERS BLOCKED ×{blockPowersSpins}</Text>
          )}
        </View>

        {/* ── Cancel / ability+consumable area ── */}
        {selection.mode !== 'none' ? (
          <View style={styles.cancelRow}>
            <Pressable style={styles.cancelBtn} onPress={() => setSelection(NO_SELECTION)}>
              <Text style={styles.cancelText}>CANCEL</Text>
            </Pressable>
          </View>
        ) : (
          <>
            {/* ── Abilities ── */}
            <View style={styles.itemRow}>
              <Pressable
                style={[
                  styles.itemBtn,
                  (!abilitiesUsable || abilitiesUsed.includes('reroll')) && styles.itemBtnDisabled,
                ]}
                disabled={!abilitiesUsable || abilitiesUsed.includes('reroll')}
                onPress={() => setSelection({ mode: 'reroll' })}
              >
                <Text style={styles.itemName}>REROLL</Text>
                <Text style={styles.itemTag}>1/RUN</Text>
              </Pressable>

              {hasShift && (
                <Pressable
                  style={[
                    styles.itemBtn,
                    (!abilitiesUsable || abilitiesUsed.includes('shift')) && styles.itemBtnDisabled,
                  ]}
                  disabled={!abilitiesUsable || abilitiesUsed.includes('shift')}
                  onPress={() => setSelection({ mode: 'move', reel: null })}
                >
                  <Text style={styles.itemName}>SHIFT</Text>
                  <Text style={styles.itemTag}>1/RUN</Text>
                </Pressable>
              )}

              {hasMemory && (
                <Pressable
                  style={[
                    styles.itemBtn,
                    (!abilitiesUsable || abilitiesUsed.includes('memory')) && styles.itemBtnDisabled,
                  ]}
                  disabled={!abilitiesUsable || abilitiesUsed.includes('memory')}
                  onPress={() => setSelection({ mode: 'lock' })}
                >
                  <Text style={styles.itemName}>MEMORY</Text>
                  <Text style={styles.itemTag}>1/RUN</Text>
                </Pressable>
              )}
            </View>

            {/* ── Consumables ── */}
            {activeConsumables.length > 0 && (
              <View style={styles.itemRow}>
                {activeConsumables.map(c => {
                  const charges = runConsumables[c.id] ?? 0;
                  const disabled = runPhase !== 'running' || runBusy;
                  return (
                    <Pressable
                      key={c.id}
                      style={[styles.itemBtn, styles.itemBtnConsumable, disabled && styles.itemBtnDisabled]}
                      disabled={disabled}
                      onPress={() => handleConsumable(c.id)}
                    >
                      <Text style={styles.itemName} numberOfLines={1}>
                        {c.name.split(' ')[0].toUpperCase()}
                      </Text>
                      <Text style={styles.itemTag}>×{charges}</Text>
                    </Pressable>
                  );
                })}
              </View>
            )}
          </>
        )}

        {/* ── Bet multiplier selector ── */}
        <View style={styles.betRow}>
          {([1, 2, 3] as const).map(m => {
            const betLocked = forcedRandomBetSpins > 0 || neurons < m * ECONOMY.NEURON_DECAY_PER_SPIN;
            const betDisabled = runPhase !== 'running' || runBusy || betLocked;
            return (
              <Pressable
                key={m}
                style={[styles.betBtn, betMultiplier === m && styles.betBtnActive, betLocked && styles.betBtnLocked]}
                onPress={() => setBetMultiplier(m)}
                disabled={betDisabled}
              >
                <Text style={[styles.betBtnText, betMultiplier === m && styles.betBtnTextActive, betLocked && styles.betBtnLockedText]}>
                  {betLocked ? '🔒' : `×${m}`}
                </Text>
                <Text style={[styles.betCostText, betMultiplier === m && styles.betBtnTextActive, betLocked && styles.betBtnLockedText]}>
                  -{m * ECONOMY.NEURON_DECAY_PER_SPIN}N
                </Text>
              </Pressable>
            );
          })}
        </View>

        {/* ── Spin button ── */}
        <View style={styles.controls}>
          <Pressable
            style={[styles.spinBtn, !canSpin && styles.spinBtnDisabled]}
            onPress={handleSpin}
            disabled={!canSpin}
          >
            <Text style={styles.spinBtnText}>
              {spinLabel}
            </Text>
          </Pressable>
        </View>

      </SafeAreaView>

      {/* ── Dealer modal ── */}
      {dealerPending && dealerItems.length > 0 && (
        <View style={styles.overlay}>
          <Text style={styles.dealerTitle}>THE DEALER</Text>
          <Text style={styles.dealerSubtitle}>He lays two things on the table.</Text>
          <View style={styles.dealerOffers}>
            {dealerItems.map(item => item && (
              <View key={item.id} style={styles.dealerCard}>
                <Text style={styles.dealerItemName}>{item.name}</Text>
                <Text style={styles.dealerItemDesc}>{item.description}</Text>
                <Pressable
                  style={styles.dealerAcceptBtn}
                  onPress={() => acceptDealerOffer(item.id)}
                >
                  <Text style={styles.dealerAcceptText}>TAKE IT</Text>
                </Pressable>
              </View>
            ))}
          </View>
          <Pressable style={styles.dealerDeclineBtn} onPress={declineDealerOffer}>
            <Text style={styles.dealerDeclineText}>REFUSE BOTH</Text>
          </Pressable>
        </View>
      )}

      {/* ── Gift overlay (stash received, or stash full + discard) ── */}
      {pendingGiftId && (
        <View style={styles.overlay}>
          {(runConsumables[pendingGiftId] ?? 0) > 0 ? (
            <>
              <Text style={styles.dealerTitle}>STASHED</Text>
              <Text style={styles.dealerSubtitle}>
                He slips you{'\n'}
                <Text style={styles.dealerItemName}>
                  {CONSUMABLES.find(c => c.id === pendingGiftId)?.name ?? 'something'}
                </Text>
                .{'\n'}Tucked away in your coat.
              </Text>
              <Pressable style={styles.dealerAcceptBtn} onPress={dismissGift}>
                <Text style={styles.dealerAcceptText}>GOT IT</Text>
              </Pressable>
            </>
          ) : (
            <>
              <Text style={styles.dealerTitle}>STASH FULL</Text>
              <Text style={styles.dealerSubtitle}>
                He hands you {CONSUMABLES.find(c => c.id === pendingGiftId)?.name ?? 'something'}.
                {'\n'}Discard something to make room.
              </Text>
              <View style={styles.dealerOffers}>
                {activeConsumables.map(c => (
                  <View key={c.id} style={styles.dealerCard}>
                    <Text style={styles.dealerItemName}>{c.name}</Text>
                    <Text style={styles.dealerItemDesc}>×{runConsumables[c.id] ?? 0} charge{(runConsumables[c.id] ?? 0) > 1 ? 's' : ''}</Text>
                    <Pressable
                      style={styles.dealerAcceptBtn}
                      onPress={() => discardConsumableForGift(c.id)}
                    >
                      <Text style={styles.dealerAcceptText}>DISCARD</Text>
                    </Pressable>
                  </View>
                ))}
              </View>
              <Pressable style={styles.dealerDeclineBtn} onPress={dismissGift}>
                <Text style={styles.dealerDeclineText}>TOSS THE GIFT</Text>
              </Pressable>
            </>
          )}
        </View>
      )}

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
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 8,
    minHeight: 18,
    paddingHorizontal: 8,
  },
  freeSpinBadge: {
    color: '#00e5ff',
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 2,
  },
  stasisBadge: {
    color: '#a855f7',
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 2,
  },
  boostBadge: {
    color: '#f97316',
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 2,
  },
  energyBadge: {
    color: '#22c55e',
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 2,
  },
  pillBadge: {
    color: '#fbbf24',
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 2,
  },
  blockBadge: {
    color: '#ef4444',
    fontSize: 11,
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
  itemBtnConsumable: {
    backgroundColor: 'rgba(0,229,255,0.12)',
    borderColor: 'rgba(0,229,255,0.4)',
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
  itemTag: {
    color: '#a855f7',
    fontSize: 9,
    fontWeight: '700',
  },

  // Cancel row shown during any active selection
  cancelRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    minHeight: 40,
    alignItems: 'center',
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

  // Bet multiplier
  betRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 8,
    paddingHorizontal: 24,
    paddingTop: 6,
    paddingBottom: 4,
  },
  betBtn: {
    flex: 1,
    borderWidth: 1,
    borderColor: 'rgba(255,45,120,0.35)',
    borderRadius: 6,
    paddingVertical: 5,
    alignItems: 'center',
    backgroundColor: 'rgba(255,45,120,0.07)',
  },
  betBtnActive: {
    backgroundColor: 'rgba(255,45,120,0.28)',
    borderColor: '#ff2d78',
  },
  betBtnText: {
    color: 'rgba(255,45,120,0.55)',
    fontSize: 13,
    fontWeight: '900',
    letterSpacing: 1,
  },
  betBtnTextActive: {
    color: '#ff2d78',
  },
  betBtnLocked: {
    opacity: 0.4,
    borderColor: 'rgba(255,255,255,0.15)',
  },
  betBtnLockedText: {
    color: 'rgba(255,255,255,0.35)',
  },
  betCostText: {
    color: 'rgba(255,45,120,0.4)',
    fontSize: 9,
    fontWeight: '700',
    letterSpacing: 1,
  },

  // Spin button
  controls: {
    paddingHorizontal: 24,
    paddingBottom: 16,
    paddingTop: 4,
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

  // Dealer modal + Game over overlay (both use same base overlay)
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.92)',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 16,
    paddingHorizontal: 32,
  },

  // Dealer
  dealerTitle: {
    color: '#a855f7',
    fontSize: 28,
    fontWeight: '900',
    letterSpacing: 6,
  },
  dealerSubtitle: {
    color: '#64748b',
    fontSize: 13,
    fontStyle: 'italic',
    textAlign: 'center',
  },
  dealerOffers: {
    flexDirection: 'row',
    gap: 12,
    width: '100%',
  },
  dealerCard: {
    flex: 1,
    backgroundColor: 'rgba(168,85,247,0.12)',
    borderColor: 'rgba(168,85,247,0.45)',
    borderWidth: 1,
    borderRadius: 12,
    padding: 14,
    gap: 8,
    alignItems: 'center',
  },
  dealerItemName: {
    color: '#e2e8f0',
    fontSize: 15,
    fontWeight: '900',
    letterSpacing: 1,
    textAlign: 'center',
  },
  dealerItemDesc: {
    color: '#94a3b8',
    fontSize: 11,
    textAlign: 'center',
    lineHeight: 16,
    flex: 1,
  },
  dealerAcceptBtn: {
    backgroundColor: '#a855f7',
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 8,
    width: '100%',
    alignItems: 'center',
  },
  dealerAcceptText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '900',
    letterSpacing: 2,
  },
  dealerDeclineBtn: {
    paddingVertical: 12,
    paddingHorizontal: 24,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#475569',
  },
  dealerDeclineText: {
    color: '#64748b',
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 2,
  },

  // Game over
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
