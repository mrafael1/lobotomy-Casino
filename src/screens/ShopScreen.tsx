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
import { CORRUPTED_UPGRADES } from '../content/upgrades';
import type { Upgrade } from '../content/upgrades';

export function ShopScreen() {
  const router = useRouter();
  const lucidityWallet     = useMetaStore(s => s.lucidityWallet);
  const ownedPermanents    = useMetaStore(s => s.ownedPermanents);
  const corruptionEverUsed = useMetaStore(s => s.corruptionEverUsed);
  const buyUpgrade         = useMetaStore(s => s.buyUpgrade);

  function statusFor(upgrade: Upgrade): 'owned' | 'locked' | 'tooPoor' | 'buyable' {
    if (ownedPermanents.includes(upgrade.id)) return 'owned';
    if (upgrade.requiresId && !ownedPermanents.includes(upgrade.requiresId)) return 'locked';
    if (lucidityWallet < upgrade.cost) return 'tooPoor';
    return 'buyable';
  }

  return (
    <View style={styles.root}>
      <SafeAreaView style={styles.safe}>
        <View style={styles.header}>
          <Text style={styles.title}>THE DEALER</Text>
          <Text style={styles.wallet}>{lucidityWallet} LUCIDITY</Text>
        </View>

        <Text style={styles.warning}>
          {corruptionEverUsed
            ? 'You are already corrupted. It does not wash off.'
            : 'Everything here changes you. Permanently.'}
        </Text>

        <ScrollView contentContainerStyle={styles.list}>
          {CORRUPTED_UPGRADES.map(upgrade => {
            const status = statusFor(upgrade);
            return (
              <View key={upgrade.id} style={styles.card}>
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
                    status === 'owned'   && styles.buyBtnOwned,
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
          })}
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
  warning: {
    color: '#ff2d78',
    fontSize: 11,
    fontStyle: 'italic',
    letterSpacing: 1,
    paddingHorizontal: 20,
    paddingTop: 6,
    paddingBottom: 12,
  },
  list: {
    paddingHorizontal: 16,
    gap: 10,
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
  cardText: {
    flex: 1,
    gap: 2,
  },
  cardName: {
    color: '#e2e8f0',
    fontSize: 14,
    fontWeight: '800',
    letterSpacing: 1,
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
    minWidth: 68,
    alignItems: 'center',
  },
  buyBtnOwned: {
    backgroundColor: 'rgba(148,163,184,0.25)',
  },
  buyBtnDisabled: {
    backgroundColor: 'rgba(168,85,247,0.2)',
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
