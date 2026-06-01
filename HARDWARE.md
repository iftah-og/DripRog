# Hardware

## Core components

- **Raspberry Pi 3A+** (any 64-bit Pi with the same GPIO header should work)
- **HiFiBerry DAC+ ADC Pro** (records `hw:0,0`, 192 kHz / 24-bit stereo)
- **USB drive**, formatted **FAT32**, mounted at `/mnt/usb` (recordings go to `/mnt/usb/recordings`)
- Momentary push button
- One status indicator (see below)
- 4-position rotary gain switch

A recording needs ~2.1 GB free per segment, so size the USB drive for your session length (24 h at these settings is large — use a high-capacity drive).

### USB drive

Recordings are written continuously, so drive quality matters — a slow or
flaky drive can cause dropouts or stalls. Use a high-quality drive. Tested and
recommended:

- **Samsung FIT Plus**
- **SanDisk Ultra Fit**

Both are compact, fast, and reliable for sustained writing. Format as **FAT32**.

## Microphones

DripRog is designed around **electret capsules** fed by the ADC's plug-in
power. The capsule choice is yours; these are the ones the project is built and
tested around:

- **Primo EM272** — low-self-noise omni, a long-standing favourite for quiet
  nature and ambient field recording.
- **Primo EM419N** — the successor to the EM258, with slightly higher max SPL
  and SNR. Notably, it keeps a **useful ultrasonic response** (the EM258/EM419
  line reaches well above 20 kHz, into the tens of kHz), which makes the EM419N
  particularly handy for **ultrasound** work (bats, insects, high-frequency
  detail) at the recorder's 192 kHz sample rate.
- **PUI Audio capsules** — modern WM-61A-style electrets that are cheap and
  high quality; a good low-cost option.

Any standard 2-terminal electret capsule will work — these are just known-good
picks. For stereo, wire two capsules to the ADC's left and right inputs.

### Plug-in power — jumper required

Electret capsules need a DC bias ("plug-in power") to run. The HiFiBerry DAC+
ADC Pro can supply this, but **it is not enabled by default — you must set the
plug-in-power jumper on the board** for the ADC inputs you're using. Without the
jumper the capsule gets no bias and you'll record only noise/silence.

Set the jumper(s), then wire each capsule between the ADC input and ground per
the HiFiBerry DAC+ ADC Pro documentation. Confirm the capsule is biased (a
quick test recording should show real signal, not just noise floor) before
deploying.

## GPIO connections

All inputs are active-low with the internal pull-up enabled in software; wire each one to **GND** through the button/switch.

| Function | GPIO (BCM) | Notes |
|---|---|---|
| Record button | 17 | Momentary, to GND |
| Status indicator | 23 | LED / piezo / motor — see below |
| Gain select (24) | 12 | To GND |
| Gain select (60) | 5 | To GND |
| Gain select (80) | 6 | To GND |
| Gain default (104) | — | No gain pin to GND |

The "gain" values are the ADC capture level passed to the `ADC` mixer control (0–104, i.e. 0–40 dB).

## Status indicator on GPIO 23

GPIO 23 is a simple on/off output. You can fit **one** of three indicators, and
the firmware drives all of them identically (pin high = on) using the same
patterns. This is the project's main accessibility feature: choose feedback by
sight, sound, or touch — whichever suits you — without changing anything in
software.

- **LED** — visual.
- **Active piezo buzzer** — audible.
- **Coin vibration motor** — tactile / silent.

All three respond to the same patterns (see [Indicator patterns](#indicator-patterns)),
so the device behaves identically regardless of which you fit. Pick based on
whether you want to see, hear, or feel the status.

### Option A — LED (visual)

Most common. LED in series with a current-limiting resistor to GND.

- **220–330 Ω** series resistor for a standard LED at 3.3 V.
- Long leg (anode) toward GPIO 23, short leg (cathode) toward the resistor/GND.

### Option B — Active piezo buzzer (audible, kept quiet)

Use an **active** piezo (built-in oscillator — runs on DC, not a passive
element). Driven straight from GPIO 23, an active piezo is loud, so add a
**series resistor to reduce the volume**:

- Start around **4.7 kΩ** for a quiet chirp.
- Increase toward **10 kΩ or more** to make it quieter still — higher resistance
  = lower volume. Tune to taste.
- Polarity matters: `+` toward GPIO 23, `–` toward the resistor/GND.

This keeps the same blink patterns as the LED, just audible instead of visual.

### Option C — Coin vibration motor (silent / tactile)

A coin (ERM) vibration motor gives feedback you can feel without light or sound
— good for fully covert deployment.

**Do not connect the motor directly to GPIO 23.** A coin motor draws roughly
75–100 mA, far above the Pi's ~16 mA per-pin limit, and the inductive kickback
can damage the pin. Use a small transistor driver:

- **N-channel MOSFET** (e.g. 2N7000) or **NPN transistor** (e.g. BC337 / 2N2222)
  switching the motor's low side.
- **~1 kΩ** resistor from GPIO 23 to the gate/base.
- **Flyback diode** (e.g. 1N4148 or 1N4001) across the motor terminals,
  cathode to the positive supply, to absorb the inductive spike.
- Power the motor from the **3.3 V or 5 V rail**, not from GPIO 23.

The motor then follows the same on/off patterns as the LED.

## Indicator patterns

| Pattern | Meaning |
|---|---|
| One blink at startup | Power-on self-test |
| Solid on | Ready (USB mounted, space available) |
| 2 blinks, pause, repeat | Waiting for USB / not enough space |
| 5 blinks then off | Recording started (off = recording) |
| On after a 1 s hold while recording | Stop is being confirmed |
| 8 fast blinks then solid | Recording stopped and synced |
| 10 fast blinks | Shutting down |

## Controls

- **Short press** (< ~0.8 s): start recording.
- **Long press** (≥ ~0.8 s) while recording: stop recording.
- **Hold 5 s**: clean shutdown (safe to remove power afterward).

## Gain switch

A 4-position rotary switch sets the ADC capture level. By position (1 = lowest
gain, 4 = maximum):

| Position | ADC level | Wiring |
|---|---|---|
| 1 | 24 | GPIO 12 to GND |
| 2 | 60 | GPIO 5 to GND |
| 3 | 80 | GPIO 6 to GND |
| 4 | 104 (max) | no pin to GND |

The level is read at idle and locked in when a recording starts. Position 4
(max) is the "nothing connected" state, so if the switch is unwired or
disconnected the recorder defaults to maximum gain — it still runs, just always
at 104.

### A note on setting gain for unattended recording

Setting a gain level ahead of an overnight or multi-day recording is inherently
a guess — you don't know in advance how loud the environment will be, and you
won't be there to adjust it. So in practice there isn't a "correct" gain to
dial in for an unattended session.

The switch is here anyway, because sometimes you do know something about the
site (e.g. you're deploying somewhere reliably very loud). Unless you have a
specific reason, **set the switch to position 3 (level 80)** as a sensible
default, and only choose a lower position if you know you'll be in an unusually
loud environment.

## Power

The Pi is powered over its micro-USB input, so any good USB power bank works.
Use a **high-quality battery** — cheap packs can sag or cut out under the Pi's
load and interrupt a recording. **Anker** packs are a known-good choice.

As a rough guide, a **10 Ah** battery gives around **24 hours** of recording
time on a Pi 3A+ with this setup. Scale capacity to the session length you
need. Because the root filesystem is read-only, the battery simply dying mid-
session is safe — you only lose the segment that was being written.
