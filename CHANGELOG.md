# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [0.1.0] - Unreleased

First public release.

### Added
- Real-time screen capture with ScreenCaptureKit, downscaled by the compositor (up to 60 fps)
- GPU per-zone color averaging with Metal and zero-copy texture input
- Letterbox (black bar) detection with temporal smoothing
- Standard Adalight protocol and the fixed-header variant used by Skydimo controllers
- Arbitrary serial baud rates via `IOSSIOSPEED`
- Auto-detection of CH340/CH9102, CP210x, FTDI, PL2303, Arduino and ESP32 USB controllers
- Configurable strip layout: LEDs per side, start corner, direction, edge depth
- Menu-bar status item and a settings window; color settings apply live
- Adaptive frame pacing: stops waiting for acknowledgements on controllers that never send them
- Automatic recovery after sleep/wake, USB re-enumeration and display reconnects
- Diagnostics: `--test-frame`, `--test-ends`, `--dry-run`, `--list-displays`, `--list-serial-devices`
- Universal (Apple Silicon + Intel) release build

[0.1.0]: https://github.com/RomanSur1998/glowline/releases/tag/v0.1.0
