# OCTAVE

**Open-source car infotainment / carputer / DIY head unit — for Raspberry Pi, desktop, and Android.**

OCTAVE is a fully programmable, open-source infotainment system — a carputer you actually own. Rip out your factory head unit, bolt a Raspberry Pi to your dash, run it on a laptop in a project car, or sideload it onto an Android tablet. Plays your music, talks to your car over OBD-II, themes itself to your album art, and stays out of your way when you want to make it do something new.

Think of it as an open alternative to **Crankshaft, OpenAuto Pro, and AGL** — closer to a hackable foundation than a polished consumer product, with both a C++/Qt and a Python/PySide6 backend so you can fork whichever side you're already fluent in.

<p align="center">
  <img src="frontend/assets/readme/display.gif" alt="OCTAVE in motion" width="720">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/platforms-Win%20%7C%20macOS%20%7C%20Linux%20%7C%20Pi%20%7C%20Android-success" alt="Platforms">
  <img src="https://img.shields.io/badge/backend-C%2B%2B%20%2B%20Python-orange" alt="Dual backend">
  <img src="https://img.shields.io/badge/frontend-Qt%206%20%2F%20QML-41cd52" alt="Qt 6">
</p>

---

## Why OCTAVE

Stock head units age out fast. Aftermarket units lock you in. Android Auto and CarPlay are great, until you want to do something the manufacturer didn't think of.

OCTAVE is the third option: a **fully programmable** infotainment stack that you build, modify, and run on whatever hardware you want. It plays your music, talks to your car, syncs with hardware you solder yourself, and gets out of the way when you want to make it do something new.

If you've ever wanted to wire a rotary encoder to your dash, throw a custom OBD gauge on screen, or theme your UI to match your album art in real time — this is for you.

This isn't a product. It's a starting point. I maintain "vanilla" OCTAVE — but the whole point is that you fork it, mod it, and build the head unit *you* want.

## Who This Is For

- **The Pi tinkerer** — you've got a Raspberry Pi 4/5, a touchscreen, and a free weekend. You want a real infotainment stack to hack on, not a kiosk wrapped around a browser tab.
- **The factory-head-unit refugee** — your 2008 Civic / E46 / Tacoma / van came with something terrible (or nothing at all), and you'd rather wire a tablet into the dash than buy a $900 double-DIN.
- **The Android Auto / CarPlay defector** — those are great until you want to do something the manufacturer didn't sign off on. OCTAVE is the "do whatever you want" option.
- **The OBD-II data nerd** — you want live gauges, custom dashboards, and 50+ PIDs on screen without paying for a subscription app.
- **The van-build / overlander / project-car person** — you need an interface that survives being rebuilt three times and fits hardware nobody else supports.

If any of those sound like you, keep reading.

## How It Compares

| | OCTAVE | Crankshaft | OpenAuto Pro | Stock Android Auto |
|---|---|---|---|---|
| Open source | yes (MIT) | yes | partial | no |
| Runs without a phone | yes | no (AA projection) | no (AA projection) | no |
| Built-in OBD-II + custom gauges | yes | no | limited | no |
| Themable / forkable UI | fully (QML) | limited | limited | no |
| Local music + Spotify + downloads | yes | via phone | via phone | via phone |
| Desktop dev loop | yes (Win/macOS/Linux) | Pi only | Pi only | n/a |

OCTAVE is the option when you want a head unit that runs **on its own**, not a screen that mirrors your phone.

## See It

<p align="center">
  <img src="frontend/assets/readme/home_page.png" alt="Home" width="32%">
  <img src="frontend/assets/readme/media_room.png" alt="Media Room" width="32%">
  <img src="frontend/assets/readme/obd_page.png" alt="OBD Diagnostics" width="32%">
</p>

## What's In The Box

### Media & Audio
- Local player for MP3, M4A, FLAC with album art carousel and live FFT visualizer
- Spotify integration with OAuth2 and full device control
- Music search and download (Spotify metadata + YouTube audio)
- Dynamic theming that pulls colors straight from album art

### Vehicle & Hardware
- OBD-II diagnostics over ELM327 — 50+ live parameters, custom gauges, full dashboards
- ESP32 wireless volume knob with LED sync
- BerryIMU 9DOF sensor fusion (accelerometer, gyro, magnetometer, barometer)
- PAJ7620U2 gesture sensor for touchless control

### Platform & Customization
- Runs on Windows, macOS, Linux, Raspberry Pi, and Android
- Two parallel backends so you can hack in whichever language you'd rather live in
- 100+ user-configurable settings, all persisted to disk
- Custom gauge primitives and dashboard system — build your own and drop them in

## Quick Start

The fast path — clone, run one script, done:

