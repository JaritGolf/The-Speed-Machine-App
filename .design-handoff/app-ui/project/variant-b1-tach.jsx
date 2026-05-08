// B1 — Tach (refined original Sport).
// Tach bars across top, big target, live readout overlay, edge flash, End Session.
// This is the closest descendant of the original B.

function VariantSportTach({ session, dark = true }) {
  const s = deriveSessionState(session);
  const T = sportTokens(dark);
  const isReady = s.lastPutt == null;
  const liveColor = isReady ? T.sub : s.lastInZone ? T.zone : T.miss;
  const flash = useEdgeFlash(s.lastPutt, s.lastInZone, T.zone, T.miss);

  // Hero card tint fades from full → transparent over 2s on each new putt.
  // Restart the animation by re-keying the tint overlay whenever lastPutt changes.
  const tintColor = isReady ? null : s.lastInZone ? 'rgba(34,197,94,0.28)' : 'rgba(239,68,68,0.28)';
  const heroBorder = isReady ? T.subtle : liveColor;

  return (
    <div style={{
      width: '100%', height: '100%', background: T.bg, color: T.fg,
      paddingTop: 54, paddingBottom: 34, position: 'relative',
      fontFamily: '-apple-system, "SF Pro Text", system-ui, sans-serif',
      WebkitFontSmoothing: 'antialiased',
      display: 'flex', flexDirection: 'column'
    }}>
      <SportEdgeFlash flash={flash} />
      <SportRecHeader s={s} tokens={T} />

      {/* Pass progress strip */}
      <div style={{ padding: '6px 18px 12px', borderBottom: `1px solid ${T.subtle}`, textAlign: "center" }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 8, textAlign: "center" }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: T.display, color: T.sub, textAlign: 'center', fontWeight: 700, letterSpacing: '5px', fontSize: 27, lineHeight: 1.1, whiteSpace: 'pre-line' }}>{'PUTTS\nLEFT'}</div>
            <div style={{ fontFamily: T.display, fontSize: 124, fontWeight: 700, lineHeight: 1,
              letterSpacing: '-0.02em', fontVariantNumeric: 'tabular-nums', color: T.fg, marginTop: 4, textAlign: 'center'
            }}>{Math.max(0, s.totalPutts - (s.history?.length || 0))}</div>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: T.display, color: T.sub, textAlign: 'center', fontWeight: 700, letterSpacing: '3.2px', fontSize: 27, lineHeight: 1.1, whiteSpace: 'pre-line' }}>{'PUTTS\nNEEDED'}</div>
            <div style={{ fontFamily: T.display, fontWeight: 700, lineHeight: 1,
              fontVariantNumeric: 'tabular-nums', marginTop: 4, fontSize: 124, textAlign: 'center', letterSpacing: '-0.02em', color: T.fg
            }}>{Math.max(0, s.passThreshold - s.inZone)}</div>
          </div>
        </div>
        <TachBars history={s.history} total={s.totalPutts} target={s.target}
        tolerance={s.tolerance} T={T} />
        <div style={{ height: 4 }} />
        <PassNeededBars total={s.passThreshold} inZone={s.inZone} totalPutts={s.totalPutts} T={T} />
      </div>

      {/* Hero */}
      <div style={{ flex: 1, padding: '14px 16px 10px', display: 'flex', flexDirection: 'column', gap: 12, minHeight: 0 }}>
        <div style={{
          flex: 1, background: T.surface, borderRadius: 24,
          border: `2px solid ${heroBorder}`,
          outline: '4px solid #000', outlineOffset: '4px',
          padding: '18px 20px',
          position: 'relative', overflow: 'hidden',
          display: 'flex', flexDirection: 'column',
          transition: 'border-color 0.25s, background 0.25s'
        }}>
          {tintColor &&
          <div
            key={`${s.lastPutt}-${s.lastInZone}-${s.history?.length || 0}`}
            style={{
              position: 'absolute', inset: 0, background: tintColor,
              animation: 'b1-tint-fade 2s ease-out forwards',
              pointerEvents: 'none', zIndex: 0
            }} />

          }
          <style>{`
            @keyframes b1-tint-fade {
              0% { opacity: 1; }
              100% { opacity: 0; }
            }
          `}</style>
          <div style={{ position: 'relative', zIndex: 1, display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div />
            <CornerStat label="HIT RATE" value={`${s.hitRate}%`} T={T} color={T.zone} align="right" />
          </div>
          <div style={{ position: 'absolute', left: 16, top: '50%', transform: 'translateY(-50%)', marginTop: -77, overflow: 'visible', zIndex: 1 }}>
            <Ladder s={s} T={T} pxHeight={300} />
          </div>
          <div style={{
            position: 'absolute', top: 0, bottom: 0,
            left: 84, right: 0,
            paddingRight: 20,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            zIndex: 1, pointerEvents: 'none',
          }}>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 24 }}>
              <div style={{
                fontFamily: T.display,
                fontSize: !isReady && fmtMph(s.lastPutt).length >= 4 ? 150 : 200,
                fontWeight: 700, lineHeight: 0.78,
                letterSpacing: '-0.05em', fontVariantNumeric: 'tabular-nums',
                color: isReady ? T.sub : T.fg, textAlign: 'center'
              }}>{isReady ? '— —' : fmtMph(s.lastPutt)}</div>
              <div style={{
                fontSize: 22, fontWeight: 700, letterSpacing: '0.18em', color: T.sub
              }}>MPH</div>
            </div>
          </div>
          <div style={{ flex: 1 }} />
          <div style={{ position: 'relative', zIndex: 1 }}>
            <LiveReadout s={s} T={T} isReady={isReady} liveColor={liveColor} dark={dark} />
          </div>
        </div>
        <SportEndButton tokens={T} />
      </div>
    </div>);

}

