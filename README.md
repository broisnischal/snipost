# Snipost

A minimal, modern screenshot tool for macOS. **Snip → auto-beautify → post.**

Capture a screenshot and it appears already beautified: a background gradient derived
from the screenshot's own colors, auto-growing padding, rounded corners, and a soft
shadow. One click to copy or save. (See [PRODUCT.md](PRODUCT.md) for the full vision —
Google Drive sync and social posting are next.)

## Requirements

- macOS 14+ (Apple Silicon or Intel)
- Swift toolchain (Xcode or Command Line Tools)

## Run it

```sh
# Dev run (menu bar icon appears; Ctrl-C to quit)
swift run Snipost

# Or build a proper app bundle
./Scripts/make-app.sh
open dist/Snipost.app
```

> **Screen Recording permission:** capture uses the system `screencapture` tool. macOS
> attributes the permission to the invoking app — your terminal during `swift run`, or
> Snipost.app when bundled. Grant it in System Settings → Privacy & Security →
> Screen Recording if window contents come out black.

## Use it

| Action | Hotkey | Also in menu bar |
|---|---|---|
| Capture area | ⌥⇧S | ✓ |
| Capture window | ⌥⇧W | ✓ |
| Capture full screen | ⌥⇧F | ✓ |

After a capture, the editor opens with the beautified result. Tweak background /
padding / corner radius / shadow / canvas aspect (16:9, 1:1, 4:5, 4:3), then
**Copy (⌘C)**, **Save to Desktop**, or **Save… (⌘S)**.

## Headless render check (no UI)

```sh
swift build
.build/debug/Snipost --selftest /tmp/snipost-test.png     # synthetic screenshot
.build/debug/Snipost --beautify in.png out.png            # your own image
```

## Architecture

```
Sources/Snipost/
  main.swift                  entry point + headless CLI modes
  AppDelegate.swift           menu bar item, global hotkeys, editor windows
  Capture/CaptureService.swift    system screencapture wrapper (ScreenCaptureKit later)
  Render/
    BeautifySettings.swift    settings model, gradient + aspect presets
    ColorAnalysis.swift       edge-color sampling → auto gradient
    BeautifyRenderer.swift    CoreGraphics compositor (bg → shadow → rounded image)
    HeadlessRender.swift      --beautify/--selftest CLI + PNG writer
  Editor/                     SwiftUI editor window
  Support/                    Carbon global hotkeys, clipboard
```

## Roadmap

- [x] Menu bar app, global hotkeys, area/window/screen capture
- [x] Auto-beautify: edge-color gradient, auto-grow padding, radius, shadow
- [x] Aspect presets, gradient gallery, transparent export
- [x] Copy / Save / headless render mode
- [ ] Floating post-capture thumbnail (skip editor for the 3-second flow)
- [ ] Google Drive sync (`drive.file` OAuth) with instant share link
- [ ] Social posting: pre-sized exports + web intents, then Bluesky/Mastodon APIs
- [ ] Annotations: arrow, box, text, blur/redact
- [ ] ScreenCaptureKit capture backend, scrolling capture, OCR
- [ ] History library, hotkey customization, Sparkle updates, notarized DMG
