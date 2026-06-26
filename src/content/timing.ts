// ── Shared coin-flow timing ──────────────────────────────────────────────────
// Lucidity coins pour out of the bottom cash tray and stream up to the goal bar.
// The displayed Lucidity counter + the TV objective bar must NOT start climbing
// while coins are still only leaving the tray — they wait until the FIRST coin
// reaches the bar. These constants are the single source of truth so CoinFlow's
// flight and the counter/bar gate (useAnimatedLucidity) stay in sync.
export const COIN_FLIGHT_MS = 720;   // per coin: burst out of the tray + collect to the bar
export const COIN_STAGGER_MS = 90;   // gap between coins pouring out

// The first coin reaches the goal bar this long after a Lucidity gain settles
// (the coins launch immediately on settle and the first one flies for COIN_FLIGHT_MS).
// The counter/bar defer their climb by this much so they start with coin ARRIVAL,
// not with the launch. Also serves as the fallback delay if the coin animation is
// ever skipped, so the counter still reconciles to the real total shortly after.
export const COIN_FIRST_ARRIVAL_MS = COIN_FLIGHT_MS;
