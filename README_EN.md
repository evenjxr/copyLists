# CopyLists

> **macOS 13+** · Native Swift · Local-only · [License](LICENSE) (free for non-commercial use; **contact us for commercial licensing**)  
> **中文说明:** [ReadMe.md](ReadMe.md)

A **clipboard history** app for macOS: hotkey to open, Return to paste; image thumbnails, **on-device OCR search**, **favorites that survive cleanup**, and **`⌘P` preview** (edit text / annotate images, then write back to the clipboard). Open source, no account, no ads; the stock build does not upload clipboard data (see **Privacy and security**).

**Repository:** [github.com/evenjxr/copyLists](https://github.com/evenjxr/copyLists) · **Download:** [Releases (latest)](https://github.com/evenjxr/copyLists/releases/latest)

---

## Contents

- [Quick start](#quick-start)
- [Features](#features)
- [Privacy and security](#privacy-and-security)
- [Shortcuts](#shortcuts)
- [Building from source](#building-from-source)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Quick start

### Install (recommended)

1. Open **[Releases → Latest](https://github.com/evenjxr/copyLists/releases/latest)** and download **`CopyLists.dmg`**.  
2. Drag `CopyLists.app` into **Applications**.  
3. **First open:** in Finder, **right-click → Open** (Gatekeeper may block unsigned / unnotarized builds; see [Troubleshooting](#gatekeeper-cannot-verify-developer)).  
4. Use the menu bar icon after launch; **pasting and the search field** need **Accessibility** permission (see [Troubleshooting](#paste-or-search-field-does-not-work)).

### Requirements

- macOS **13** or later  
- Apple Silicon and Intel: `build_app.sh` produces a **Universal** binary by default; if a release ships **arm64-only**, follow that build’s notes.

> **Slow GitHub access:** you can mirror the repo (e.g. Gitee) and attach the same-version DMG to a release there; publishing a **SHA256** or mapping to the official Git tag is recommended.

---

## Features

| Capability | Description |
|------------|-------------|
| **Panel** | `⌘⇧V` anywhere to open history; select an item and press `↵` to paste and return to the previous app. |
| **Types & dedup** | Detects URL / email / path / code / image / plain text; duplicate copies merge into one row with a use count. |
| **Keyboard** | `↑↓` move · `←→` filter tabs · `⇧↵` plain paste · `⌘S` favorite · `⌘P` preview · `⌘⌫` delete · `⎋` close. |
| **Favorites** | Favorites are **not evicted** by LRU; they remain when you clear history; filter chip for favorites. |
| **Preview (`⌘P`)** | Edit text, `⌘↩` writes back; images: pen / arrow / rectangle, `⌘Z` / `⌘⇧Z` undo/redo, `⌘↩` export annotated image. Pin keeps the window on top; multiple previews stack from the top-right; position and size are remembered. |
| **OCR** | **Vision** on-device (Chinese + English); recognized text is searchable. |
| **Privacy** | **Pause recording** from the menu bar; **exclude apps** by bundle ID (password managers excluded by default); see table below. |
| **Settings (`⌘,`)** | History limit (20–500), login item, pause, exclusion list. |

Data directory: `~/Library/Application Support/CopyLists/` (you may delete it after uninstalling the app).

---

## Privacy and security

| Topic | Behavior |
|--------|----------|
| **Clipboard** | Used only to build local history; **paused** state skips recording. |
| **Network** | Stock build has **no** analytics, cloud sync, or clipboard upload; if you change the code to add networking, your build’s behavior applies. |
| **Sensitive apps** | **Bundle ID** exclusions; 1Password, Bitwarden, Dashlane, LastPass, etc. are on the default list (skipped when that app is frontmost). |
| **OCR** | On-device only; text stored locally for search. |
| **Accessibility** | Used to simulate **`⌘V` paste** and focus the search field; you can revoke it in System Settings anytime. |
| **Login item** | Starts CopyLists only; does not add third-party login items. |

---

## Shortcuts

**Main panel**

| Key | Action |
|:---:|:---|
| `⌘⇧V` | Show / hide |
| `↑` / `↓` | Select item |
| `←` / `→` | Change type filter |
| `↵` | Paste |
| `⇧↵` | Paste as plain text |
| `⌘S` | Favorite / unfavorite |
| `⌘P` | Preview window |
| `⌘1`–`⌘9` | Quick paste 1–9 |
| `⌘⌫` | Delete selection |
| `⎋` | Close panel |

**Inside preview**

| Key | Action |
|:---:|:---|
| `⌘↩` | Save and close (text or annotated image to clipboard) |
| `⌘Z` / `⌘⇧Z` | Undo / redo (image annotations) |
| `⎋` | Close preview |

---

## Building from source

```bash
git clone https://github.com/evenjxr/copyLists.git && cd copyLists
bash build_app.sh          # produces CopyLists.app in the repo root
open CopyLists.app
```

Development run (no `.app` bundle):

```bash
bash dev_app.sh
```

**DMG (maintainers):** run `build_app.sh`, then `bash package_dmg.sh` (output is usually `CopyLists.dmg` in the repo root—confirm in the script).

---

## Troubleshooting

### Gatekeeper: “cannot verify developer”

Gatekeeper blocks apps that are not from the App Store and not **notarized** (or not signed as expected).

1. **Recommended:** Control-click `CopyLists` → **Open** → **Open** again. Often only needed once.  
2. If there is no Open button: **System Settings → Privacy & Security** → find the blocked-app message → **Open Anyway** / **Still Open**.  
3. **Long term:** **Developer ID** signing + **notarization** improves first-run experience.

### Paste or search field does not work

Enable **Accessibility**: **System Settings → Privacy & Security → Accessibility** → unlock → turn on **CopyLists**. If it is missing, launch the app and try paste once and accept the system prompt.

### Login item does not run at startup

**System Settings → General → Login Items & Extensions** → ensure **CopyLists** is enabled; if not, toggle **Open at login** again in the in-app settings.

### History missing after restart

Data lives under `~/Library/Application Support/CopyLists/`. Prefer the **DMG-installed** app if you only used `swift run` / debug flows before.

---

## License

See **[LICENSE](LICENSE)**: non-commercial use, modification, and redistribution are allowed if you keep the copyright and license text; **commercial use** requires prior written permission (email in LICENSE). Issues and PRs welcome.

**Sample post (Chinese communities, e.g. V2EX):** [docs/v2ex-share-draft.md](docs/v2ex-share-draft.md)

---

*CopyLists · macOS 13+ · [License](LICENSE)*
