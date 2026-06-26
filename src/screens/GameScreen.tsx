import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  View,
  Image,
  Pressable,
  StyleSheet,
  Animated,
} from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Text } from '../components/PixelText';
import { PIXEL_FONT } from '../content/typography';
import { Background } from '../components/Background';
import { SlotMachine } from '../components/SlotMachine';
import { PixelScene } from '../components/PixelScene';
import { Stash } from '../components/Stash';
import { FlatlineKeptCountdown } from '../components/FlatlineKeptCountdown';
import {
  vpx, ASSET_SCALE, VIRTUAL_WIDTH, HUD_HEIGHT,
  MACHINE_X, MACHINE_Y, MACHINE_W, MACHINE_H,
} from '../content/layout';
import { DEALER_SHOP_PORTRAIT } from '../content/uiAssets';
import { useRunStore } from '../state/runState';
import { useMetaStore } from '../state/metaState';
import { checkEnding } from '../game/endings';
import { hasSedative } from '../game/economy';
import { ECONOMY } from '../content/economy';
import { CONSUMABLES, buildStashSlots } from '../content/consumables';
import { IN_RUN_ITEMS } from '../content/inRunItems';

// Reel-targeting state for abilities and consumable interactions.
type Selection =
  | { mode: 'none' }
  | { mode: 'reroll' }
  | { mode: 'lock' }
  | { mode: 'move' }
  | { mode: 'copy_source'; consumableId: string }       // charge NOT yet consumed
  | { mode: 'copy_target'; sourceReel: number; consumableId: string }; // charge NOT yet consumed

const NO_SELECTION: Selection = { mode: 'none' };

// After the final spin drops spins/neurons to a run-ending state, hold on the
// resolved reels + payout for this long before showing the run-over (Flatline /
// Wealth) overlay, so the player actually sees the last result.
const FLATLINE_REVEAL_DELAY_MS = 1000;

// Machine dealer-arrival portrait. The dealer-scene sheet (dealer_portrait.png,
// 2560×2560 = two 1280×2560 frames) draws the figure small inside a full scene
// canvas, so we CROP to the figure's measured alpha bounds within frame 2
// (index 1) and scale that crop up — readable, same dealer as the scene, no
// stretch (uniform scale). Crop measured from the PNG alpha box.
const DEALER_SHEET_SIZE   = 2560;
const DEALER_FRAME_W      = 1280;
const DEALER_FRAME_INDEX  = 1; // "frame 2"
const DEALER_CROP         = { x: 392, y: 1048, w: 464, h: 640 } as const;
const DEALER_PORTRAIT_H   = 176;
const DEALER_PORTRAIT_W   = Math.round(DEALER_PORTRAIT_H * DEALER_CROP.w / DEALER_CROP.h);
const DEALER_PORTRAIT_SCALE = DEALER_PORTRAIT_W / DEALER_CROP.w;
const DEALER_PORTRAIT_SRC_X = DEALER_FRAME_INDEX * DEALER_FRAME_W + DEALER_CROP.x;

