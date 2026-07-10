# Murmur

Murmur is a macOS desktop widget app for mood, lightweight to-dos, and private self-reminders.

## Run Locally

```bash
swift run MurmurApp
```

The app runs as a menu bar utility named `Murmur`. It opens one desktop widget by default.

During development, Murmur is intentionally packaged as a normal visible app so it appears in the Dock and Force Quit list.

Quit options:

- Right-click the Murmur widget and choose `Quit Murmur`.
- Open `Settings` and click `退出 Murmur`.
- Use the Dock menu or `Command-Q`.

For sandboxed development runs in this workspace, use:

```bash
MURMUR_DEV_DATA_DIR="$PWD/.murmur-dev-data" \
HOME="$PWD/.build-cache/home" \
CLANG_MODULE_CACHE_PATH="$PWD/.build-cache/clang" \
swift run --disable-sandbox --scratch-path "$PWD/.build-cache/swiftpm" MurmurApp
```

To create a local `.app` bundle:

```bash
bash scripts/package-dev-app.sh
open "dist/Murmur.app"
```

## Current V1 Skeleton

- macOS native Swift/AppKit app.
- One transparent desktop widget.
- Frosted-glass card body.
- Default blurred cover.
- Click widget body to toggle blurred/clear state.
- Desktop pet stays clear outside the cover.
- Menu bar actions for showing the widget, toggling the cover, opening settings, and quitting.
- Local JSON state saved under macOS Application Support by default.
- Optional `MURMUR_DEV_DATA_DIR` override for local development data.

## Notes

This is currently a Swift Package app skeleton because the local machine has Swift command-line tools but not the full Xcode project toolchain. Before App Store packaging, migrate this into a standard Xcode app target and add signing, icon, entitlements, and release packaging.