```bash
git clone https://github.com/waybettersolutions/octave.git
cd octave
python setup.py
```

`setup.py` detects your OS, installs dependencies, builds a virtualenv, and launches the app. Pass `--no-run` to install without launching.

After setup:

```bash
source venv/bin/activate            # Windows: venv\Scripts\activate
python main.py                       # normal run
python main.py --debug               # verbose logging
python dev/dev_main.py               # simulated OBD + keyboard controls
```

### Running the C++ Build

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j
./build/octave
```

Full build matrix (9 targets including iOS, Android, Flatpak, and app store variants) lives in [BUILD.md](BUILD.md).

### YouTube downloads failing? Check your VPN first.

**99% of the time the fix is to turn off your VPN.** YouTube's bot detection blocklists most VPN exit IPs (NordVPN, ExpressVPN, Mullvad, ProtonVPN, etc. — they're shared with thousands of automated tools), and every download will fail with *"Sign in to confirm you're not a bot"* until you reconnect on a residential IP. If you need to stay on a VPN, switch to a residential-IP plan or a dedicated-IP exit node.

If turning off the VPN isn't an option (geo-restricted regions, privacy requirements), you can authenticate with your YouTube account via cookies as a fallback:

1. Install the **Get cookies.txt LOCALLY** extension in any Chromium-based browser:
   - Desktop: Chrome / Brave / Edge / Vivaldi.
   - Android: **Kiwi Browser** or **Brave** (Chrome on Android doesn't support extensions).
2. Log into <https://www.youtube.com> in that browser.
3. Click the extension's icon while on a YouTube tab → **Export → cookies.txt**.
4. Save (or rename) the file to `youtube_cookies.txt` in your **Downloads** folder:
   - **Linux / macOS:** `~/Downloads/youtube_cookies.txt`
   - **Windows:** `%USERPROFILE%\Downloads\youtube_cookies.txt`
   - **Android:** `/storage/emulated/0/Download/youtube_cookies.txt` (visible as `Internal storage / Download / youtube_cookies.txt` in any file manager)
5. Restart OCTAVE — every download will now use those cookies. Cookies usually stay valid for weeks.

OCTAVE detects the file automatically — no settings to configure. If you don't have the file, downloads still work for any video that isn't currently walled by YouTube on your network.

## Two Backends, One Frontend — Built For The Community

This is the part I care about most.

OCTAVE ships **two parallel backends** — C++ / Qt 6 and Python / PySide6 — both driving the same QML frontend. Not because the project needs both, but because **you** might. The whole reason this exists in two languages is so the next person to fork OCTAVE can pick up the side they're already fluent in and start building.

- Love C++? `src/` is yours. Performance, app stores, mobile — that's the side that ships natively.
- Live in Python? `backend/` is yours. Want to wire up a weird sensor on a Pi at 2am with a REPL open? Done in 20 lines.

The frontend doesn't know or care which one is running. Mod whichever side you want, ship to whoever you want.

I'll keep maintaining "vanilla" OCTAVE as the reference build. But the real win is the forks, the wild rigs, the custom dashboards, the ports to hardware I haven't even heard of yet. If you're sharper or weirder than me — and a lot of you are — take this and run.

## System Requirements

- **Python** 3.8+ (for the Python backend) / **Qt 6** + **CMake 3.16+** (for C++)
- **OS:** Windows 10+, macOS 10.14+, Linux (Debian / Arch / Fedora), Raspberry Pi OS, Android

## Roadmap

A few of the bigger things in flight — full plans live under [`TODO/`](TODO/):

- **Drag-and-drop dashboard editor** — Tony Hawk create-a-park, but for OBD gauges. See [`TODO/dashboards-roadmap.md`](TODO/dashboards-roadmap.md).
- **Native C++ Android port** — App Store / Play Store distribution. See [`TODO/android-cpp-port.md`](TODO/android-cpp-port.md).
- **In-app error notification UI** — surface backend issues without diving into log files.
- **Expanded test coverage** — beyond the current smoke suite.

## Documentation

The wiki covers everything — architecture, every backend manager, every frontend page, settings reference, hardware setup, build guides, the gauge authoring spec — start at [`wiki/index.html`](wiki/index.html). For building gauges and dashboards specifically, [`docs/GAUGE_AUTHORING.md`](docs/GAUGE_AUTHORING.md) is the source of truth.

## Contributing

Pull requests welcome. Bug reports welcome. Hardware mods welcome.

If you build something cool on top of OCTAVE — a custom dashboard, a new sensor integration, a port to weirder hardware — open an issue or PR and show it off. The more wild builds out there, the better the project gets.

Star the repo if you'd like to follow along.

## License

2026 [Way Better Solutions](https://waybetter.solutions/) — MIT License. Do whatever you want with it.
