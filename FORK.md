# About this fork

This repository is a fork of [krisgfx9/Wireless-Device-Battery-Monitor](https://github.com/krisgfx9/Wireless-Device-Battery-Monitor), where the app is developed. All device support comes from there, so please report device problems and request new devices [upstream](https://github.com/krisgfx9/Wireless-Device-Battery-Monitor/issues).

The fork's own documentation lives in this file, not in `README.md`. The README is the original's, with one notice added at the top, so that it never gets in the way when the fork is brought up to date.

## What it adds

- **Check for updates:** the first entry in the menu, showing the installed version. It asks GitHub for this fork's latest release and, if there is a newer one, offers to install it: one click downloads the installer, checks it against the SHA-256 that GitHub published for it, installs it silently and restarts the app. It only runs when you click it and only downloads installers from this repository's releases. If anything fails, it offers the download page instead.
- **Widget position:** *Place at the left edge of the taskbar* in the menu moves the widget from beside the notification area to the far left. It is off by default. It needs Windows 11 with centered taskbar icons and the Widgets button turned off; otherwise the option is greyed out and the widget stays next to the notification area.

Everything else is the original, unchanged.

## Install

Download `WirelessBattery-Setup-<version>.exe` from [this fork's latest release](https://github.com/anas1412/Wireless-Device-Battery-Monitor/releases/latest) and run it. Installers from the original and from this fork replace each other, so install one or the other.

## Versions

Releases are numbered `<upstream version>.<fork build>`: `1.0.8.1` is the first fork release based on upstream 1.0.8, `1.0.8.2` the next, and `1.0.9.1` the first one based on upstream 1.0.9.

## How it stays current

The fork's commits are kept on top of the original's `main` (rebased, not merged), so it always contains everything upstream has plus the additions above.

- **Weekly, by itself:** the GitHub Actions job `sync-upstream.yml` checks upstream every Monday. When there are new commits it replays the fork's commits on top, pushes `main` and publishes the next release. It pushes with the deploy key stored in the `SYNC_DEPLOY_KEY` secret.
- **By hand:** `release.cmd` does the same routine on your machine, asking before each push. `release.cmd -DryRun` only shows what would happen.
- **Conflicts:** when upstream and the fork changed the same lines, the weekly job fails without pushing anything and GitHub mails the owner. Run `release.cmd` locally, resolve the conflict, and run it again.

To keep conflicts rare, the fork's code sits on its own lines where possible (marked `Fork:` in comments), its menu IDs use their own range (200 to 299), and its documentation stays out of the README.
