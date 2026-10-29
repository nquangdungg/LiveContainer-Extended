# LiveContainer Extended 5.0.0

| Component                  | Version |
| -------------------------- | ------- |
| **LiveContainer Extended** | `5.0.0` |
| **Embedded SideStore**     | CI nightly |

> [!Warning]
> Standalone build needs **SideStore 0.6.2+** or **AltStore 2.2.1+**.
> For `LiveContainer+SideStore.ipa` use Impactor or iloader.

## New Features

- SpringBoard / Grid / Compact app layout modes (Settings → App Layout)
- One-tap status bar (clock side) to exit guest app
- Cloudflare-inspired dashboard & accent colors
- Build-time version stamping (CFBundleShortVersionString / LCVersionInfo)

## Improvements

- Smoother layout switch animations (spring)
- Clean build pipeline — no embedded StikDebug
- External StikDebug / StosDebug still supported as JIT enablers

## Bug Fixes

- (track per release)

## Notes

- StikDebug is supported as an external JIT enabler only (not embedded).
- SpringBoard mode: 4-column home-screen style grid; long-press for Settings / Remove.

## Credits

- **Lead Developer:** Nguyen Quang Dung
- Based on [LiveContainer](https://github.com/LiveContainer/LiveContainer)
