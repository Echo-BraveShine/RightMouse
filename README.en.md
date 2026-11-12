# RightMouse

[简体中文](README.md) · English

Make Finder’s right click yours. Create files, organize them, copy paths, and open Terminal from the context menu.

[Website](https://echo-braveshine.github.io/RightMouse/en.html) · [Download](https://github.com/Echo-BraveShine/RightMouse/releases) · [Report an Issue](https://github.com/Echo-BraveShine/RightMouse/issues) · [Buy Me a Coffee](https://buymeacoffee.com/1239383708p)

**macOS 13+ · Apple silicon and Intel · English / 简体中文**

## Features

| Action | What it does |
| --- | --- |
| New File | Right-click a folder’s background to create a file from a template. Import and rename multiple templates per extension. The menu shows `extension(template name)`. |
| Move to and Copy to | Send selected items to a favorite folder or choose a destination for this operation. |
| Favorite Folders | Open frequently used folders from the context menu. |
| Copy Path | Copy selected paths, one per line, or right-click the background to copy the current folder path. |
| Open in Terminal | Open macOS Terminal in the current folder, a selected folder, or a file’s containing folder. |
| Menu and appearance | Reorder and toggle actions. Choose a language and appearance manually in General or follow macOS. Liquid Glass is available on macOS 26 and later. |

## Install and update

1. Download the universal ZIP from [GitHub Releases](https://github.com/Echo-BraveShine/RightMouse/releases), unzip it, and drag RightMouse into Applications.
2. Open RightMouse and use Extension Settings to enable its Finder extension in macOS System Settings.
3. Right-click the background of a local folder and choose New File.

The current packaging script uses ad hoc signing. Set up Apple Developer ID signing and notarization before public distribution. The Finder menu covers local folders and mounted volumes. File operations may require you to grant access through the system folder picker. macOS may request additional access to locations such as Desktop, Documents, or Downloads.

Open **General → Version & Support → Check for Updates** to check GitHub for a stable release. When an update is available, download and install it in the app, then relaunch.

## Homebrew

After the first GitHub Release and cask sync, use Homebrew to install and upgrade.

```sh
brew tap echo-braveshine/rightmouse https://github.com/Echo-BraveShine/RightMouse.git
brew install --cask echo-braveshine/rightmouse/rightmouse
brew upgrade --cask --greedy echo-braveshine/rightmouse/rightmouse
```

## Build locally

Open `RightMouse.xcodeproj` in Xcode with the macOS 26 SDK or later, then run RightMouse on My Mac.

```sh
./scripts/build-release.sh
```

The script produces a universal ZIP and a SHA-256 checksum. See the [release and deployment guide](RELEASING.md) for workflow details.

If RightMouse helps you, you can [buy me a coffee](https://buymeacoffee.com/1239383708p) to support its development.