export function GameScreen() {
  const router = useRouter();

  const runPhase            = useRunStore(s => s.runPhase);
  const lastEnding          = useRunStore(s => s.lastEnding);
  const isSpinning          = useRunStore(s => s.isSpinning);
  const neurons             = useRunStore(s => s.neurons);
  const lucidityCoins        = useRunStore(s => s.lucidityCoins);
  const freeSpins           = useRunStore(s => s.freeSpinsRemaining);
  const lastResult          = useRunStore(s => s.lastResult);
  const decaySkips          = useRunStore(s => s.decaySkips);
  const runConsumables      = useRunStore(s => s.runConsumables);
  const abilitiesUsed       = useRunStore(s => s.abilitiesUsed);
  const blockPowersSpins    = useRunStore(s => s.blockPowersSpins);
  const brainBoostSpins     = useRunStore(s => s.brainBoostSpins);
  const forcedRandomBetSpins = useRunStore(s => s.forcedRandomBetSpins);
  const guaranteedWinSpins  = useRunStore(s => s.guaranteedWinSpins);
  const cocktailBoostSpins  = useRunStore(s => s.cocktailBoostSpins);
  const compulsiveSpinSkips = useRunStore(s => s.compulsiveSpinSkips);
  const dealerIncoming      = useRunStore(s => s.dealerIncoming);
  const dealerPending       = useRunStore(s => s.dealerPending);
  const spinCount           = useRunStore(s => s.spinCount);
  const ownedUpgrades       = useRunStore(s => s.ownedUpgrades);

  const spin               = useRunStore(s => s.spin);
  const setSpinning        = useRunStore(s => s.setSpinning);
  const setBetMultiplier   = useRunStore(s => s.setBetMultiplier);
  const endRun             = useRunStore(s => s.endRun);
  const continueRun        = useRunStore(s => s.continueRun);
  const startNewRun        = useRunStore(s => s.startNewRun);
  const useConsumable      = useRunStore(s => s.useConsumable);
  const lockReel           = useRunStore(s => s.lockReel);
  const rerollReel         = useRunStore(s => s.rerollReel);
  const moveReel           = useRunStore(s => s.moveReel);
  const copyReel           = useRunStore(s => s.copyReel);
  const checkDealerTrigger = useRunStore(s => s.checkDealerTrigger);
  const revealDealer       = useRunStore(s => s.revealDealer);
  const declineDealerVisit = useRunStore(s => s.declineDealerVisit);

  const ownedPermanents        = useMetaStore(s => s.ownedPermanents);
  const bankRun                = useMetaStore(s => s.bankRun);
  const markEndingReached      = useMetaStore(s => s.markEndingReached);
  const getPendingConsumables  = useMetaStore(s => s.getPendingConsumables);

  const [selection, setSelection] = useState<Selection>(NO_SELECTION);
  const [rerollingReelIndex, setRerollingReelIndex] = useState<number | null>(null);
  // Reel the score announcement should emerge from. A normal spin's final scoring
  // action is the 3rd reel (default, via ?? 2 below); a power that changes a reel
  // and updates the result sets this to that reel. Reset at the start of each spin.
  const [scoreSourceReel, setScoreSourceReel] = useState<0 | 1 | 2 | null>(null);
  // Dealer arrival prompt: 'taps' = shoulder-tap text popping, 'ask' = speech bubble.
  const [dealerPrompt, setDealerPrompt] = useState<'taps' | 'ask' | null>(null);
  // True while holding on the final spin result before the run-over overlay shows.
  const [endingPending, setEndingPending] = useState(false);
  const endingTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  // Whether this run's payout has been banked yet. The wealth ending defers
  // banking (the player may Continue and earn more), so we bank lazily — on
  // flatline, or when the player finally leaves the wealth screen — exactly once.
  const bankedRef = useRef(false);

  const shakeAnim = useRef(new Animated.Value(0)).current;
  const tapTexts  = useRef([
    new Animated.Value(0), new Animated.Value(0), new Animated.Value(0),
  ]).current;
  const compulsiveSpinTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // ── Compulsion (Cocktail) possession visuals ──
  // A separate shake layer (kept apart from the jackpot shakeAnim so they can't
  // conflict), a forced x1/x2 bet shown on the readout, and a lever self-pull cue.
  const compulsionShake = useRef(new Animated.Value(0)).current;
  // True while a forced spin's reels are turning. The last forced spin zeroes the
  // counter at its START, so this flag carries the possession visuals THROUGH it
  // (the counter alone would drop the visuals one spin early).
  const [forcedSpinInFlight, setForcedSpinInFlight] = useState(false);
  const [compulsionVisualMultiplier, setCompulsionVisualMultiplier] = useState<1 | 2 | null>(null);
  const [compulsionPullSignal, setCompulsionPullSignal] = useState(0);

  // Machine shakes on jackpot — including jackpots made with powers, once the
  // reroll animation has landed.
  useEffect(() => {
    if (!lastResult?.isJackpot || isSpinning || rerollingReelIndex !== null) return;
    shakeAnim.setValue(0);
    Animated.sequence([
      Animated.timing(shakeAnim, { toValue:  9, duration: 45, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: -9, duration: 45, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue:  7, duration: 45, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: -7, duration: 45, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue:  4, duration: 45, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: -4, duration: 45, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue:  0, duration: 60, useNativeDriver: true }),
    ]).start();
  }, [lastResult, isSpinning, rerollingReelIndex]);

  // Dealer arrival: "tap tap tap" pops on screen like he's tapping your
  // shoulder, fades, then his speech bubble asks if you want to see the goods.
  useEffect(() => {
    if (!dealerIncoming) {
      setDealerPrompt(null);
      return;
    }
    setDealerPrompt('taps');
    tapTexts.forEach(v => v.setValue(0));
    Animated.sequence([
      Animated.stagger(280, tapTexts.map(v =>
        Animated.timing(v, { toValue: 1, duration: 130, useNativeDriver: true }))),
      Animated.delay(400),
      Animated.parallel(tapTexts.map(v =>
        Animated.timing(v, { toValue: 0, duration: 220, useNativeDriver: true }))),
    ]).start(({ finished }) => {
      if (finished) setDealerPrompt('ask');
    });
  }, [dealerIncoming]);

  useEffect(() => {
    if (runPhase === 'idle') {
      startNewRun(ownedPermanents, getPendingConsumables());
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // COME: accept the dealer's invitation. We flip the run into the active
  // dealer-visit state (revealDealer → dealerPending) and leave the machine for
  // the FULL dealer scene in run-consumables mode — the shop is no longer drawn
  // as a modal here. DealerShopScreen reads the run offer + applies/declines and
  // navigates back to the machine.
  const handleDealerCome = useCallback(() => {
    revealDealer();
    router.push({ pathname: '/dealer', params: { mode: 'run_consumables' } });
  }, [revealDealer, router]);

  const handleSpin = useCallback(() => {
    setSelection(NO_SELECTION);
    // A fresh spin's score comes from the 3rd reel until a power says otherwise.
    setScoreSourceReel(null);
    spin();
  }, [spin]);

  const handleAllReelsDone = useCallback(() => {
    setSpinning(false);
    const runNow = useRunStore.getState();
    // End check runs first — if the run is over the Dealer should not appear.
    let ending = checkEnding(runNow, useMetaStore.getState());
    // Once the player has Continued past the wealth threshold, the wealth ending
    // no longer fires (only flatline can end the run from here).
    if (ending === 'wealth' && runNow.wealthContinued) ending = null;
    if (ending) {
      // Hold on the final reels + payout, THEN flip to the run-over overlay.
      // endingPending locks the machine (runBusy) so no spin/race during the
      // hold; the guard prevents scheduling a second timer / duplicate overlay.
      if (endingTimer.current) return;
      const endingType = ending;
      setEndingPending(true);
      endingTimer.current = setTimeout(() => {
        endingTimer.current = null;
        setEndingPending(false);
        // Flatline is final — bank now. Wealth defers banking until the player
        // leaves the screen (they may Continue and bank a larger total later),
        // but the win still counts as reached the moment the screen shows.
        if (endingType === 'flatline') {
          bankRun(useRunStore.getState(), endingType);
          bankedRef.current = true;
        } else {
          markEndingReached(endingType);
        }
        endRun(endingType);
      }, FLATLINE_REVEAL_DELAY_MS);
    } else if (runNow.compulsiveSpinSkips > 0) {
      return;
    } else {
      checkDealerTrigger();
    }
  }, [setSpinning, bankRun, markEndingReached, endRun, checkDealerTrigger]);

  // Bank the finished run's payout exactly once. Flatline already banked at the
  // ending hold; the wealth screen defers to here, so leaving it (start again /
  // dealer / shop) commits the bank with the full final total.
  const commitBankIfNeeded = useCallback(() => {
    if (bankedRef.current) return;
    const latest = useRunStore.getState();
    if (latest.lastEnding) {
      bankRun(latest, latest.lastEnding);
      bankedRef.current = true;
    }
  }, [bankRun]);

  // "Continue run?" — resume play past the wealth threshold; nothing is banked
  // yet (the larger total banks when the run truly ends).
  const handleContinueRun = useCallback(() => {
    setSelection(NO_SELECTION);
    continueRun();
  }, [continueRun]);

  const handleNewRun = useCallback(() => {
    if (endingTimer.current) {
      clearTimeout(endingTimer.current);
      endingTimer.current = null;
    }
    commitBankIfNeeded();
    setEndingPending(false);
    setSelection(NO_SELECTION);
    startNewRun(ownedPermanents, getPendingConsumables());
    bankedRef.current = false;
  }, [commitBankIfNeeded, startNewRun, ownedPermanents, getPendingConsumables]);

  // Clear the pending run-over timer if the screen unmounts mid-hold.
  useEffect(() => () => {
    if (endingTimer.current) clearTimeout(endingTimer.current);
  }, []);

  // ── Reel targeting ──
  const handleReelPress = useCallback((i: number) => {
    if (selection.mode === 'reroll') {
      if (rerollReel(i)) {
        setRerollingReelIndex(i);
        // Reroll changes this reel and re-scores → score emerges from it.
        setScoreSourceReel(i as 0 | 1 | 2);
      }
      setSelection(NO_SELECTION);
    } else if (selection.mode === 'lock') {
      lockReel(i);
      setSelection(NO_SELECTION);
    } else if (selection.mode === 'copy_source') {
      setSelection({ mode: 'copy_target', sourceReel: i, consumableId: selection.consumableId });
    } else if (selection.mode === 'copy_target') {
      if (i !== selection.sourceReel) {
        if (useConsumable(selection.consumableId)) {
          copyReel(selection.sourceReel, i);
          // The copy writes onto the target reel and re-scores → score from it.
          setScoreSourceReel(i as 0 | 1 | 2);
        }
        setSelection(NO_SELECTION);
      }
    }
  }, [selection, lockReel, rerollReel, copyReel, useConsumable]);

  const handleConsumable = useCallback((id: string) => {
    const consumable = CONSUMABLES.find(c => c.id === id);

    if (consumable?.effect.type === 'copyReel') {
      // White Powder: enter selection without consuming the charge yet.
      // The charge is consumed only when source + target are both confirmed.
      setSelection({ mode: 'copy_source', consumableId: id });
    } else {
      useConsumable(id);
    }
  }, [useConsumable]);

  const handleShiftReel = useCallback((reelIndex: number, direction: -1 | 1) => {
    if (selection.mode === 'move') {
      if (moveReel(reelIndex, direction)) {
        // Shift changes this reel and re-scores → score emerges from it.
        setScoreSourceReel(reelIndex as 0 | 1 | 2);
      }
    }
    setSelection(NO_SELECTION);
  }, [selection, moveReel]);

  const runBusy =
    isSpinning ||
    rerollingReelIndex !== null ||
    dealerIncoming ||
    dealerPending ||
    endingPending ||
    compulsiveSpinSkips > 0;

  // Compulsion is active while forced spins are pending OR one is still animating
  // (the last forced spin zeroes the counter at its start, so the in-flight flag
  // carries the visuals through it). Purely derived → it tracks the real spin
  // lifecycle exactly and can never lag on or get stuck.
  const compulsionActive =
    runPhase === 'running' && (compulsiveSpinSkips > 0 || forcedSpinInFlight);

  useEffect(() => {
    const modalBusy = rerollingReelIndex !== null || dealerIncoming || dealerPending || endingPending;
    if (runPhase !== 'running' || isSpinning || modalBusy || compulsiveSpinSkips <= 0) return;

    // Possession cues for this forced spin: a self-pull of the lever and a random
    // forced bet (x1/x2 only — never x3) shown on the readout. The spin itself is
    // still fired exactly once, by the timer below — these are visual only.
    setCompulsionVisualMultiplier(Math.random() < 0.5 ? 1 : 2);
    setCompulsionPullSignal(n => n + 1);

    if (compulsiveSpinTimer.current) {
      clearTimeout(compulsiveSpinTimer.current);
    }
    compulsiveSpinTimer.current = setTimeout(() => {
      compulsiveSpinTimer.current = null;
      // Mark the forced spin in flight so the visuals stay through the LAST one
      // (its counter is already 0). Only if it actually started (else don't stick).
      const fired = useRunStore.getState().spin({ compulsive: true });
      setForcedSpinInFlight(fired !== null);
    }, 450);

    return () => {
      if (compulsiveSpinTimer.current) {
        clearTimeout(compulsiveSpinTimer.current);
        compulsiveSpinTimer.current = null;
      }
    };
  }, [runPhase, isSpinning, rerollingReelIndex, dealerIncoming, dealerPending, endingPending, compulsiveSpinSkips]);

  // A forced spin stops being "in flight" the instant its reels stop.
  useEffect(() => {
    if (!isSpinning) setForcedSpinInFlight(false);
  }, [isSpinning]);

  // Safety net: if the in-flight flag is ever left set (e.g. a forced spin that
  // never started), force it off after a generous ceiling so visuals can't stick.
  useEffect(() => {
    if (!forcedSpinInFlight) return;
    const safety = setTimeout(() => setForcedSpinInFlight(false), 8000);
    return () => clearTimeout(safety);
  }, [forcedSpinInFlight]);

  // Clear the forced-bet readout the moment Compulsion ends → back to the player's
  // own multiplier.
  useEffect(() => {
    if (!compulsionActive) setCompulsionVisualMultiplier(null);
  }, [compulsionActive]);

  // Machine vibration for the whole Compulsion: a small fast jitter on its own
  // animated value (independent of the jackpot shakeAnim). Runs while active,
  // reliably stopped + reset when it ends — so it can never shake forever.
  useEffect(() => {
    if (!compulsionActive) return;
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(compulsionShake, { toValue:  1, duration: 45, useNativeDriver: true }),
        Animated.timing(compulsionShake, { toValue: -1, duration: 45, useNativeDriver: true }),
      ]),
    );
    loop.start();
    return () => {
      loop.stop();
      compulsionShake.setValue(0);
    };
  }, [compulsionActive, compulsionShake]);

  const canSpin = runPhase === 'running' && !runBusy && (freeSpins > 0 || neurons >= 1);

  // Sedative Protocol: every 3rd spin costs nothing — mirror spin()'s check.
  const sedativeNext = hasSedative(ownedUpgrades) && freeSpins === 0 && (spinCount + 1) % 3 === 0;
  const energyLocked = forcedRandomBetSpins > 0;
  const noNeuronCostSpin = freeSpins > 0 || decaySkips > 0 || sedativeNext;
  // Abilities blocked while game is busy, powers blocked (Pill), or no result yet
  const powersBlocked = blockPowersSpins > 0;
  const abilitiesUsable = runPhase === 'running' && !runBusy && lastResult !== null && !powersBlocked;

  const hasShift  = ownedPermanents.includes('perm_shift');
  const hasMemory = ownedPermanents.includes('perm_memory');

  // Machine-mounted power buttons. Frame: 1 selected, 0 available, 2 unavailable.
  // Pressing the active power again cancels; pressing another switches selection.
  const powerFrame = (
    mode: Selection['mode'],
    abilityId: 'reroll' | 'shift' | 'memory',
  ): 0 | 1 | 2 =>
    selection.mode === mode ? 1
    : abilitiesUsable && !abilitiesUsed.includes(abilityId) ? 0
    : 2;

  const powers = {
    reroll: {
      visible: true,
      frame: powerFrame('reroll', 'reroll'),
      onPress: () => setSelection(s => (s.mode === 'reroll' ? NO_SELECTION : { mode: 'reroll' })),
    },
    shift: {
      visible: hasShift,
      frame: powerFrame('move', 'shift'),
      onPress: () => setSelection(s => (s.mode === 'move' ? NO_SELECTION : { mode: 'move' })),
    },
    memory: {
      visible: hasMemory,
      frame: powerFrame('lock', 'memory'),
      onPress: () => setSelection(s => (s.mode === 'lock' ? NO_SELECTION : { mode: 'lock' })),
    },
  };

  // Physical stash slots — duplicates occupy separate slots (WATER, WATER), so
  // expand copies into slots rather than stacking with a ×N badge.
  const stashItems = [...CONSUMABLES, ...IN_RUN_ITEMS];
  const stashSlots = buildStashSlots(runConsumables, stashItems);
  const stashUsable = runPhase === 'running' && !runBusy && selection.mode === 'none';

  // The result announcement (PAIR / TRIPLE / JACKPOT + amount) no longer lives in
  // this fixed top label — it bursts from the source reel inside the machine (see
  // ScoreBurst in SlotMachine). The remaining selection hint now sits at the bottom
  // of the screen (see the hint anchor below). Shift has NO hint — its on-reel
  // up/down arrows are self-explanatory, so 'move' deliberately yields null here.
  // Reroll/lock no longer carry a text hint — the on-reel selection arrows
  // (reel_selection overlay) make the "tap a reel" affordance clear. Only the
  // copy (White Powder) flow, which has no arrows, keeps a hint.
  const selectionHint =
    selection.mode === 'copy_source' ? 'TAP THE REEL TO COPY FROM'
    : selection.mode === 'copy_target' ? 'TAP THE REEL TO COPY ONTO'
    : null;

  const selectedReels =
    selection.mode === 'copy_target' ? [selection.sourceReel]
    : [];

  // In 'move' mode the shift arrows (not the reels) take the taps, so reels stay
  // non-tappable; every other targeting mode taps the reels directly.
  const reelsTappable = selection.mode !== 'none' && selection.mode !== 'move' && !runBusy;

  // Compulsion jitter — small fast X (with a touch of Y), additive to the jackpot
  // shake but driven by its own value so the two never interfere. Created ONCE
  // (not inline each render) so we don't rebuild native animated nodes on the root.
  const compulsionShakeX = useRef(
    compulsionShake.interpolate({ inputRange: [-1, 1], outputRange: [-4, 4] }),
  ).current;
  const compulsionShakeY = useRef(
    compulsionShake.interpolate({ inputRange: [-1, 1], outputRange: [-2, 2] }),
  ).current;

  return (
    <Background>

      {/* ── Pixel-art scene: the whole 160×320 virtual canvas as one composition —
             the machine fills it, and the HUD (win label, badges, stash, powers)
             composes into the empty upper region. The jackpot shake lives on the
             outer (screen-space) container so its magnitude stays visually
             constant across devices. ── */}
      <Animated.View
        style={[StyleSheet.absoluteFill, {
          // Only layer the compulsion jitter while it's actually active — at rest
          // the transform is exactly the jackpot shake (no idle vibration).
          transform: compulsionActive
            ? [
                { translateX: shakeAnim },
                { translateX: compulsionShakeX },
                { translateY: compulsionShakeY },
              ]
            : [{ translateX: shakeAnim }],
        }]}
        pointerEvents="box-none"
      >
        <PixelScene>
          <View
            style={{
              position: 'absolute',
              left: vpx(MACHINE_X),
              top: vpx(MACHINE_Y),
              width: vpx(MACHINE_W),
              height: vpx(MACHINE_H),
            }}
          >
            <SlotMachine
              onAllReelsDone={handleAllReelsDone}
              onReelPress={reelsTappable ? handleReelPress : undefined}
              selectedReels={selectedReels}
              shiftActive={selection.mode === 'move'}
              onShiftReel={handleShiftReel}
              reelSelectActive={selection.mode === 'reroll' || selection.mode === 'lock'}
              rerollingReelIndex={rerollingReelIndex}
              onRerollDone={() => setRerollingReelIndex(null)}
              multiplierInteractive={runPhase === 'running' && !runBusy}
              onSelectMultiplier={setBetMultiplier}
              isMultiplierLocked={(m) =>
                // Budget-based: with N spins of neurons left you can afford a ×N
                // bet (one spin that drains that budget), matching the on-screen
                // "SPINS LEFT" meter. Lock ×m only when fewer than m spins remain.
                (energyLocked && m === 3) ||
                (!noNeuronCostSpin && Math.ceil(neurons / ECONOMY.NEURON_DECAY_PER_SPIN) < m)
              }
              onLeverPull={handleSpin}
              leverEnabled={canSpin}
              powers={powers}
              scale={ASSET_SCALE}
              rewardHold={isSpinning || rerollingReelIndex !== null}
              scoreSourceReelIndex={scoreSourceReel}
              forcedMultiplier={compulsionVisualMultiplier}
              compulsionPullSignal={compulsionPullSignal}
            />
          </View>

          {/* ── In-scene HUD: composed into the empty space above the cabinet.
                 Sizes are in asset-space (× ASSET_SCALE via vpx) so text stays
                 crisp (rendered large, downscaled with the rest of the canvas). ── */}
          <View style={styles.hud} pointerEvents="box-none">
            {/* Spacer above the badges. The selection hint moved to the bottom of
                the screen (temporary placement — see the hint anchor below). */}
            <View style={styles.winRow} />

            <View style={styles.badgeRow}>
              {freeSpins > 0 && (
                <Text style={[styles.badge, styles.badgeCyan]}>
                  FREE SPIN{freeSpins > 1 ? ` ×${freeSpins}` : ''}
                </Text>
              )}
              {decaySkips > 0 && (
                <Text style={[styles.badge, styles.badgeViolet]}>NO DECAY ×{decaySkips}</Text>
              )}
              {sedativeNext && (
                <Text style={[styles.badge, styles.badgeViolet]}>SEDATIVE — FREE SPIN</Text>
              )}
              {brainBoostSpins > 0 && (
                <Text style={[styles.badge, styles.badgeOrange]}>BRAIN BOOST ×{brainBoostSpins}</Text>
              )}
              {forcedRandomBetSpins > 0 && (
                <Text style={[styles.badge, styles.badgeGreen]}>ENERGY x{forcedRandomBetSpins}</Text>
              )}
              {cocktailBoostSpins > 0 && (
                <Text style={[styles.badge, styles.badgePink]}>COCKTAIL x{cocktailBoostSpins}</Text>
              )}
              {compulsiveSpinSkips > 0 && (
                <Text style={[styles.badge, styles.badgeRose]}>COMPULSION x{compulsiveSpinSkips}</Text>
              )}
              {guaranteedWinSpins > 0 && (
                <Text style={[styles.badge, styles.badgeAmber]}>WIN GUARANTEED</Text>
              )}
              {powersBlocked && (
                <Text style={[styles.badge, styles.badgeRed]}>POWERS BLOCKED ×{blockPowersSpins}</Text>
              )}
            </View>

            {/* Controls: only the cancel affordance for an active selection lives
                in the HUD now. Powers are machine-mounted buttons; the stash tray
                sits below them on the lower cabinet face (see stashStrip). */}
            <View style={styles.controlsRow}>
              <View style={styles.cancelArea}>
                {/* Powers (reroll/shift/lock) cancel by tapping the lit power
                    again, so no CANCEL is shown for them. The copy flow (White
                    Powder) has no such toggle, so it keeps a CANCEL escape. */}
                {(selection.mode === 'copy_source' || selection.mode === 'copy_target') && (
                  <Pressable style={styles.cancelBtn} onPress={() => setSelection(NO_SELECTION)}>
                    <Text style={styles.cancelText}>CANCEL</Text>
                  </Pressable>
                )}
              </View>
            </View>
          </View>

          {/* ── Stash tray — sits on the empty lower cabinet face, directly BELOW
                 the machine-mounted power buttons (powers above, stash below). The
                 red panel here (virtual y≈240–283) is clear of reels/meters/lever/
                 powers, so the tray doesn't overlap any functional art. ── */}
          <View style={styles.stashStrip} pointerEvents="box-none">
            <Stash
              items={stashSlots}
              onUse={handleConsumable}
              disabled={!stashUsable}
              width={vpx(48)}
            />
          </View>
        </PixelScene>
      </Animated.View>

      {/* ── Scores table button — top-right corner, clear of the centred HUD and
             the machine. Opens the read-only scores screen. ── */}
      <SafeAreaView style={styles.scoresAnchor} pointerEvents="box-none">
        <Pressable style={styles.scoresBtn} onPress={() => router.push('/scores')}>
          <Text style={styles.scoresText}>SCORES</Text>
        </Pressable>
      </SafeAreaView>

      {/* ── Power/selection hint — TEMPORARY placement at the bottom of the screen,
             clear of the reels, meters, powers and stash. Pixel font (no
             fontWeight, so the DTM face is kept). Shift has no hint (arrows only). ── */}
      {selectionHint && (
        <SafeAreaView style={styles.hintAnchor} pointerEvents="none">
          <Text style={styles.bottomHint}>{selectionHint}</Text>
        </SafeAreaView>
      )}

      {/* ── Dealer arrival: shoulder taps ── */}
      {dealerPrompt === 'taps' && (
        <View style={styles.tapOverlay} pointerEvents="none">
          {tapTexts.map((v, i) => (
            <Animated.Text
              key={i}
              style={[
                styles.tapText,
                { opacity: v, transform: [{ translateY: i * 26 }, { translateX: (i - 1) * 30 }] },
              ]}
            >
              tap
            </Animated.Text>
          ))}
        </View>
      )}

      {/* ── Dealer arrival: portrait + speech bubble ── */}
      {dealerPrompt === 'ask' && (
        <View style={styles.bubbleOverlay}>
          <View style={styles.bubble}>
            <Text style={styles.bubbleText}>"I've got something for you"</Text>
            <View style={styles.bubbleBtnRow}>
              <Pressable style={styles.bubbleYesBtn} onPress={handleDealerCome}>
                <Text style={styles.bubbleYesText}>COME</Text>
              </Pressable>
              <Pressable style={styles.bubbleNoBtn} onPress={declineDealerVisit}>
                <Text style={styles.bubbleNoText}>IGNORE</Text>
              </Pressable>
            </View>
          </View>
          <View style={styles.bubbleTail} />
          {/* Same dealer as the dealer scene: frame 2 of dealer_portrait.png,
              cropped to the figure and scaled up so it's readable (not tiny,
              not stretched). */}
          <View style={styles.dealerArrivalPortrait}>
            <Image
              source={DEALER_SHOP_PORTRAIT}
              style={{
                position: 'absolute',
                left: -DEALER_PORTRAIT_SRC_X * DEALER_PORTRAIT_SCALE,
                top:  -DEALER_CROP.y * DEALER_PORTRAIT_SCALE,
                width:  DEALER_SHEET_SIZE * DEALER_PORTRAIT_SCALE,
                height: DEALER_SHEET_SIZE * DEALER_PORTRAIT_SCALE,
              }}
              resizeMode="stretch"
              fadeDuration={0}
            />
          </View>
        </View>
      )}

      {/* The in-run dealer's consumable offer is NOT a modal — COME leaves the
          machine for the full DealerShopScreen in run-consumables mode (see
          handleDealerCome). Only the invitation prompt lives here. */}

      {/* Stash-full is handled on the dealer screen now (drag an item onto the
          dealer to throw one out) — no gift/discard modal here. */}

      {/* ── Run-over overlay ── */}
      {runPhase === 'over' && (
        <View style={styles.overlay}>
          {lastEnding === 'wealth' ? (
            <>
              <Text style={[styles.overlayTitle, styles.wealthTitle]}>WEALTH</Text>
              <Text style={styles.overlayBody}>
                You have everything.{'\n'}It isn't enough.
              </Text>
              <Text style={styles.overlayBody}>
                {Math.floor(lucidityCoins * ECONOMY.END_OF_RUN_LUCIDITY_KEPT)} Lucidity kept (10% of {lucidityCoins})
              </Text>
            </>
          ) : (
            <>
              <Text style={styles.overlayTitle}>FLATLINE</Text>
              {/* Show the run's score, then drain it down to the 10% kept so the
                  player watches the loss happen. Visual only — banking already
                  kept the real 10% when the run ended. */}
              <FlatlineKeptCountdown
                total={lucidityCoins}
                keptFraction={ECONOMY.END_OF_RUN_LUCIDITY_KEPT}
              />
            </>
          )}
          {lastEnding === 'wealth' && (
            <Pressable style={styles.continueBtn} onPress={handleContinueRun}>
              <Text style={styles.continueText}>CONTINUE RUN?</Text>
            </Pressable>
          )}
          <Pressable style={styles.restartBtn} onPress={handleNewRun}>
            <Text style={styles.restartText}>START AGAIN</Text>
          </Pressable>
          <Pressable style={styles.shopBtn} onPress={() => { commitBankIfNeeded(); router.push('/dealer'); }}>
            <Text style={styles.shopText}>VISIT THE DEALER</Text>
          </Pressable>
          <Pressable style={styles.metaShopBtn} onPress={() => { commitBankIfNeeded(); router.push('/shop'); }}>
            <Text style={styles.metaShopText}>SPEND LUCIDITY</Text>
          </Pressable>
        </View>
      )}
    </Background>
  );
}

