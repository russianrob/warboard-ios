# Torn-page screenshot share (gyazo-style) — design

**Goal:** an owner-only button in the in-app browser toolbar that screenshots the
current Torn page, uploads it to the warboard server, and gives the owner a
public, shareable `tornwar.com/s/<hex>.png` link.

**Not** an agent feature — the screenshot is for sharing, not for the agent to
see. (The idea started in the agent-chat thread but was scoped to a standalone
share tool.)

## Decisions (owner-approved)
- **Placement:** browser toolbar, next to the ✨/Scripts buttons.
- **Audience:** owner only (playerId 137558), same gate as the agent chat.
- **After capture:** copy the URL to the clipboard **and** present the iOS share
  sheet, with a toast confirmation.
- **Resolution:** full-res PNG (native), not the agent's 600pt downscale.
- **URL:** unguessable random 16-hex filename.
- **Retention:** prune `public/s/` files older than 30 days on each upload.

## Flow
Owner taps 📷 → app snapshots the WKWebView content (not the SwiftUI chrome) →
POSTs the base64 PNG to `POST /api/screenshot` (owner JWT) → server writes
`public/s/<hex>.png` (served statically) and returns `{ url }` → app copies the
URL to the clipboard, shows the share sheet, and toasts "Link copied".

## Components
**Server (`/opt/warboard/server`)**
- `POST /api/screenshot` in `routes.js`: `requireAuth` + `_inspectIsOwner` gate;
  `express.json({limit:"16mb"})`; validates base64 + PNG magic bytes; writes
  `public/s/<randomBytes(8).hex>.png`; prunes >30d; returns
  `{ ok, url: "https://tornwar.com/s/<hex>.png" }`. `public/` is already served
  statically (`server.js`), so no new serving code.

**iOS (`warboard-ios`)**
- `BrowserModel.captureFullPNG()` — native-resolution `WKWebView.takeSnapshot`.
- `BrowserView`: owner-gated `camera` toolbar button → `captureAndShare()` →
  capture → `onUploadScreenshot` closure → clipboard + `ShareSheet` +
  `showToast`. New `onUploadScreenshot: ((Data) async -> String?)?` init param
  (framework can't read PrefsStore, so the uploader is injected).
- `ContentView`: provides the uploader closure (`uploadScreenshot(_:baseUrl:jwt:)`
  reading `prefs.baseUrl` + owner JWT) and passes it in.

## Error handling
Capture nil → toast "Couldn't capture page". Upload non-200 / nil jwt / network
error → toast "Upload failed". Server rejects non-owner (401/403), bad base64 /
non-PNG (400), oversized (400).

## Security
Owner-JWT gated end to end. Filename is server-generated random hex (no
user-controlled path). Content is magic-byte-checked PNG. URLs are unguessable;
`public/s/` has no directory listing.
