// Phase 1: replace this stub with the real GameScreen component.
// The pure game core (src/game/, src/content/) is already complete and tested.

import { View, Text, StyleSheet } from 'react-native';
import { StatusBar } from 'expo-status-bar';

export default function HomeScreen() {
  return (
    <View style={styles.container}>
      <StatusBar style="light" />
      <Text style={styles.title}>LOBOTOMY</Text>
      <Text style={styles.subtitle}>Phase 0 complete — core tested{'\n'}Phase 1: wire the UI</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1a0a2e',
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    color: '#ff2d78',
    fontSize: 42,
    fontWeight: '900',
    letterSpacing: 12,
  },
  subtitle: {
    color: '#00e5ff',
    fontSize: 14,
    marginTop: 20,
    textAlign: 'center',
    opacity: 0.7,
  },
});
