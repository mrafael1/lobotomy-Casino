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
import { CONSUMABLES, MAX_CONSUMABLE_CHARGES_PER_SLOT, MAX_CONSUMABLE_SLOTS } from '../content/consumables';
import type { Upgrade } from '../content/upgrades';
import type { Consumable } from '../content/consumables';

// Groups an upgrade list into individual cards and tier-group rows.
// Returns an array of either a single Upgrade or an array of Upgrades (a tier group).
function groupUpgrades(list: ReadonlyArray<Upgrade>): Array<Upgrade | Upgrade[]> {
  const result: Array<Upgrade | Upgrade[]> = [];
  const seen = new Set<string>();

  for (const u of list) {
    if (seen.has(u.id)) continue;
    if (u.tierGroup) {
      const group = list.filter(x => x.tierGroup === u.tierGroup);
      group.forEach(x => seen.add(x.id));
      result.push(group);
    } else {
      seen.add(u.id);
      result.push(u);
    }
  }
  return result;
}

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

  function consumableStatus(c: Consumable): 'maxed' | 'tooPoor' | 'slotsFull' | 'buyable' {
    const charges = pendingConsumables[c.id] ?? 0;
    if (charges >= MAX_CONSUMABLE_CHARGES_PER_SLOT) return 'maxed';
    if (lucidityWallet < c.shopCost) return 'tooPoor';
    const alreadyHas = charges > 0;
    if (!alreadyHas) {
      const distinctSlots = Object.values(pendingConsumables).filter(n => (n ?? 0) > 0).length;
      if (distinctSlots >= MAX_CONSUMABLE_SLOTS) return 'slotsFull';
    }
    return 'buyable';
  }

  // Single upgrade card (non-tiered)
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

  // Tier group card: one row with N tier buttons side by side
  function renderTierGroupCard(group: Upgrade[], accent: string) {
    const name = group[0].name;
    return (
      <View key={group[0].tierGroup} style={[styles.card, styles.tierCard, { borderColor: accent + '55' }]}>
        <Text style={styles.cardName}>{name}</Text>
        <View style={styles.tierRow}>
          {group.map(upgrade => {
            const status = upgradeStatus(upgrade);
            return (
              <Pressable
                key={upgrade.id}
                style={[
                  styles.tierBtn,
                  { borderColor: accent + '88' },
                  status === 'owned'   && [styles.tierBtnOwned,   { borderColor: accent }],
                  status === 'buyable' && [styles.tierBtnBuyable, { borderColor: accent, backgroundColor: accent + '22' }],
                  (status === 'locked' || status === 'tooPoor') && styles.tierBtnDisabled,
                ]}
                disabled={status !== 'buyable'}
                onPress={() => buyUpgrade(upgrade.id)}
              >
                <Text style={[styles.tierLabel, status === 'owned' && { color: accent }]}>
                  {upgrade.tierLabel}
                </Text>
                {status === 'locked' ? (
                  <Text style={styles.tierLock}>🔒</Text>
                ) : status === 'owned' ? (
                  <Text style={[styles.tierCost, { color: accent }]}>OWNED</Text>
                ) : (
                  <Text style={[
                    styles.tierCost,
                    status === 'buyable' && { color: accent },
                  ]}>
                    {upgrade.cost}
                  </Text>
                )}
              </Pressable>
            );
          })}
        </View>
        {/* Description of the highest owned or next purchasable tier */}
        {(() => {
          const next = group.find(u => upgradeStatus(u) !== 'owned');
          const desc = next ? next.description : group[group.length - 1].description;
          return <Text style={styles.tierDesc}>{desc}</Text>;
        })()}
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
          {status === 'slotsFull' && (
            <Text style={styles.cardLocked}>Both supply slots are full</Text>
          )}
          {status === 'maxed' && (
            <Text style={styles.cardLocked}>Supply locked at 2 charges</Text>
          )}
        </View>
        <Pressable
          style={[
            styles.buyBtn,
            styles.buyBtnConsumable,
            status !== 'buyable' && styles.buyBtnDisabled,
          ]}
          disabled={status !== 'buyable'}
          onPress={() => buyConsumableCharge(c.id)}
        >
          <Text style={styles.buyBtnText}>
            {status === 'maxed' ? 'LOCKED' : c.shopCost}
          </Text>
        </Pressable>
      </View>
    );
  }

  function renderSection(list: ReadonlyArray<Upgrade>, accent: string) {
    return groupUpgrades(list).map(item =>
      Array.isArray(item)
        ? renderTierGroupCard(item, accent)
        : renderUpgradeCard(item, accent),
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
          {renderSection(ABILITY_UPGRADES, '#a855f7')}

          {/* ── SUPPLIES ── */}
          <Text style={[styles.sectionLabel, styles.sectionLabelCyan]}>SUPPLIES</Text>
          <Text style={styles.sectionNote}>
            Charges carried into your next run (max 2 types). Unused charges are lost at run end.
          </Text>
          {CONSUMABLES.map(c => renderConsumableCard(c))}

          {/* ── CORRUPTED ── */}
          <Text style={[styles.sectionLabel, styles.sectionLabelRed]}>CORRUPTED</Text>
          <Text style={styles.sectionNote}>
            {corruptionEverUsed
              ? 'You are already corrupted. It does not wash off.'
              : 'Everything here changes you. Permanently.'}
          </Text>
          {renderSection(CORRUPTED_UPGRADES, '#ef4444')}

          {/* ── POSITIVE ── */}
          <Text style={[styles.sectionLabel, styles.sectionLabelGold]}>POSITIVE</Text>
          <Text style={styles.sectionNote}>
            Enhancements that do not corrupt your record.
          </Text>
          {renderSection(POSITIVE_UPGRADES, '#22c55e')}

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
  sectionLabelCyan: { color: '#00e5ff' },
  sectionLabelRed:  { color: '#ef4444' },
  sectionLabelGold: { color: '#22c55e' },
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

  // ── Standard single-upgrade card ──
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

  // ── Tier group card ──
  tierCard: {
    flexDirection: 'column',
    alignItems: 'stretch',
    gap: 10,
  },
  tierRow: {
    flexDirection: 'row',
    gap: 8,
  },
  tierBtn: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderRadius: 8,
    paddingVertical: 10,
    gap: 4,
    backgroundColor: 'rgba(255,255,255,0.03)',
  },
  tierBtnOwned: {
    backgroundColor: 'rgba(148,163,184,0.12)',
  },
  tierBtnBuyable: {
    // accent color applied inline
  },
  tierBtnDisabled: {
    opacity: 0.35,
  },
  tierLabel: {
    color: '#94a3b8',
    fontSize: 13,
    fontWeight: '900',
    letterSpacing: 1,
  },
  tierCost: {
    color: '#64748b',
    fontSize: 11,
    fontWeight: '700',
  },
  tierLock: {
    fontSize: 13,
  },
  tierDesc: {
    color: '#94a3b8',
    fontSize: 12,
    paddingTop: 2,
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
