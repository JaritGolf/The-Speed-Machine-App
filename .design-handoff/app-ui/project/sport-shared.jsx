// Shared building blocks for all Sport (B) variants.
// - useEdgeFlash: triggers a brief screen-edge color flash whenever lastPutt
//   identity changes; the flash fades back to the steady state.
// - SportEdgeFlash: full-bleed border overlay that does the flash + steady glow.
// - SportEndButton: shared dramatic end-session button.
// - SportRecHeader: shared top header (REC dot + drill).
// - sportTokens: shared dark theme.

const sportTokens = (dark = true) => ({
  bg: dark ? '#08090C' : '#FAFAF7',
  surface: dark ? '#13151A' : '#FFFFFF',
  inset: dark ? '#0E1014' : '#F1F1EE',
  fg: dark ? '#FFFFFF' : '#08090C',
  sub: dark ? 'rgba(255,255,255,0.50)' : 'rgba(0,0,0,0.50)',
  dim: dark ? 'rgba(255,255,255,0.30)' : 'rgba(0,0,0,0.30)',
  subtle: dark ? 'rgba(255,255,255,0.10)' : 'rgba(0,0,0,0.08)',
  hairline: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)',
  zone: '#22C55E',
  miss: '#EF4444',
  display: '"Oswald", "Helvetica Neue", sans-serif'
});

// Trigger a flash whenever the lastPutt value changes.
// Returns { flashing, flashColor } — flashing is true for ~600ms.
function useEdgeFlash(lastPutt, inZone, zone, miss) {
  const [flash, setFlash] = React.useState({ on: false, color: null });
  const prev = React.useRef(lastPutt);
  React.useEffect(() => {
    if (lastPutt == null) {
      prev.current = lastPutt;
      return;
    }
    if (prev.current !== lastPutt) {
      const color = inZone ? zone : miss;
      setFlash({ on: true, color });
      const t = setTimeout(() => setFlash((f) => ({ ...f, on: false })), 700);
      prev.current = lastPutt;
      return () => clearTimeout(t);
    }
  }, [lastPutt, inZone, zone, miss]);
  return flash;
}

// Full-bleed edge flash overlay. Sits absolute over the device.
// Renders a soft inset glow that pulses in and fades out.
function SportEdgeFlash({ flash }) {
  const { on, color } = flash;
  if (!color) return null;
  return (
    <div
      key={on ? 'on' : 'off'}
      style={{
        position: 'absolute', inset: 0, pointerEvents: 'none', zIndex: 100,
        borderRadius: 'inherit',
        boxShadow: on ?
        `inset 0 0 0 6px ${color}, inset 0 0 80px ${color}aa, inset 0 0 200px ${color}66` :
        `inset 0 0 0 0px ${color}00`,
        transition: on ? 'box-shadow 60ms ease-out' : 'box-shadow 600ms ease-out',
        opacity: on ? 1 : 0
      }} />);


}

function SportEndButton({ tokens, label = 'END SESSION' }) {
  return (
    <button style={{
      width: '100%',
      background: 'transparent',
      border: `1.5px solid ${tokens.miss}55`,
      color: tokens.miss,
      fontSize: 13, fontWeight: 700, letterSpacing: '0.20em',
      padding: '14px', borderRadius: 12,
      fontFamily: 'inherit', textTransform: 'uppercase',
      cursor: 'pointer'
    }}>{label}</button>);

}

function SportRecHeader({ s, tokens, compact = false }) {
  return (
    <div style={{ ...{
        padding: compact ? '6px 16px 8px' : '8px 18px 10px',
        display: 'flex', alignItems: 'center', gap: 10, height: "45px"
      }, padding: "8px 18px 0px" }}>
      <div style={{
        borderRadius: 8, background: tokens.miss,
        boxShadow: `0 0 0 4px ${tokens.miss}30`,
        animation: 'sportPulse 1.6s ease-in-out infinite', width: "16px", height: "15px"
      }} />
      <div style={{ ...{
          fontFamily: tokens.display,
          fontSize: compact ? 12 : 14, fontWeight: 600, letterSpacing: '0.14em',
          textTransform: 'uppercase'
        }, fontSize: "18px" }}>DAY {s.day} / BLOCK {s.block}</div>
      <div style={{ flex: 1 }} />
      <div style={{ color: tokens.sub, fontWeight: 500, fontSize: "19px" }}>{s.drillName}</div>
    </div>);

}

// Animation keyframes — injected once.
if (typeof document !== 'undefined' && !document.getElementById('sport-anim')) {
  const st = document.createElement('style');
  st.id = 'sport-anim';
  st.textContent = `
    @keyframes sportPulse { 0%,100% { opacity: 1 } 50% { opacity: 0.4 } }
    @keyframes sportPopIn { 0% { transform: scale(0.85); opacity: 0 } 60% { transform: scale(1.04); opacity: 1 } 100% { transform: scale(1); opacity: 1 } }
    @keyframes sportSlideUp { 0% { transform: translateY(8px); opacity: 0 } 100% { transform: translateY(0); opacity: 1 } }
  `;
  document.head.appendChild(st);
}

Object.assign(window, {
  sportTokens, useEdgeFlash, SportEdgeFlash, SportEndButton, SportRecHeader
});