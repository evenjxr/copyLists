# CopyLists

**macOS 13+** · Native Swift · Local-only · [License](LICENSE) (non-commercial free; **contact for commercial use**)

[中文版说明（ReadMe.md）](ReadMe.md)

## What it is

CopyLists is a **clipboard history** app for macOS: text, links, images, and more—recallable with a hotkey, searchable (including **OCR text inside images**), with **favorites** that survive cleanup, **preview windows** (`⌘P`) for quick edit/annotate, and **privacy controls** (pause + per-app exclusion).

## Trust & pricing

- **Open source** — you can audit what it does.  
- **No account, no ads, no tracking, no upload** — data stays under `~/Library/Application Support/CopyLists/`.  
- **Free for personal & non-commercial use** — see [LICENSE](LICENSE). **Commercial use requires prior permission** (email in LICENSE).

## Install

1. Download the latest **`CopyLists.dmg`** from [GitHub Releases](https://github.com/evenjxr/copyLists/releases/latest).  
2. Drag `CopyLists.app` into **Applications**.  
3. **First launch:** right-click the app → **Open** (Gatekeeper), or allow in **System Settings → Privacy & Security** if prompted.

Build from source:

```bash
git clone https://github.com/evenjxr/copyLists.git && cd copyLists
bash build_app.sh
open CopyLists.app
```

## Privacy (summary)

| Topic | Behavior |
|--------|----------|
| Clipboard | Monitored locally to build history; can **pause** anytime from the menu bar. |
| Sensitive apps | Default exclusions for common password managers; you can edit the list in Settings. |
| Network | No analytics or cloud sync in the stock build. |
| OCR | Runs on-device (Vision); extracted text is stored locally for search. |

For **Accessibility** permission: required so the app can send `⌘V` to paste into the frontmost app. See ReadMe.md (Chinese) for step-by-step screenshots-style instructions.

## Shortcuts (main panel)

| Key | Action |
|-----|--------|
| `⌘⇧V` | Show / hide panel |
| `↑` `↓` | Select item |
| `←` `→` | Change type filter |
| `↵` | Paste |
| `⇧↵` | Paste as plain text |
| `⌘S` | Favorite / unfavorite |
| `⌘P` | Preview floating window |
| `⌘1`–`⌘9` | Quick paste slot |
| `⌘⌫` | Delete |
| `⎋` | Close |

## License

[CopyLists License](LICENSE) — non-commercial use permitted; commercial licensing by arrangement.
