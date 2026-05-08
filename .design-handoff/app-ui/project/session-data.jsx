// Shared session data + helpers for all 4 variations.
// Single source of truth so tweaks flow through every artboard.

const SESSION_DEFAULTS = {
  day: 16,
  block: 1,
  drillName: 'Zone Jumping',
  target: 13,            // MPH
  tolerance: 0.7,        // ± MPH (so 12.3 - 13.7)
  totalPutts: 24,
  passThreshold: 15,
  // Simulated history of putts already taken. null = not yet hit.
  // Each entry is { mph: number } — we derive in/out from tolerance.
  history: [
    { mph: 13.1 }, { mph: 12.5 }, { mph: 13.8 }, { mph: 12.9 },
    { mph: 13.4 }, { mph: 14.2 }, { mph: 13.0 }, { mph: 12.7 },
    { mph: 13.5 }, { mph: 13.2 }, { mph: 11.8 }, { mph: 13.6 },
    { mph: 13.0 }, { mph: 12.4 }, { mph: 13.3 },
  ],
  // Last putt mph (drives the live readout). null = ready, awaiting putt
  lastPutt: 13.2,
  units: 'mph',
};

// Derive metrics from a session state.
function deriveSessionState(s) {
  const min = s.target - s.tolerance;
  const max = s.target + s.tolerance;
  const inZone = s.history.filter(p => p.mph >= min && p.mph <= max).length;
  const puttsTaken = s.history.length;
  const puttsLeft = s.totalPutts - puttsTaken;
  const hitRate = puttsTaken > 0 ? Math.round((inZone / puttsTaken) * 100) : 0;
  const passRate = Math.round((s.passThreshold / s.totalPutts) * 100);
  // Last putt analysis
  const last = s.lastPutt;
  let lastInZone = null;
  let lastDelta = null;
  if (last !== null && last !== undefined) {
    lastInZone = last >= min && last <= max;
    lastDelta = last - s.target;
  }
  // Can we still pass? Need (passThreshold - inZone) hits in remaining putts
  const stillPossible = (s.passThreshold - inZone) <= puttsLeft;
  return {
    ...s,
    min, max,
    inZone, puttsTaken, puttsLeft,
    hitRate, passRate,
    lastInZone, lastDelta,
    stillPossible,
  };
}

// Format helpers
const fmtMph = (n) => n == null ? '—' : n.toFixed(1);
const fmtDelta = (d) => {
  if (d == null) return '—';
  const sign = d > 0 ? '+' : '';
  return `${sign}${d.toFixed(1)}`;
};

// Color tokens (semantic — used across variations, themed per variation)
const SEM = {
  zoneLight: '#16A34A',
  zoneDark:  '#22C55E',
  missLight: '#DC2626',
  missDark:  '#F87171',
  warnLight: '#EA580C',
  warnDark:  '#FB923C',
};

Object.assign(window, { SESSION_DEFAULTS, deriveSessionState, fmtMph, fmtDelta, SEM });
