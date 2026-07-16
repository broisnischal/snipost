# Snipost

**A minimal, modern screenshot tool for macOS.** Snip → auto-beautify → post.
The screenshot equivalent of [screen01](https://screen01.app/) (free, native, cinematic screen recorder): the same "drop it on a beautiful background" polish, but for still captures — with sync to *your* Google Drive and one-click posting to social platforms.

---

## Positioning

> Capture a screenshot and it's already beautiful, already backed up, already ready to post — in under 3 seconds.

| Tool | Beautify | Cloud | Social posting | Price |
|---|---|---|---|---|
| **Xnapper** | ✅ auto-balance, its whole pitch | ❌ | size presets only | $15 one-time |
| **CleanShot X** | partial | ✅ proprietary cloud | ❌ | $29 + $8/mo cloud |
| **Shottr** | backdrop tool, less refined | ❌ | ❌ | free / $8 |
| **screen01** (video) | ✅ bg/padding/radius/glow | ❌ | ❌ | free |
| **Snipost** | ✅ auto-grow background | ✅ **your own Drive** | ✅ **compose & post** | free core |

The two gaps nobody fills: **bring-your-own cloud** (CleanShot charges $8/mo for theirs) and **actually posting** (Xnapper only resizes for platforms; you still do the posting).

---

## Core loop (the 3-second flow)

1. Global hotkey → snip an area / window / full screen
2. Floating preview appears **already beautified** — background auto-applied, padding auto-grown, corners rounded, shadow on
3. One click: **Copy** · **Save** · **Drive link** · **Post**

No editor to open unless you want to tweak. That's the screen01 ethos: no menus, no setup, the default output already looks professional.

## Features

### 1. Capture
- Hotkeys: area, window, full screen, repeat-last-bounds
- Window capture with clean rounded corners, no desktop clutter behind it
- Retina-aware (ScreenCaptureKit), menu-bar app, optional no-dock-icon
- Later: scrolling capture, timed capture, OCR copy-text

### 2. Beautify — "background auto grow"
- **Auto-balance**: sample the screenshot's edge/dominant colors → generate a matching gradient background automatically (zero clicks)
- Auto padding that scales with image dimensions; corner radius, shadow, glow
- Background gallery: gradients, mesh, macOS wallpapers, solids, transparent, custom image
- **Platform aspect presets**: X 16:9 · Instagram 1:1 & 4:5 · LinkedIn · Open Graph · Dribbble
- Optional browser-chrome / macOS-window frame mockup
- Minimal annotations only: arrow, rect, text, blur/redact. Later: auto-detect emails/tokens and offer redaction (Xnapper-style)

### 3. Sync — *your* cloud, not ours
- Connect Google Drive (OAuth, `drive.file` scope — non-sensitive, avoids Google's restricted-scope review since we only touch files we create)
- Every export auto-uploads to a `Snipost/` folder; shareable link lands on the clipboard
- User owns storage → zero monthly infra cost for us, no subscription for them
- Later: iCloud Drive, Dropbox, S3/R2

### 4. Post everywhere
- **v1 (no API keys needed)**: pick platform → image pre-sized to that platform's preset + copied to clipboard + compose window opened via web intent (X, LinkedIn, Threads). Caption box in-app, one compose reused across platforms.
- **v2 (direct posting)**: Bluesky (AT Protocol) and Mastodon first — free, easy APIs; then X API, LinkedIn API. Instagram has no viable personal-posting API → keep the clipboard+open route.
- Slack/Discord via webhooks/share sheet.

### 5. Library
- Local history with thumbnails, search; later OCR-indexed search ("find that screenshot with the error message")

---

## Tech stack

- **Swift + SwiftUI** (AppKit interop where needed), macOS 14+, Apple Silicon-first
- **ScreenCaptureKit** for capture; TCC screen-recording permission handled in onboarding
- **Core Image / Metal** render pipeline — live preview of background/padding/shadow must be 60fps
- **Google Drive REST v3** multipart upload, tokens in Keychain, PKCE OAuth
- **Bluesky/Mastodon** direct APIs; X/LinkedIn web intents in v1
- Distribution: notarized DMG + **Sparkle** for updates (outside App Store; Drive OAuth + posting is easier there)

## MVP plan (~6 weeks)

| Week | Milestone |
|---|---|
| 1–2 | Menu-bar app, capture engine (area/window/screen + hotkeys), floating post-capture preview |
| 2–3 | Beautify pipeline: auto background, auto-grow padding, radius/shadow, platform presets, copy/save/export |
| 4 | Google Drive connect, auto-upload, share-link copy |
| 5 | Social flow (presets + captions + web intents), local history |
| 6 | Onboarding (permissions UX), polish, notarization, landing page |

## Business model

Follow the screen01/Xnapper playbook: **free core forever** (capture + beautify + copy/save — that alone beats Shottr's backdrop), **Pro one-time ~$15–19** for Drive sync, direct posting, custom preset packs, library OCR search. No subscriptions — that's CleanShot's weakness and part of the pitch.

## Known risks

- macOS screen-recording permission is a scary dialog → invest in onboarding
- Google OAuth app verification takes time even with `drive.file` — start the process early
- X API pricing is hostile → web intents first, direct posting only where APIs are friendly (Bluesky, Mastodon)
- Instagram direct posting: not feasible for personal accounts; don't promise it
