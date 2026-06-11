import React from 'react';
import {
  View,
  Text,
  Pressable,
  StyleSheet,
  SafeAreaView,
  ScrollView,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useMetaStore } from '../state/metaState';
import { ABILITY_UPGRADES, CORRUPTED_UPGRADES, POSITIVE_UPGRADES } from '../content/upgrades';
import { CONSUMABLES } from '../content/consumables';
import type { Upgrade } from '../content/upgrades';
import type { Consumable } from '../content/consumables';

export function ShopScreen() {
  const router = useRouter();
  const lucidityWallet      = useMetaStore(s => s.lucidityWallet);
  const ownedPermanents     = useMetaStore(s => s.ownedPermanents);
  const pendingConsumables  = useMetaStore(s => s.pendingConsumables);
  const corruptionEverUsed  = useMetaStore(s => s.corruptionEverUsed);
  const buyUpgrade          = useMetaStore(s => s.buyUpgrade);
  const buyConsumableCharge = useMetaStore(s => s.buyConsumableCharge);

  function upgradeStatus(upgrade: Upgrade): 'owned' | 'locked' | 'tooPoor' | 'buyable' {
    if (ownedPermanents.includes(upgrade.id)) return 'owned';
    if (upgrade.requiresId && !ownedPermanents.includes(upgrade.requiresId)) return 'locked';
    if (lucidityWallet < upgrade.cost) return 'tooPoor';
    return 'buyable';
  }

  function consumableStatus(c: Consumable): 'tooPoor' | 'buyable' {
    return lucidityWallet < c.shopCost ? 'tooPoor' : 'buyable';
  }

  function renderUpgradeCard(upgrade: Upgrade, accent: string) {
    const status = upgradeStatus(upgrade);
    return (
      <View key={upgrade.id} style={[styles.card, { borderColor: accent + '55' }]}>
        <View style={styles.cardText}>
          <Text style={styles.cardName}>{upgrade.name}</Text>
          <Text style={styles.cardDesc}>{upgrade.description}</Text>
          {status === 'locked' && (
            <Text style={styles.cardLocked}>Requires previous tier</Text>
          )}
        </View>
        <Pressable
          style={[
            styles.buyBtn,
            { backgroundColor: accent },
            status === 'owned' && styles.buyBtnOwned,
            (status === 'locked' || status === 'tooPoor') && styles.buyBtnDisabled,
          ]}
          disabled={status !== 'buyable'}
          onPress={() => buyUpgrade(upgrade.id)}
        >
          <Text style={styles.buyBtnText}>
            {status === 'owned' ? 'OWNED' : upgrade.cost}
          </Text>
        </Pressable>
      </View>
    );
  }

  function renderConsumableCard(c: Consumable) {
    const status  = consumableStatus(c);
    const charges = pendingConsumables[c.id] ?? 0;
    return (
      <View key={c.id} style={[styles.card, styles.cardConsumable]}>
        <View style={styles.cardText}>
          <View style={styles.cardNameRow}>
            <Text style={styles.cardName}>{c.name}</Text>
            {charges > 0 && (
              <Text style={styles.cardCharges}>×{charges} queued</Text>
            )}
          </View>
          <Text style={styles.cardDesc}>{c.description}</Text>
        </View>
        <Pressable
          style={[
            styles.buyBtn,
            styles.buyBtnConsumable,
            status === 'tooPoor' && styles.buyBtnDisabled,
          ]}
          disabled={status === 'tooPoor'}
          onPress={() => buyConsumableCharge(c.id)}
        >
          <Text style={styles.buyBtnText}>{c.shopCost}</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <View style={styles.root}>
      <SafeAreaView style={styles.safe}>
        <View style={styles.header}>
          <Text style={styles.title}>THE DEALER</Text>
          <Text style={styles.wallet}>{lucidityWallet} LUCIDITY</Text>
        </View>

        <ScrollView contentContainerStyle={styles.list}>

          {/* ── POWERS ── */}
          <Text style={styles.sectionLabel}>POWERS</Text>
          <Text style={styles.sectionNote}>
            Permanent abilities. 1 use unlocked per run.
          </Text>
          {ABILITY_UPGRADES.map(u => renderUpgradeCard(u, '#a855f7'))}

          {/* ── SUPPLIES ── */}
          <Text style={[styles.sectionLabel, styles.sectionLabelCyan]}>SUPPLIES</Text>
          <Text style={styles.sectionNote}>
            Single-use charges brought into your next run. Unused charges are lost at run end.
          </Text>
          {CONSUMABLES.map(c => renderConsumableCard(c))}

          {/* ── CORRUPTED ── */}
          <Text style={[styles.sectionLabel, styles.sectionLabelRed]}>CORRUPTED</Text>
          <Text style={styles.sectionNote}>
            {corruptionEverUsed
              ? 'You are already corrupted. It does not wash off.'
              : 'Everything here changes you. Permanently.'}
          </Text>
          {CORRUPTED_UPGRADES.map(u => renderUpgradeCard(u, '#ef4444'))}

          {/* ── POSITIVE ── */}
          <Text style={[styles.sectionLabel, styles.sectionLabelGold]}>POSITIVE</Text>
          <Text style={styles.sectionNote}>
            Enhancements that do not corrupt your record.
          </Text>
          {POSITIVE_UPGRADES.map(u => renderUpgradeCard(u, '#22c55e'))}

        </ScrollView>

        <Pressable style={styles.backBtn} onPress={() => router.back()}>
          <Text style={styles.backText}>BACK TO THE MACHINE</Text>
        </Pressable>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#100618',
  },
  safe: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 12,
    paddingBottom: 8,
  },
  title: {
    color: '#a855f7',
    fontSize: 22,
    fontWeight: '900',
    letterSpacing: 5,
  },
  wallet: {
    color: '#00e5ff',
    fontSize: 14,
    fontWeight: '800',
  },

  sectionLabel: {
    color: '#a855f7',
    fontSize: 11,
    fontWeight: '900',
    letterSpacing: 4,
    paddingHorizontal: 4,
    paddingTop: 16,
    paddingBottom: 2,
  },
  sectionLabelCyan: {
    color: '#00e5ff',
  },
  sectionLabelRed: {
    color: '#ef4444',
  },
  sectionLabelGold: {
    color: '#22c55e',
  },
  sectionNote: {
    color: '#64748b',
    fontSize: 10,
    fontStyle: 'italic',
    paddingHorizontal: 4,
    paddingBottom: 6,
  },

  list: {
    paddingHorizontal: 16,
    paddingBottom: 8,
    gap: 8,
  },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(168,85,247,0.08)',
    borderColor: 'rgba(168,85,247,0.35)',
    borderWidth: 1,
    borderRadius: 10,
    padding: 14,
    gap: 12,
  },
  cardConsumable: {
    backgroundColor: 'rgba(0,229,255,0.05)',
    borderColor: 'rgba(0,229,255,0.25)',
  },
  cardText: {
    flex: 1,
    gap: 2,
  },
  cardNameRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  cardName: {
    color: '#e2e8f0',
    fontSize: 14,
    fontWeight: '800',
    letterSpacing: 1,
  },
  cardCharges: {
    color: '#00e5ff',
    fontSize: 11,
    fontWeight: '700',
  },
  cardDesc: {
    color: '#94a3b8',
    fontSize: 12,
  },
  cardLocked: {
    color: '#f97316',
    fontSize: 10,
    fontWeight: '700',
  },
  buyBtn: {
    backgroundColor: '#a855f7',
    borderRadius: 6,
    paddingVertical: 10,
    paddingHorizontal: 14,
    minWidth: 62,
    alignItems: 'center',
  },
  buyBtnConsumable: {
    backgroundColor: '#0ea5e9',
  },
  buyBtnOwned: {
    backgroundColor: 'rgba(148,163,184,0.25)',
  },
  buyBtnDisabled: {
    opacity: 0.35,
  },
  buyBtnText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '900',
  },
  backBtn: {
    margin: 16,
    paddingVertical: 14,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#00e5ff',
    alignItems: 'center',
  },
  backText: {
    color: '#00e5ff',
    fontSize: 13,
    fontWeight: '800',
    letterSpacing: 3,
  },
});
