
# Lidiculous
<img src="lidiculous.png" alt="Lidiculous" width="500"/>

![macOS](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square&labelColor=0a0a0a&color=6b2d3e) ![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&labelColor=0a0a0a) ![License](https://img.shields.io/badge/license-MIT-green?style=flat-square&labelColor=0a0a0a) ![Size](https://img.shields.io/badge/size-~300KB-purple?style=flat-square&labelColor=0a0a0a)

---

## You snapped the microphone/lid sensor ribbon cable?

- Without the lid sensor, macOS has no idea whether the lid is open or closed. So when I plug in an external monitor and "close" my laptop, the machine keeps the internal display on and heating up. Meanwhile I'm sitting at my external monitor like everything is fine.

- With two displays active, macOS scatters menu bars and spaces across both screens, and your mouse cursor loves to vanish into the void between monitors at the worst possible moment. Lidiculous kills the internal display completely — one screen, one menu bar, no cursor roulette.

---

## Features

- Disable/re-enable the built-in display from the menu bar
- Auto-toggle — kills internal on external connect, revives on disconnect
- Launch at Login — starts at boot, auto-disables if external is already connected
- Zero dependencies

---

## Build

```bash
git clone https://github.com/ciutadellla/Lidiculous.git
cd Lidiculous
./build.sh
```

## Debug

```bash
swift package clean
swift build && .build/debug/Lidiculous
```

> **First launch:** grant Accessibility permission when prompted, or go to **System Settings → Privacy & Security → Accessibility**.

---

## Usage

Click the display icon in your menu bar.

| Control | What it does |
|---|---|
| Built-in toggle | Manually kill / revive the internal display |
| Auto-toggle | Plug HDMI → screen off. Unplug → screen back. |
| Launch at Login | Starts at boot and auto-disables on connect |
| Re-enable All | Emergency — forces every display back on |

---

## Permissions

- **Accessibility** — required to call the private `CGSConfigureDisplayEnabled` API
- **Login Items** — optional, only used when you enable "Launch at Login"

---

*Built by [@ciutadellla](https://github.com/ciutadellla) Sometimes the best ideas comes from the dumbest mistakes.*