function CornerStat({ label, value, T, color, align = 'left' }) {
  return (
    <div style={{ textAlign: align }}>
      <div style={{ fontWeight: 700, letterSpacing: '0.18em', color: T.sub, fontFamily: "Arial", fontSize: "20px" }}>{label}</div>
      <div style={{
        fontFamily: T.display, fontWeight: 600, lineHeight: 1,
        fontVariantNumeric: 'tabular-nums', marginTop: 4, color: color || T.fg, fontSize: "37px"
      }}>{value}</div>
    </div>);

}

function LiveReadout({ s, T, isReady, liveColor, dark }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',

      background: dark ? 'rgba(0,0,0,0.30)' : 'rgba(255,255,255,0.55)',
      backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)',
      borderRadius: 14, border: `1px solid ${T.subtle}`, padding: "0px 16px", height: "131px"
    }}>
      <div>
        <div style={{
          fontWeight: 800, letterSpacing: '0.18em',
          color: T.sub, fontSize: "17px"
        }}>TARGET SPEED</div>
        <div style={{
          fontFamily: T.display, fontWeight: 600, lineHeight: 1,
          fontVariantNumeric: 'tabular-nums', color: T.fg, marginTop: 4, fontSize: "62px"
        }}>
          {Number.isInteger(s.target) ? s.target : fmtMph(s.target)}
          <span style={{
            color: T.sub, marginLeft: 6, fontWeight: 600, letterSpacing: "1.5px", fontSize: "30px"
          }}>MPH</span>
        </div>
      </div>
      {!isReady &&
      <div key={s.lastPutt} style={{
        borderRadius: 8,
        background: liveColor + '22', color: liveColor,
        fontFamily: T.display, fontWeight: 600,
        fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.01em',
        animation: 'sportPopIn 0.4s ease-out', padding: "0px 12px 11px", fontSize: "65px"
      }}>{fmtDelta(s.lastDelta)}</div>
      }
    </div>);

}

function TachBars({ history, total, target, tolerance, T }) {
  const min = target - tolerance,max = target + tolerance;
  const visMax = 2.5;
  return (
    <div style={{ display: 'flex', gap: 2, alignItems: 'flex-end' }}>
      {Array.from({ length: total }).map((_, i) => {
        const p = history[i];
        let h = 4,color = T.subtle;
        if (p) {
          const dev = Math.max(-visMax, Math.min(visMax, p.mph - target));
          h = 30 + Math.abs(dev) / visMax * 70;
          color = p.mph >= min && p.mph <= max ? T.zone : T.miss;
        }
        return (
          <div key={i} style={{ flex: 1, height: 20, display: 'flex', alignItems: 'flex-end' }}>
            <div style={{ ...{ width: '100%', height: `${h}%`, background: color, borderRadius: 1.5 }, height: "20px" }} />
          </div>);

      })}
    </div>);

}

function PassNeededBars({ total, inZone, totalPutts, T }) {
  // Mirror the made-putts tach: same per-bar width as that tach (which spans
  // totalPutts segments across full width). We render `total` bars right-aligned.
  return (
    <div style={{ display: 'flex', gap: 2, alignItems: 'flex-end', justifyContent: 'flex-end' }}>
      {Array.from({ length: total }).map((_, i) => {
        // Bar at index i is "depleted" if a corresponding in-zone putt has been made.
        // Mirror means: deplete from the LEFT — remaining bars hug the right edge.
        const depleted = i < inZone;
        return (
          <div key={i} style={{ flex: `0 0 calc((100% - ${(totalPutts - 1) * 2}px) / ${totalPutts})`, height: 20, display: 'flex', alignItems: 'flex-end' }}>
            <div style={{
              width: '100%', height: 20,
              background: depleted ? T.subtle : T.zone,
              opacity: depleted ? 0.35 : 1,
              borderRadius: 1.5,
              transform: depleted ? 'scaleY(0.2)' : 'scaleY(1)',
              transformOrigin: 'bottom',
              transition: 'transform 0.3s ease, opacity 0.3s ease, background 0.3s ease'
            }} />
          </div>);
      })}
    </div>);
}

Object.assign(window, { VariantSportTach, TachBars, PassNeededBars, CornerStat, LiveReadout });