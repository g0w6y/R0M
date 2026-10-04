# R0M

A system monitor and cache cleaner for Apple Silicon Macs. Native SwiftUI, no dependencies, no network access, no tracking.

## What it does

- **Monitor** CPU (per core), GPU, memory, temperatures (CPU, SSD, battery), battery health, live power draw, storage, network, Wi-Fi and Bluetooth battery levels.
- **Menu bar** readout that keeps updating with the window closed.
- **Clean** caches and logs, both your own and system-wide, plus Xcode, npm and Gradle caches.
- **Schedule** automatic power-on, shutdown and sleep.

## Install

You need an Apple Silicon Mac on macOS 14 or later.

### Download

1. Get `R0M-<version>.dmg` from the [latest release](../../releases/latest).
2. Open it and drag R0M into Applications.
3. The first time you open it, macOS will say it can't verify the app, because R0M is not notarized. Go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.

If you prefer the terminal, `xattr -dr com.apple.quarantine /Applications/R0M.app` does the same thing.

### Build from source

You need the Command Line Tools (`xcode-select --install`). Full Xcode is not needed.

```sh
git clone https://github.com/g0w6y/R0M.git
cd R0M
./build.sh
```

This builds the app and installs it to `/Applications`. Use `./build.sh --no-install` to only build, or `scripts/make-dmg.sh` to create the disk image in `dist/`. An app you build yourself opens without the warning.

## Cleaner

The Cleaner only touches the direct contents of these folders:

`~/Library/Caches`, `~/Library/Logs`, Xcode DerivedData and DeviceSupport, Simulator caches, `~/.npm/_cacache`, `~/.cache`, `~/.gradle/caches`, `/Library/Caches` and `/Library/Logs`.

- Your own files go to the Trash by default. Space is freed once you empty it.
- System folders ask for your password and are deleted permanently. Anything macOS protects is skipped.
- Items belonging to running apps are marked and never selected for you.
- It also has Empty Trash, Flush DNS and Purge memory.

## Compatibility

| Mac | Status |
|---|---|
| MacBook Air M4, macOS 27 | Tested |
| Other Apple Silicon Macs | Should work, not tested yet |
| Intel Macs | Not supported |

Temperature sensor names differ between chips, so that is the most likely thing to break. If something is missing on your Mac, run the command below and [open an issue](../../issues/new?template=compatibility.md) with the output.

```sh
/Applications/R0M.app/Contents/MacOS/R0M --diagnose
```

## Limits

- Temperatures use IOKit functions that are not in Apple's public headers. If macOS removes them, the temperature cards hide.
- Fan speed, per-app energy and CPU frequency need private APIs or root, so they are not shown.
- The Wi-Fi network name needs Location permission. Signal, rate and channel do not.
- History only covers the time R0M is running.

## Development

```sh
./build.sh --no-install
scripts/test.sh
```

`scripts/test.sh` checks the Cleaner's safety rules using throwaway files. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
