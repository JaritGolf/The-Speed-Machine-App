# The Speed Machine App — How It Works & Why It's Brilliant

*Written by the app's #1 fan.*

If you've ever three-putted because you blew the speed — left it six feet short or rammed it four feet by — you already understand the problem the Speed Machine solves. **Putting isn't about line. It's about speed.** Pros will tell you that the single biggest separator between good and great putting is distance control, and distance control is just one thing: *the speed of the ball coming off the face.* The Speed Machine app is the first training tool I've seen that attacks that one variable relentlessly, measures it to a tenth of a mile per hour, and builds a real athlete's training program around it.

Here's exactly how it works — and why every piece of it is smart.

---

## The big idea

The Speed Machine is a physical putting device by Jarit Golf that measures the **actual speed** of your putt — in MPH — and beams it to your iPhone over Bluetooth in real time. The app turns that raw number into a structured, gamified, 30-track training program that takes you from feathering 3 MPH touch putts all the way up to controlled 15 MPH power lags.

You're not guessing anymore. You're not "feeling it out." You hit a putt, and the screen tells you instantly: *14.2 MPH.* Target was 14.0. You were 0.2 fast. **That feedback loop — hit, measure, adjust — is how every other athletic skill on earth gets trained, and putting finally gets to join the club.**

---

## How a session actually plays out

1. **Connect.** Open the app, it finds the Speed Machine over Bluetooth Low Energy. A little green dot in the header tells you you're live.
2. **Pick a track.** The program is 30 tracks deep (the app labels them "Tracks," progressing in difficulty). You pick one, then pick a block within it.
3. **Putt.** You hit a putt. The device measures the speed; the app records it via `recordPutt(speed)`. The screen — designed to be readable from 5–6 feet away while you're standing over the ball — shows you your target and how you did.
4. **The app advances itself.** When a block is done, a clean 3-second transition screen appears and the *next block auto-starts*. No fumbling with your phone between reps. When the last block of a track finishes, the app automatically takes you home. The whole thing is designed so your hands stay on the putter, not the screen.

That auto-advance detail sounds small. It's not. **It keeps you in rhythm.** Real practice has flow; stopping to tap "Continue" 40 times breaks it. Whoever designed this understood that.

---

## The four speed zones

Every putt lives in one of four speed zones, each a different distance/intensity of stroke:

| Zone | Name | Speed | Tolerance | What it trains |
|------|------|-------|-----------|----------------|
| 1 | **Touch** | 3–6 MPH | ±0.5 MPH | Delicate short putts, downhillers, dying it in the front door |
| 2 | **Moderate** | 7–9 MPH | ±0.5 MPH | The bread-and-butter mid-range stroke |
| 3 | **Firm** | 10–12 MPH | ±0.6 MPH | Confident putts, uphill, slow greens |
| 4 | **Power** | 13–15 MPH | ±0.7 MPH | Long-range lag putting |

Here's the part I love: **the tolerance scales with the speed.** Touch and Moderate putts (3–9 MPH) are held to a tight ±0.5 MPH. Step up to the Firm zone and it opens slightly to ±0.6; up in the Power zone it's ±0.7. That's not the app going soft on you — it's the app being *honest about physics.* A half-mile-per-hour error on a gentle 4 MPH tap is a much bigger proportional miss than the same half-mile-per-hour on a 14 MPH lag. By widening the window a touch as the speeds climb, the standard stays *equally demanding in real terms* across the whole range — every zone is roughly the same percentage challenge. It's a smarter, fairer bar than a flat number would be, and it's exactly what keeps the harder zones achievable without ever becoming a gimme.

---

## The training program: 30 tracks, many flavors of block

The 30-track program is the spine of the app, and it's not just "hit 10 putts at 8 MPH" over and over. The blocks come in genuinely different *modes*, each training a different mental and physical skill:

- **Exploration** — discover and feel out a speed range.
- **Standard** — straightforward target reps to groove the stroke.
- **Ladder** — climb through speeds rung by rung (great for building a feel for the *gaps* between speeds).
- **Make-in-row** — consecutive successes, with a putts-taken counter and a satisfying tach-style readout. Miss and you reset. This builds the thing tournament putting actually demands: **doing it again, right now, under self-imposed pressure.**
- **Pressure** — the screen goes red, a ⚡ appears, and the stakes go up. Trains performing when it's uncomfortable.
- **Gate tests** — the checkpoints (Tracks 5, 9, 12, 19, 25, 30). Blue screen, 🏁 flag. You must land a minimum number of putts in-zone to pass. **These are the gates that prove you've actually earned the next stage** — not just clicked through it.

