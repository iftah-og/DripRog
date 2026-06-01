# DripRog

DripRog is a minimal, accessible, unattended field audio recorder for the
Raspberry Pi with a HiFiBerry DAC+ ADC Pro. One button, one status indicator,
records 192 kHz / 24-bit stereo WAV to a USB drive. Built to be dropped
somewhere, left running on battery, and powered off whenever.

Accessibility is core to the design, not an afterthought. See
[Accessibility](#accessibility) below.

There are two ways to use it:

- **Flash the ready-made image**: easiest, no setup. [Download link here].
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
field_recorder.sh                 the recorder
systemd/field-recorder.service    starts it at boot
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
sudo install -m 755 field_recorder.sh /usr/local/bin/field_recorder.sh
sudo install -m 644 systemd/field-recorder.service /etc/systemd/system/
sudo install -m 644 systemd/usb-mount@.service /etc/systemd/system/
sudo install -m 644 udev/99-usb-automount.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo systemctl daemon-reload
sudo systemctl enable --now field-recorder.service
```

Insert a FAT32 USB drive and the recorder is ready (indicator solid).

## How it works

- **Short press** the button: start recording.
- **Long press** while recording: stop.
- **Hold 5 s**: clean shutdown.

Recordings are written to `/mnt/usb/recordings/droprig-NNN/`, one folder per
power-on, split into ~23-minute WAV segments. The status indicator shows state
(see [docs/HARDWARE.md](docs/HARDWARE.md) for the full pattern reference and
wiring, including the LED, piezo, and vibration-motor options on the indicator
pin).

## Accessibility

Accessibility is core to the design of DripRog, not an afterthought. The device
is built to be operable without relying on any single sense.

- **One control.** Everything is done with a single button: short press, long
  press, and a 5-second hold. There is no screen, menu, or app to navigate.
- **Choose how it reports state.** The status indicator on GPIO 23 can be a
  **visual LED**, an **audible active piezo buzzer**, or a **tactile coin
  vibration motor**. None is the default or primary option; they are equal
  choices. All three use the same patterns (startup, ready, recording, stopped,
  shutdown), so you pick the one, or combination, that works for you: sight,
  sound, or touch. Wiring for each is in
  [docs/HARDWARE.md](docs/HARDWARE.md#status-indicator-on-gpio-23).
- **Consistent, learnable patterns.** State is conveyed by a small set of
  distinct rhythms (for example solid = ready, fast blinks = shutting down)
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
EM258, with useful ultrasonic response, great for bats and insects at 192 kHz),
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