const styles = StyleSheet.create({
  // ── In-scene HUD ────────────────────────────────────────────────────────────
  // The HUD lives INSIDE PixelScene (one full-canvas composition), positioned in
  // the empty space above the cabinet. All sizes are asset-space (× ASSET_SCALE
  // via vpx), matching MachineScreenMeters, so text renders large and downscales
  // crisp with the rest of the canvas — no separate screen-space UI bands.
  hud: {
    position: 'absolute',
    left: 0,
    top: 0,
    width: vpx(VIRTUAL_WIDTH),
    height: vpx(HUD_HEIGHT),
    paddingTop: vpx(6),
    alignItems: 'center',
  },

  // Top HUD spacer (formerly the win label / selection hint row).
  winRow: {
    height: vpx(16),
    alignItems: 'center',
    justifyContent: 'center',
  },

  // Selection/power hint — temporary bottom placement, screen-space. Pixel font
  // (NO fontWeight, or Android drops the DTM face for the system sans), on a dark
  // pill for readability over whatever sits behind it.
  hintAnchor: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    alignItems: 'center',
    paddingBottom: 12,
    paddingHorizontal: 16,
  },
  bottomHint: {
    color: '#00e5ff',
    fontSize: 13,
    letterSpacing: 1,
    textAlign: 'center',
    backgroundColor: 'rgba(0,0,0,0.6)',
    paddingVertical: 6,
    paddingHorizontal: 14,
    borderRadius: 6,
    overflow: 'hidden',
  },

  // Status badges — shared size, per-effect colour.
  badgeRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: vpx(4),
    minHeight: vpx(10),
    paddingHorizontal: vpx(6),
  },
  badge: {
    fontSize: vpx(7),
    fontWeight: '700',
    letterSpacing: vpx(0.6),
  },
  badgeCyan:   { color: '#00e5ff' },
  badgeViolet: { color: '#a855f7' },
  badgeOrange: { color: '#f97316' },
  badgeGreen:  { color: '#22c55e' },
  badgePink:   { color: '#f0abfc' },
  badgeRose:   { color: '#f43f5e' },
  badgeAmber:  { color: '#fbbf24' },
  badgeRed:    { color: '#ef4444' },

  // Controls row: stash tray (left) + cancel affordance, anchored to the bottom of
  // the HUD region so it sits just above the cabinet. Powers are on the machine.
  controlsRow: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: vpx(6),
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: vpx(8),
    gap: vpx(6),
  },
  cancelArea: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },

  // Scores button — screen-space, pinned to the top-right corner.
  scoresAnchor: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    alignItems: 'flex-end',
    paddingTop: 6,
    paddingHorizontal: 10,
  },
  scoresBtn: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 6,
    backgroundColor: 'rgba(0,0,0,0.55)',
    borderWidth: 1,
    borderColor: '#fbbf2455',
  },
  scoresText: {
    color: '#fbbf24',
    fontSize: 11,
    letterSpacing: 2,
  },

  // Stash tray, placed on the lower red cabinet face just under the power
  // buttons (POWER_HITS top ≈ y223). Asset-space coords (vpx) like the rest of
  // the in-scene composition; centred horizontally (tray is 48 wide → left 56).
  stashStrip: {
    position: 'absolute',
    top: vpx(250),
    left: vpx(56),
    width: vpx(48),
  },
  itemBtnDisabled: {
    opacity: 0.35,
  },

  cancelBtn: {
    paddingVertical: vpx(5),
    paddingHorizontal: vpx(9),
  },
  cancelText: {
    color: '#94a3b8',
    fontSize: vpx(7),
    fontWeight: '700',
    letterSpacing: vpx(1),
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

  // Dealer arrival prompt
  tapOverlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tapText: {
    color: '#a855f7',
    fontFamily: PIXEL_FONT,
    fontSize: 24,
    fontWeight: '900',
    fontStyle: 'italic',
    letterSpacing: 4,
    textShadowColor: 'rgba(0,0,0,0.9)',
    textShadowRadius: 6,
  },
  bubbleOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.55)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  bubble: {
    backgroundColor: '#13091f',
    borderColor: '#a855f7',
    borderWidth: 1,
    borderRadius: 16,
    paddingVertical: 18,
    paddingHorizontal: 24,
    gap: 16,
    alignItems: 'center',
    maxWidth: '80%',
  },
  bubbleTail: {
    width: 0,
    height: 0,
    borderLeftWidth: 10,
    borderRightWidth: 10,
    borderTopWidth: 14,
    borderLeftColor: 'transparent',
    borderRightColor: 'transparent',
    borderTopColor: '#a855f7',
    marginTop: -1,
  },
  bubbleText: {
    color: '#e2e8f0',
    fontSize: 15,
    fontStyle: 'italic',
    textAlign: 'center',
  },
  bubbleBtnRow: {
    flexDirection: 'row',
    gap: 12,
  },
  bubbleYesBtn: {
    backgroundColor: '#a855f7',
    paddingVertical: 10,
    paddingHorizontal: 28,
    borderRadius: 8,
  },
  bubbleYesText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '900',
    letterSpacing: 2,
  },
  bubbleNoBtn: {
    paddingVertical: 10,
    paddingHorizontal: 28,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#475569',
  },
  bubbleNoText: {
    color: '#64748b',
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 2,
  },

  // Dealer portraits + offer hands
  dealerArrivalPortrait: {
    width: DEALER_PORTRAIT_W,
    height: DEALER_PORTRAIT_H,
    marginTop: 8,
    alignSelf: 'center',
    overflow: 'hidden',
  },
  dealerSpeech: {
    backgroundColor: '#13091f',
    borderColor: '#a855f7',
    borderWidth: 1,
    borderRadius: 14,
    paddingVertical: 14,
    paddingHorizontal: 18,
    maxWidth: '88%',
    minHeight: 84,
    justifyContent: 'center',
  },
  dealerSpeechTail: {
    width: 0,
    height: 0,
    borderLeftWidth: 9,
    borderRightWidth: 9,
    borderBottomWidth: 12,
    borderLeftColor: 'transparent',
    borderRightColor: 'transparent',
    borderBottomColor: '#a855f7',
    marginBottom: -1,
    marginTop: -1,
    transform: [{ rotate: '180deg' }],
  },
  dealerHandsRow: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  dealerHandsImg: {
    width: 256,
    height: 128,
  },
  dealerHandsOffers: {
    ...StyleSheet.absoluteFillObject,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-evenly',
  },
  dealerHandSlot: {
    alignItems: 'center',
    justifyContent: 'center',
    padding: 6,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: 'transparent',
    gap: 2,
  },
  dealerHandSlotSelected: {
    borderColor: '#00e5ff',
    backgroundColor: 'rgba(0,229,255,0.12)',
  },
  dealerHandIcon: {
    width: 44,
    height: 44,
  },
  dealerHandName: {
    color: '#e2e8f0',
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 1,
    maxWidth: 90,
  },
  dealerInspectName: {
    color: '#00e5ff',
    fontSize: 14,
    fontWeight: '900',
    letterSpacing: 1,
    textAlign: 'center',
    marginBottom: 5,
  },
  dealerInspectDesc: {
    color: '#cbd5e1',
    fontSize: 12,
    lineHeight: 17,
    textAlign: 'center',
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
  continueBtn: {
    marginTop: 24,
    marginBottom: 4,
    backgroundColor: '#22c55e',
    paddingVertical: 14,
    paddingHorizontal: 40,
    borderRadius: 8,
  },
  continueText: {
    color: '#06210f',
    fontSize: 16,
    fontWeight: '900',
    letterSpacing: 3,
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
  metaShopBtn: {
    marginTop: 10,
    paddingVertical: 12,
    paddingHorizontal: 32,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#22d3ee',
  },
  metaShopText: {
    color: '#22d3ee',
    fontSize: 13,
    fontWeight: '800',
    letterSpacing: 3,
  },
});
