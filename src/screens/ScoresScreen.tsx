import React, { useMemo } from 'react';
import { View, Image, Pressable, StyleSheet, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Text } from '../components/PixelText';
import { Symbol } from '../components/Symbol';
import { useMetaStore } from '../state/metaState';
import { COIN_ICON } from '../content/uiAssets';
import { BASE_SYMBOL_CYCLE } from '../content/symbols';
import { PAIR_SCORE, TRIPLE_SCORE, JACKPOT_SCORE } from '../content/payouts';

// Pair/triple points table, built from the canonical payout config (no duplicated
// numbers). Brain's triple is the jackpot, so it uses JACKPOT_SCORE.
const POINTS_ROWS = BASE_SYMBOL_CYCLE.map(id => ({
  id,
  pair:   PAIR_SCORE[id] ?? 0,
  triple: id === 'brain' ? JACKPOT_SCORE : (TRIPLE_SCORE[id] ?? 0),
  jackpot: id === 'brain',
}));

// Read-only scores/records table. Opened from the SCORE button on the machine
// screen. Shows the persistent meta records plus the pair/triple points table.
// All text uses the DTM pixel font via the PixelText wrapper.
export function ScoresScreen() {
  const router = useRouter();

  const lucidityWallet = useMetaStore(s => s.lucidityWallet);
  const history        = useMetaStore(s => s.history);
  const endingsReached = useMetaStore(s => s.endingsReached);

  const rows: Array<{ label: string; value: string }> = useMemo(() => [
    { label: 'BEST RUN SCORE', value: `${history.bestScoreRun}` },
    { label: 'RUNS PLAYED',    value: `${history.runsPlayed}` },
    { label: 'WEALTH REACHED', value: endingsReached.includes('wealth') ? 'YES' : '—' },
  ], [history.bestScoreRun, history.runsPlayed, endingsReached]);

  return (
    <SafeAreaView style={styles.root}>
      {/* Header: back (left) + wallet (right) in the flow; the title is absolutely
          centred across the full width so it stays centred regardless of the
          differing back/wallet widths. */}
      <View style={styles.header}>
        <Pressable
          style={({ pressed }) => [styles.backBtn, pressed && styles.pressFeedback]}
          onPress={() => router.back()}
        >
          <Text style={styles.backText}>← BACK</Text>
        </Pressable>
        <View style={styles.titleWrap} pointerEvents="none">
          <Text style={styles.title}>SCORES</Text>
        </View>
        <View style={styles.walletPill}>
          <Image source={COIN_ICON} style={styles.walletCoin} resizeMode="contain" fadeDuration={0} />
          <Text style={styles.walletText}>{lucidityWallet}</Text>
        </View>
      </View>

      <ScrollView contentContainerStyle={styles.tableContent}>
        <View style={styles.table}>
          {rows.map((r, i) => (
            <View key={r.label} style={[styles.row, i % 2 === 1 && styles.rowAlt]}>
              <Text style={styles.rowLabel}>{r.label}</Text>
              <Text style={styles.rowValue}>{r.value}</Text>
            </View>
          ))}
        </View>

        {/* Points table — under WEALTH REACHED, explains pair/triple scoring. */}
        <Text style={styles.sectionTitle}>POINTS TABLE</Text>
        <View style={styles.table}>
          <View style={[styles.row, styles.ptHeaderRow]}>
            <Text style={[styles.ptHead, styles.ptSymCol]}>SYMBOL</Text>
            <Text style={[styles.ptHead, styles.ptNumCol]}>PAIR</Text>
            <Text style={[styles.ptHead, styles.ptNumCol]}>TRIPLE</Text>
          </View>
          {POINTS_ROWS.map((r, i) => (
            <View key={r.id} style={[styles.row, i % 2 === 1 && styles.rowAlt]}>
              <View style={styles.ptSymCol}>
                <Symbol symbol={r.id} size={28} tile={false} />
              </View>
              <Text style={[styles.rowValue, styles.ptNumCol]}>+{r.pair}</Text>
              <Text style={[styles.rowValue, styles.ptNumCol, r.jackpot && styles.ptJackpot]}>
                +{r.triple}{r.jackpot ? ' ★' : ''}
              </Text>
            </View>
          ))}
        </View>
        <Text style={styles.note}>BRAIN triple = JACKPOT</Text>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#0e081c',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: 10,
    paddingBottom: 12,
  },
  titleWrap: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
  },
  backBtn: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 6,
    backgroundColor: 'rgba(0,0,0,0.55)',
    borderWidth: 1,
    borderColor: '#00e5ff44',
  },
  pressFeedback: {
    opacity: 0.7,
    transform: [{ scale: 0.97 }],
  },
  backText: {
    color: '#00e5ff',
    fontSize: 12,
    letterSpacing: 2,
  },
  title: {
    color: '#fbbf24',
    fontSize: 18,
    letterSpacing: 4,
    textAlign: 'center',
  },
  walletPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: 'rgba(0,0,0,0.55)',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 6,
  },
  walletCoin: {
    width: 14,
    height: 14,
  },
  walletText: {
    color: '#00e5ff',
    fontSize: 14,
    letterSpacing: 1,
  },
  tableContent: {
    paddingHorizontal: 16,
    paddingBottom: 32,
  },
  table: {
    borderWidth: 1,
    borderColor: '#00e5ff33',
    borderRadius: 10,
    overflow: 'hidden',
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 14,
    paddingHorizontal: 16,
  },
  rowAlt: {
    backgroundColor: 'rgba(255,255,255,0.03)',
  },
  rowLabel: {
    color: '#cbd5e1',
    fontSize: 13,
    letterSpacing: 1,
  },
  rowValue: {
    color: '#7df9c6',
    fontSize: 15,
    letterSpacing: 1,
  },

  // ── Points table ──
  sectionTitle: {
    color: '#fbbf24',
    fontSize: 13,
    letterSpacing: 3,
    marginTop: 22,
    marginBottom: 8,
  },
  ptHeaderRow: {
    backgroundColor: 'rgba(0,229,255,0.10)',
    paddingVertical: 10,
  },
  ptHead: {
    color: '#00e5ff',
    fontSize: 11,
    letterSpacing: 1,
  },
  ptSymCol: {
    flex: 2,
  },
  ptNumCol: {
    flex: 1,
    textAlign: 'right',
  },
  ptJackpot: {
    color: '#ff2d78',
  },
  note: {
    color: '#64748b',
    fontSize: 10,
    letterSpacing: 1,
    marginTop: 8,
    textAlign: 'center',
  },
});
