# Hardware

DripRog is intentionally built from off-the-shelf, readily available components rather than custom or hand-built electronics. The goal is to keep the system reproducible, repairable, and easy to assemble, and accessible to anyone without prior electronics experience.
## Core components

- **Raspberry Pi 3A+** 
- **HiFiBerry DAC+ ADC Pro** (records `hw:0,0`, 192 kHz / 24-bit stereo)
- **USB drive**, formatted **FAT32**, mounted at `/mnt/usb` (recordings go to `/mnt/usb/recordings`)
- Momentary push button
- One status indicator (see below)
- 4-position rotary gain switch

A recording needs ~2.1 GB free per segment (approximately 23 min 15 s at 192 kHz / 24-bit), so the USB drive should be sized for the session length. A 24-hour recording would require approximately 130 GB of storage, so a 256 GB USB drive is recommended to provide sufficient free space and headroom for long recordings.

### USB drive

Recordings are written continuously, so drive quality matters. A slow or flaky
drive can cause dropouts or stalls, so a high-quality drive is recommended.The USB drive must be formatted as **FAT32** before use.
Tested and working well:

- **Samsung FIT Plus**
- **SanDisk Ultra Fit**

Both are compact, fast, and reliable for long recordings

### Why the Pi 3A+

The Pi 3A+ is cheap, power-efficient, and will remain in production until 2030. For a device that
sits in a field doing one job, there is no reason to use anything more powerful. The 3B and 3B+
should also work with DripRog OS, but are untested.

## Microphones

DripRog is designed around **electret capsules** fed by the ADC's plug-in
power. These are the ones the project is built and
tested around:

- **Primo EM272**: Great sounding low-self-noise omni.
- **Primo EM419N**: the successor to the EM258, with slightly higher max SPL
  and SNR. It keeps a **very useful ultrasonic response** (the EM258/EM419 line
  reaches well above 20 kHz, into the tens of kHz), which makes the EM419N
  particularly handy for **ultrasound** work.
- **PUI Audio capsules**: modern WM-61A-style electrets that are cheap and high
  quality; a good low-cost option.

Any standard 2-terminal electret capsule will work; these are just known-good
picks. For stereo, two capsules go to the ADC's left and right inputs.

### Electrical noise and mic placement

Like any active electronic device, the Pi and DAC board produce a small amount of electrical noise.
A faint periodic tone around 8 kHz is visible in a spectrogram, though it is too quiet to hear. It
is not introduced in the signal path, it is radiated as EMI and picked up by the capsules directly.
The likely cause is the kernel's periodic writeback flushing the recording to the USB drive. On the
Pi 3, SD and USB share the same bus, so each flush produces a brief burst of interference. Placing
the capsules roughly **60 cm away from the board** eliminates it.

### Plug-in power

Electret capsules need a DC bias ("plug-in power") to run. The HiFiBerry DAC+
ADC Pro can supply this, but **it is not enabled by default: the plug-in-power
jumper on the board needs to be set** for the ADC inputs you're using. Without
the jumper the capsule gets no bias, and the result is only noise or silence.

With the jumper(s) set, each capsule connects between the ADC input and ground
per the HiFiBerry DAC+ ADC Pro documentation. 

## GPIO connections

All inputs are active-low with the internal pull-up enabled in software; wire each one to **GND** through the button/switch.

| Function | GPIO (BCM) | Notes |
|---|---|---|
| Record button | 17 | Momentary, to GND |
| Status indicator | 23 | LED / piezo / motor (see below) |
| Gain select (24) | 12 | To GND |
| Gain select (60) | 5 | To GND |
| Gain select (80) | 6 | To GND |
| Gain default (104) | none | No gain pin to GND |

The "gain" values are the ADC capture level passed to the `ADC` mixer control (0 to 104).

## Status indicator on GPIO 23

Accessibility is a core part of DripRog's design, and this is where it lives.
The device reports its state through a single indicator on GPIO 23, and that
indicator can be **visual, audible, or tactile**. The firmware drives all three
identically (pin high = on) using the same patterns, so the device behaves the
same regardless of which you fit. None is the "default" or primary option; they
are equal choices, and you pick the one (or combination) that matches how you
need to perceive the device's state.

- **LED**: visual.
- **Active piezo buzzer**: audible.
- **Coin vibration motor**: tactile, and silent to anyone nearby.

