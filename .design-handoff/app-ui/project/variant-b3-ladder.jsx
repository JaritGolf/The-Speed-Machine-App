// B3 — Ladder
// Vertical tolerance ladder beside target number. Last-5 putts as MPH chips
// (recency-focused). Compact density. Big edge flash on putt.

function VariantSportLadder({ session, dark = true }) {
  const s = deriveSessionState(session);
  const T = sportTokens(dark);
  const isReady = s.lastPutt == null;
  const liveColor = isReady ? T.sub : (s.lastInZone ? T.zone : T.miss);
  const flash = useEdgeFlash(s.lastPutt, s.lastInZone, T.zone, T.miss);

  // Last 5 putts (most-recent first)
  const last5 = s.history.slice(-5).reverse();

  return (
    <div style={{
      width: '100%', height: '100%', background: T.bg, color: T.fg,
      paddingTop: 54, paddingBottom: 34, position: 'relative',
      fontFamily: '-apple-system, "SF Pro Text", system-ui, sans-serif',
      WebkitFontSmoothing: 'antialiased',
      display: 'flex', flexDirection: 'column',
    }}>
      <SportEdgeFlash flash={flash} />
      <SportRecHeader s={s} tokens={T} />

      {/* Stat row: in zone | hit rate | to pass */}
      <div style={{
        display: 'grid', gridTemplateColumns: '1fr 1fr 1fr',
        borderTop: `1px solid ${T.subtle}`, borderBottom: `1px solid ${T.subtle}`,
      }}>
        <StatCell label="IN ZONE" value={`${s.inZone}/${s.totalPutts}`} color={T.zone} T={T} />
        <StatCell label="HIT RATE" value={`${s.hitRate}%`} T={T} divided />
        <StatCell label="TO PASS" value={Math.max(0, s.passThreshold - s.inZone)} T={T} divided />
      </div>

      {/* Hero — target with ladder beside */}
      <div style={{
        flex: 1, padding: '20px 16px 12px',
        display: 'flex', flexDirection: 'column', gap: 14, minHeight: 0,
      }}>
        <div style={{
          flex: 1, display: 'flex', alignItems: 'center', gap: 6,
        }}>
          <Ladder s={s} T={T} />
          <div style={{ flex: 1, textAlign: 'center', position: 'relative' }}>
            <div style={{
              fontFamily: T.display, fontSize: 11, fontWeight: 700,
              letterSpacing: '0.24em', color: T.sub, marginBottom: -8,
            }}>TARGET</div>
            <div style={{
              fontFamily: T.display, fontSize: 240, fontWeight: 700, lineHeight: 0.85,
              letterSpacing: '-0.05em', fontVariantNumeric: 'tabular-nums',
            }}>{s.target}</div>
            <div style={{
              fontFamily: T.display, fontSize: 18, fontWeight: 700,
              letterSpacing: '0.20em', color: T.sub, marginTop: -10,
            }}>MPH</div>
            <div style={{
              fontSize: 12, color: T.sub, marginTop: 6,
              fontVariantNumeric: 'tabular-nums',
            }}>
              zone {fmtMph(s.min)} – {fmtMph(s.max)}
            </div>
          </div>
        </div>

        {/* Last 5 chips */}
        <div>
          <div style={{
            fontFamily: T.display, fontSize: 10, fontWeight: 700,
            letterSpacing: '0.20em', color: T.sub, marginBottom: 6,
            display: 'flex', justifyContent: 'space-between',
          }}>
            <span>LAST 5 PUTTS</span>
            <span>NEWEST →</span>
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            {Array.from({ length: 5 }).map((_, i) => {
              const p = last5[4 - i];
              if (!p) {
                return (
                  <div key={i} style={{
                    flex: 1, height: 48, borderRadius: 8,
                    border: `1px dashed ${T.subtle}`,
                  }} />
                );
              }
              const inZ = p.mph >= s.min && p.mph <= s.max;
              const c = inZ ? T.zone : T.miss;
              return (
                <div key={i} style={{
                  flex: 1, height: 48, borderRadius: 8,
                  background: c + '18', border: `1px solid ${c}66`,
                  display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                }}>
                  <div style={{
                    fontFamily: T.display, fontSize: 18, fontWeight: 600,
                    color: c, fontVariantNumeric: 'tabular-nums', lineHeight: 1,
                  }}>{fmtMph(p.mph)}</div>
                  <div style={{
                    fontSize: 9, fontWeight: 700, color: c, opacity: 0.8,
                    letterSpacing: '0.10em', marginTop: 2,
                    fontVariantNumeric: 'tabular-nums',
                  }}>{fmtDelta(p.mph - s.target)}</div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Live readout */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '14px 18px',
          background: T.surface, borderRadius: 14,
          border: `1.5px solid ${isReady ? T.subtle : liveColor}`,
          transition: 'border-color 0.25s',
        }}>
          <div>
            <div style={{
              fontSize: 10, fontWeight: 800, letterSpacing: '0.18em',
              color: isReady ? T.sub : liveColor,
            }}>
              {isReady ? 'AWAITING NEXT PUTT' : (s.lastInZone ? 'IN ZONE' : 'OUT OF ZONE')}
            </div>
            <div style={{
              fontFamily: T.display, fontSize: 32, fontWeight: 600, lineHeight: 1,
              fontVariantNumeric: 'tabular-nums', color: isReady ? T.sub : T.fg, marginTop: 4,
            }}>
              {isReady ? '— —' : `${fmtMph(s.lastPutt)}`}
              {!isReady && <span style={{ fontSize: 12, color: T.sub, marginLeft: 6, letterSpacing: '0.10em', fontWeight: 600 }}>MPH</span>}
            </div>
          </div>
          {!isReady && (
            <div key={s.lastPutt} style={{
              padding: '6px 12px', borderRadius: 8,
              background: liveColor + '22', color: liveColor,
              fontFamily: T.display, fontSize: 22, fontWeight: 600,
              fontVariantNumeric: 'tabular-nums',
              animation: 'sportPopIn 0.4s ease-out',
            }}>{fmtDelta(s.lastDelta)}</div>
          )}
        </div>

        <SportEndButton tokens={T} />
      </div>
    </div>
  );
}

function StatCell({ label, value, color, T, divided }) {
  return (
    <div style={{
      padding: '10px 14px',
      borderLeft: divided ? `1px solid ${T.subtle}` : 'none',
    }}>
      <div style={{ fontSize: 9, fontWeight: 700, letterSpacing: '0.20em', color: T.sub }}>{label}</div>
      <div style={{
        fontFamily: T.display, fontSize: 24, fontWeight: 600, lineHeight: 1,
        marginTop: 4, color: color || T.fg, fontVariantNumeric: 'tabular-nums',
      }}>{value}</div>
    </div>
  );
}

function Ladder({ s, T, pxHeight = 360 }) {
  // Vertical scale: target ± 2.5
  const range = 2.5;
  const min = s.target - range, max = s.target + range;
  const yFor = (mph) => ((max - mph) / (max - min)) * pxHeight;
  const tolMin = s.target - s.tolerance, tolMax = s.target + s.tolerance;

  // Tick rows for whole-number speeds
  const ticks = [];
  for (let mph = Math.ceil(min); mph <= Math.floor(max); mph++) {
    ticks.push(mph);
  }

  const lastY = s.lastPutt != null
    ? yFor(Math.max(min, Math.min(max, s.lastPutt))) : null;
  const lastInZ = s.lastInZone;

  return (
    <div style={{
      width: 60, height: pxHeight, position: 'relative',
      flexShrink: 0,
    }}>
      {/* Track */}
      <div style={{
        position: 'absolute', left: 22, top: 0, bottom: 0,
        width: 2, background: T.subtle, borderRadius: 1,
      }} />
      {/* Tolerance band */}
      <div style={{
        position: 'absolute', left: 16, width: 14,
        top: yFor(tolMax), height: yFor(tolMin) - yFor(tolMax),
        background: T.zone + '33',
        border: `1.5px solid ${T.zone}`,
        borderRadius: 4,
      }} />
      {/* Ticks */}
      {ticks.map(mph => (
        <div key={mph} style={{
          position: 'absolute', left: 0, right: 0,
          top: yFor(mph) - 8, height: 16,
          display: 'flex', alignItems: 'center',
        }}>
          <div style={{
            width: 30, textAlign: 'right', paddingRight: 6,
            fontFamily: T.display, fontSize: 12, fontWeight: 500,
            color: mph === s.target ? T.fg : T.sub,
            fontVariantNumeric: 'tabular-nums',
          }}>{mph}</div>
          <div style={{
            width: mph === s.target ? 14 : 8, height: mph === s.target ? 2 : 1,
            background: mph === s.target ? T.fg : T.dim,
          }} />
        </div>
      ))}
      {/* Last putt indicator */}
      {lastY != null && (() => {
        const isExact = Math.abs(s.lastPutt - s.target) < 0.05;
        return (
          <div style={{
            position: 'absolute', left: 8, right: -4, top: lastY - 10, height: 20,
            display: 'flex', alignItems: 'center', justifyContent: 'flex-end',
          }}>
            {isExact ? (
              <svg width="20" height="20" viewBox="0 0 24 24" fill="#FFC107" style={{ filter: 'drop-shadow(0 0 4px #FFC10799)' }}>
                <path d="M12 2l2.6 7.4H22l-6 4.6 2.4 7.6L12 17l-6.4 4.6L8 14 2 9.4h7.4z" />
              </svg>
            ) : (
              <div style={{
                width: 0, height: 0,
                borderTop: '7px solid transparent',
                borderBottom: '7px solid transparent',
                borderRight: `9px solid #000`,
              }} />
            )}
          </div>
        );
      })()}
    </div>
  );
}

Object.assign(window, { VariantSportLadder });