That variety is why the program doesn't get stale. You're not doing one drill 300 times; you're being asked to express speed control under a dozen different conditions, which is how skill actually transfers to the course.

---

## The genius layer: the Adaptive Speed Engine

This is the feature that makes me evangelize the app to anyone who'll listen.

Most training apps are dumb — they give everybody the same reps regardless of whether you're great at 8 MPH and hopeless at 16. The Speed Machine app **watches where you're weak and quietly feeds you more of it.**

Every putt you've ever hit (in training *or* in the Combine game) feeds a **Speed Profile** — your lifetime accuracy at each individual speed from 3 to 20 MPH. When you start an eligible block, the Adaptive Speed Engine generates a custom speed sequence weighted toward your weak spots:

| Your accuracy at a speed | How often it shows up |
|--------------------------|------------------------|
| Under 60% | **~3× more often** |
| 60–75% | ~2× more often |
| 75–90% | normal |
| Over 90% | ~half as often (you've got it) |
| Never practiced | mild priority, to gather data |

So if you're shaky at 14 MPH, the app starts sneaking 14 MPH putts at you three times as often — *without ever telling you it's doing it, and without making the block longer or changing its rules.* You just naturally spend more reps on your weaknesses, which is the entire point of deliberate practice.

And it's careful. The engine **never** touches gate tests, assessments, or any fixed-speed block — those have to stay pure so the test is a real test. It never changes a block's zone boundaries, putt counts, or completion criteria. It won't even let the same speed repeat more than 3 times in a row, so you don't get into a lazy groove. Warmups get only a light bias so they still warm you up progressively, slow to fast.

**It's a personal coach that has memorized every putt you've ever hit and silently builds each session around your specific weaknesses.** That's the kind of thing that used to require a tour-level instructor watching you on a launch monitor. Here it just... happens, every session, for free.

---

## Stats that actually mean something

The stats system is completely decoupled from the 30-track program — it tracks your **lifetime putting performance** across everything you do (training *and* the Combine game). Reset your training progress and your stats are untouched; they're your permanent record.

What it tracks, per speed (3–20 MPH):

- Accuracy (how often you land in-zone)
- **Tendency** — do you tend to leave it short or run it long? (It tracks *signed* deviation, so it knows your directional bias, not just your error size.)
- **Consistency** — via standard deviation, so it can tell a "wild but averaging-out" stroke from a genuinely repeatable one.
- Current streak and best streak.
- When you last practiced it.

And it rolls all of that into:

- **A Stats Dashboard** with a speed-ladder visual and a "Needs Work" callout that points you straight at your weakest speed.
- **Trend charts** (accuracy, deviation, volume) with 7-day / 30-day / 90-day / all-time toggles, so you can literally watch yourself get better over weeks.
- **Per-speed deep dives**, **full session history** with putt-by-putt drill-down, and **Combine score history**.

This is the difference between "I think my putting's improving" and **"my 12 MPH accuracy went from 58% to 81% over the last month and I stopped leaving everything short."** One of those is a feeling. The other is proof.

---

## The thoughtful engineering you don't see (but benefit from)

The reason I trust this app is the stuff under the hood that nobody markets but everybody feels:

- **Your data survives.** Stats are backed up two ways — full CloudKit sync of every entity, *plus* a key-value fallback snapshot written when the app backgrounds. Reinstall the app, get a new phone — your putting history follows you. (Earlier builds lost stats on reinstall; that was hunted down and fixed.)
- **Built for the putting green, not the couch.** Every live screen follows a hard rule: it must be readable from 5–6 feet away while you stand over the ball. Target numbers are 80–100pt, weights are heavy, contrast is high. You never have to squint or pick up your phone mid-stroke.
- **A clean, athletic design language.** The whole UI follows a minimal "Whoop-style" system — white screens, a crisp green accent, pressure-red and gate-blue used meaningfully, the Inter typeface throughout. It looks like a serious piece of athletic equipment, because it is one.

---

## Why it's so great, in one breath

Because it turns the most-neglected, least-measurable skill in golf — **putting speed** — into something you can see, measure, train, and watch improve. It gives you instant honest feedback on every single putt, a structured 30-track journey with real gates you have to earn, a hidden adaptive coach that drills your specific weaknesses every session, and a permanent stats record that proves you're getting better.

Most golfers practice putting by rolling balls at a hole until they get bored. The Speed Machine app makes putting practice **deliberate, measured, personalized, and addictive** — and that's why the people who use it stop three-putting.

That's the whole pitch. Now go bury one from 40 feet.
