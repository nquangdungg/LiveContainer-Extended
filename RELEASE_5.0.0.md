# LiveContainer Extended 5.0.0

| Component | Version |
|-----------|---------|
| **LiveContainer Extended** | `5.0.0` |
| **Embedded SideStore** | (from CI `sidestore_version.txt`) |
| **Embedded StikDebug** | (from CI `stikdebug_version.txt`) |

Full fork of [LiveContainer](https://github.com/LiveContainer/LiveContainer) with a modern dashboard UI, built-in SideStore packaging, optional full **StikDebug** embed, and everyday quality-of-life tools.

---

## Highlights

### Dashboard & UI
- Cloudflare-inspired home status (certificate, LocalDev VPN, quick actions)
- Unified **Install** (IPA file + URL)
- App layouts: **List / Grid / Compact** with consistent uninstall behavior
- Live accent color + **Fork** tag (opposite accent)
- Optional snow atmosphere overlay

### Runtime & Multitask
- **Double-tap status bar** to close the frontmost guest app / return to LiveContainer  
  (delayed single-tap, ~0.5s window — multitask iOS 16+ and guest process iOS 15+)
- Temporary close via Multitask minimize / PiP (keep app warm while switching)
- Cross-app URL scheme forwarding between guest apps

### Security & Developer
- App Lock (passcode / biometrics when allowed)
- **Developer Mode** (confirm → restart → banner)
- Custom guest icons & in-app **Info.plist** editor (Developer Mode)

### StikDebug (SideStore-style)
- CI can produce **`LiveContainer+StikDebug.ipa`** with full StikDebug under  
  `Frameworks/StikDebugApp.framework`
- Settings: status, open built-in StikDebug, import pairing file, request enable JIT  
  (`stikdebug://enable-jit`)
- Existing JIT Enabler options still supported

### Build / Release
- GitHub Actions: archive + pack **retry until success** (configurable max attempts), then release
- Timed `wget` for SideStore / StikDebug downloads (no infinite hang)
- SemVer-friendly version stamping on IPAs

---

## Install notes

- Standalone `LiveContainer.ipa`: use with **SideStore 0.6.2+** or **AltStore 2.2.1+**
- `LiveContainer+SideStore.ipa` / `LiveContainer+StikDebug.ipa`: install with  
  [Impactor](https://github.com/khcrysalis/Impactor) or [iloader](https://github.com/nab138/iloader)
- JIT on modern iOS still needs **LocalDev VPN** + pairing where applicable

---

## Credits

- **Lead Developer:** [Nguyen Quang Dung](https://github.com/nquangdungg)
- Based on **LiveContainer** — original authors and contributors  
  https://github.com/LiveContainer/LiveContainer
- SideStore ecosystem · [StikDebug](https://github.com/StikDebug/StikDebug)

---

## Technical (5.0.0 hardening)

- Status-bar double-tap rewritten (reliable delayed single-tap)
- Compile-blocking API fixes (`iconIsDarkIcon`, Settings structure, `openBuiltInStikDebug` placement)
- Warning cleanup: Sendable captures, deprecated `statusBarOrientation` / `keyWindow`, unused bindings, async `FileManager` enumeration, C prototype, unused OpenSSL temp