All three respond to the same patterns (see [Indicator patterns](#indicator-patterns)).
Wiring for each is below.

### LED (visual)

LED in series with a current-limiting resistor to GND.

- **220 to 330 ohm** series resistor for a standard LED at 3.3 V.
- Long leg (anode) toward GPIO 23, short leg (cathode) toward the resistor/GND.

### Active piezo buzzer (audible, kept quiet)

This option uses an **active** piezo (built-in oscillator, runs on DC, not a
passive element). Driven straight from GPIO 23 an active piezo is loud, so a
**series resistor to reduce the volume** is recommended:

- Around **220 ohm** gives a quiet tone.
- **330 ohm or more** makes it quieter still. Higher resistance means lower
  volume, so it can be tuned to taste.
- Polarity matters: `+` toward GPIO 23, `-` toward the resistor/GND.

Same patterns as the other options, audible instead of visual.

### Coin vibration motor (silent / tactile)

A coin (ERM) vibration motor gives feedback you can feel without light or
sound, which also works well when the recorder needs to stay hidden.

**Do not connect the motor directly to GPIO 23.** A coin motor draws roughly
75 to 100 mA, far above the Pi's ~16 mA per-pin limit, and the inductive
kickback can damage the pin, so a small transistor driver is used instead:

- **N-channel MOSFET** (e.g. 2N7000) or **NPN transistor** (e.g. BC337 / 2N2222)
  switching the motor's low side.
- **~1 kohm** resistor from GPIO 23 to the gate/base.
- **Flyback diode** (e.g. 1N4148 or 1N4001) across the motor terminals,
  cathode to the positive supply, to absorb the inductive spike.
- Power the motor from the **3.3 V or 5 V rail**, not from GPIO 23.

The motor then follows the same on/off patterns as the other options.

#### Step-by-step wiring

If the description above isn't familiar, the steps below go connection by
connection. Use whichever part you have (both are through-hole TO-92, not SMD).
The leg order is different between the two, so follow the matching list.

**With a 2N7000 MOSFET.** Hold it with the flat side facing you and the legs
pointing down. The legs are, left to right: **source**, **gate**, **drain**.

1. Connect **GPIO 23** to one end of the **1 kohm resistor**.
2. Connect the **other end of the resistor** to the **middle leg (gate)**.
3. Connect the **left leg (source)** to a **GND** pin on the Pi.
4. Connect the **right leg (drain)** to the **motor's "-" wire**.
5. Connect the **motor's "+" wire** to a **5V** pin on the Pi.
6. Connect the **diode across the two motor wires**: the end with the painted
   **band goes to the "+" wire**, the other end to the "-" wire.

**With a BC337 NPN transistor.** Hold it with the flat side facing you and the
legs pointing down. The legs are, left to right: **collector**, **base**,
**emitter**.

1. Connect **GPIO 23** to one end of the **1 kohm resistor**.
2. Connect the **other end of the resistor** to the **middle leg (base)**.
3. Connect the **right leg (emitter)** to a **GND** pin on the Pi.
4. Connect the **left leg (collector)** to the **motor's "-" wire**.
5. Connect the **motor's "+" wire** to a **5V** pin on the Pi.
6. Connect the **diode across the two motor wires**: the end with the painted
   **band goes to the "+" wire**, the other end to the "-" wire.

Either way, when the recorder turns the indicator on, GPIO 23 switches the part
and the motor runs; the diode protects everything when it switches off. Leg
order can vary between transistor types, so it's worth checking your specific
part's datasheet if it isn't a standard BC337 or 2N7000.

## Indicator patterns
The indicator signals state by turning on and off in counts. With an LED these
are blinks, with a buzzer they are tones, and with a motor they are vibrations; the
pattern is the same for all three. "Pulse" below means one on-then-off cycle.


| Pattern | Meaning |
|---|---|
| One pulse at startup | Power-on self-test |
| Solid on | Ready (USB mounted, space available) |
| 2 pulses, pause, repeat | Waiting for USB / not enough space |
| 4 pulses then off | Recording started (off = recording) |
| Solid → 7 fast pulses → **solid on** | Recording stopped — wait for final solid before removing USB (hold 1 s while recording to trigger) |
| 9 fast pulses | Shutting down |


## Controls

- **Short press** (< ~0.8 s): start recording.
- **Long press** (>= ~0.8 s) while recording: stop recording.
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

Only three pins are wired (12, 5, 6). Positions 1 to 3 each pull one pin to
ground; position 4 connects nothing, which the firmware reads as level 104. The
level is read at idle and locked in when a recording starts. Because position 4
is the "nothing connected" state, an unwired or disconnected switch reads as
maximum gain: the recorder still runs, just always at 104.

### Why a switch and not a continuous dial

The recorder reads the gain position when idle and locks it the moment
recording starts, so the gain never changes during a recording, whatever the
switch does. The switch matters for the setting *before* you press record.
DripRog is made to be set once, closed into a dry pack, and left in the field,
and it's easy to pack it away without checking the gain again. A rotary switch
clicks into each position and stays there, so the level you set is still the
level when you press record, even after the unit has been moved around or
carried in a bag. A turn dial would be much easier to knock to a different
setting on the way.

The trade-off is fewer choices: four fixed levels instead of a smooth range. For this
use case it helps rather than hurts, because the point is a clear, repeatable
setting, not fine adjustment. If you want a smooth dial or different gain
behaviour, it can be changed in the recorder script (the gain reading is in one
small function).

### A note on setting gain for unattended recording

Setting a gain level before an overnight or multi-day recording is tricky. 
You don't know ahead of time how loud the place will be, and you
won't be there to change it, so there isn't really a "right" gain to pick for a
recording you leave running.

The switch is here anyway, because sometimes you do know something about the
spot (for example you know it will be very loud). Unless you have a reason to do
otherwise, **position 3 (level 80)** is a good default.

## Case

The **Teko A3** comfortably fits the Pi 3A+, the HiFiBerry board, and all components, while remaining compact and portable.

## Power

The Pi is powered over its micro-USB input, so any good USB power bank works.
A **high-quality battery** is recommended; cheap packs can sag or cut out under
the Pi's load and interrupt a recording. **Anker** packs are a known-good
choice.

As a rough guide, a **10 Ah** battery gives around **22 hours** of recording
time on a Pi 3A+ with this setup, and capacity scales with the session length
you need. Because the root filesystem is read-only, the battery simply dying
mid-session is safe: only the segment that was being written is lost.

DripRog is provided as-is. Please build and use it responsibly.

