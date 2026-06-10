# DripRog

DripRog is a minimal, accessible, unattended field audio recorder for the
Raspberry Pi with a HiFiBerry DAC+ ADC Pro. One button, one status indicator,
records 192 kHz / 24-bit stereo WAV to a USB drive. Built to be dropped
somewhere, and picked up a day or two later. It can be built using off-the-shelf parts for a very moderate cost and requires minimal soldering. 

Accessibility is core to the design, not an afterthought. See
[Accessibility](#accessibility) below.

DripRog is the hardware counterpart to **Field Spectrum**, an accessible
spectral viewer and timeline for Ableton Live,  built for field recordists,
with full screen reader and keyboard support. More [here](http://if-tah.com/devices/field-spectrum).

There are two ways to use it:

- **Flash the ready-made image**: easiest, no setup. [Download the image here](https://www.if-tah.com/devices/driprog).
- **Use the scripts** (this repo): run on an existing Raspberry Pi OS install,
  or audit and modify what the device actually does.

This repository holds the open-source code behind the image. The image is a
custom, very small Buildroot OS built around these scripts: it includes only
what the recorder needs, boots and is ready to record in about 5 seconds, and
runs from a read-only root filesystem. The scripts here are exactly what runs on
it, so the repo is both the source and a way to run DripRog on an existing
Raspberry Pi OS install.

## What's here

```
driprog.sh                        the recorder
systemd/driprog.service           starts it at boot
systemd/usb-mount@.service        mounts the USB drive on insert
udev/99-usb-automount.rules       triggers the mount on hotplug
docs/HARDWARE.md                  wiring, GPIO pinout, indicator options
```

## Using the scripts on an existing system

Tested against Raspberry Pi OS Lite (libgpiod v2) and Buildroot (libgpiod v1).
The script auto-detects the libgpiod version, so it works on either.

Requirements on the target: `bash`, `alsa-utils` (`arecord`, `amixer`),
`libgpiod` tools (`gpioget`, `gpioset`), and the HiFiBerry overlay enabled in
`config.txt` (`dtoverlay=hifiberry-dacplusadcpro`, `dtparam=audio=off`).

Install:

```sh
sudo install -m 755 driprog.sh /usr/local/bin/driprog.sh
sudo install -m 644 systemd/driprog.service /etc/systemd/system/
sudo install -m 644 systemd/usb-mount@.service /etc/systemd/system/
sudo install -m 644 udev/99-usb-automount.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo systemctl daemon-reload
sudo systemctl enable --now driprog.service
```

Insert a FAT32 USB drive and the recorder is ready (indicator solid).

## How it works

- **Short press** the button: start recording.
- **Long press** while recording: stop.
- **Hold 5 s**: clean shutdown.

Recordings are written to /mnt/usb/recordings/droprig-NNN/, one folder per
power-on. The NNN is a simple counter: on each start, DripRog finds the
highest existing droprig-NNN folder on the drive and uses the next number, so
folders stay in order across sessions. Within a folder, audio is split into
~23-minute WAV segments. The status indicator shows state (see
docs/HARDWARE.md for the full pattern reference and wiring,
including the LED, piezo, and vibration-motor options on the indicator pin).

Note: DripRog has no real-time clock, a deliberate choice to keep the hardware
simple. As a result the device does not know the actual date or time. File
timestamps are consistent within a session but do not reflect real calendar
time, so use the folder counter and segment order to keep track of recordings.

## Accessibility

Accessibility is core to the design of DripRog, not an afterthought. The device
is built to be operable without relying on any single sense.

- **One control.** Everything is done with a single button: short press, long
  press, and a 5-second hold. There is no screen, menu, or app to navigate.
- **Status feedback options.** The status indicator on GPIO 23 can be a
  **visual LED**, an **audible active piezo buzzer**, or a **tactile coin
  vibration motor**. None is the default or primary option; they are equal
  choices. All three use the same patterns (startup, ready, recording, stopped,
  shutdown), so you pick the one, or combination, that works for you: sight,
  sound, or touch. Wiring for each is in
  [docs/HARDWARE.md](docs/HARDWARE.md#status-indicator-on-gpio-23).
- **Consistent, learnable patterns.** State is conveyed by a small set of
  distinct rhythms (for example solid = ready, fast pulses = shutting down)
  rather than by colour or pitch alone, so they read the same whether felt,
  heard, or seen.
- **A control you can set by feel.** Gain is a 4-position detented rotary
  switch, not a continuous dial. The positions click, so you can find and set a
  level by touch and count, without needing to see it or read a value.

If you build or adapt DripRog for a specific access need, contributions and
suggestions are welcome.

## Notes

- The image runs a **read-only root filesystem**, so pulling power (or a dead
  battery) won't corrupt the system. Recordings live on the separate USB drive;
  a power cut during a recording loses only the current segment.
- Networking, console, and logging are disabled for a clean, quiet,
  fast-booting field device.

## Hardware

Raspberry Pi 3A+ with a HiFiBerry DAC+ ADC Pro, button on GPIO 17, status
indicator on GPIO 23, 4-position gain switch on GPIO 12 / 5 / 6. Full wiring and
parts in [docs/HARDWARE.md](docs/HARDWARE.md).

### Microphones

DripRog uses **electret capsules** powered by the ADC's plug-in power. Good
choices: **Primo EM272** (quiet omni), **Primo EM419N** (successor to the
EM258, with very useful ultrasonic response),
and **PUI Audio** capsules (cheap, high quality). Note the HiFiBerry DAC+ ADC
Pro only supplies plug-in power when **jumpered for it**, so the jumper needs
to be set or there's no signal. Details in
[docs/HARDWARE.md](docs/HARDWARE.md#microphones).

### Storage and power

Recordings go to a **FAT32 USB drive**; a fast, reliable one is recommended
(tested: **Samsung FIT Plus**, **SanDisk Ultra Fit**). Power is over micro-USB
from any good battery pack; **Anker** packs work well, and roughly a **10 Ah**
battery gives about **24 hours** of recording on a Pi 3A+. See
[docs/HARDWARE.md](docs/HARDWARE.md#power) for more.

## License

MIT. See [LICENSE](LICENSE).

Copyright (c) 2026 Iftah Gabbai
