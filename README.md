# DripRog

DripRog is a minimal, unattended field audio recorder for the Raspberry Pi
with a HiFiBerry DAC+ ADC Pro. One button, one status indicator, records 192 kHz /
24-bit stereo WAV to a USB drive. Built to be dropped somewhere, left running
on battery, and powered off whenever.

There are two ways to use it:

- **Flash the ready-made image** — easiest, no setup. [Download link here].
- **Use the scripts** (this repo) — run on an existing Raspberry Pi OS install,
  or audit/modify what the device actually does.

This repository is the open-source component behind the image: the image is
just a pre-built version of these scripts.

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
wiring, including LED / piezo / vibration-motor options on the indicator pin).

## Notes

- The image runs a **read-only root filesystem**, so pulling power (or a dead
  battery) won't corrupt the system. Recordings live on the separate USB drive;
  a power cut during a recording loses only the current segment.
- Networking, console, and logging are disabled for a clean, quiet,
  fast-booting field device.

## Hardware

Raspberry Pi 3A+ + HiFiBerry DAC+ ADC Pro, button on GPIO 17, status indicator
on GPIO 23, optional gain switch on GPIO 12 / 5 / 6. Full wiring and parts in
[docs/HARDWARE.md](docs/HARDWARE.md).

## License

MIT — see [LICENSE](LICENSE).

Copyright (c) 2026 Iftah Gabbai
