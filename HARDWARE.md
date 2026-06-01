# Hardware

## Core components

- **Raspberry Pi 3A+** (any 64-bit Pi with the same GPIO header should work)
- **HiFiBerry DAC+ ADC Pro** (records `hw:0,0`, 192 kHz / 24-bit stereo)
- **USB drive**, formatted **FAT32**, mounted at `/mnt/usb` (recordings go to `/mnt/usb/recordings`)
- Momentary push button
- One status indicator (see below)
- Optional 4-position rotary gain switch

A recording needs ~2.1 GB free per segment, so size the USB drive for your session length (24 h at these settings is large — use a high-capacity drive).

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

GPIO 23 is a simple on/off output. You can fit **one** of three indicators; the
firmware drives all of them identically (pin high = on). Pick based on whether
you want visual, audible, or silent/tactile feedback.

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

## Gain switch (optional)

A 4-position rotary switch connecting one of GPIO 12 / 5 / 6 to GND selects ADC
level 24 / 60 / 80; with none connected the level is 104 (max). The level is
read at idle and locked in when a recording starts.
