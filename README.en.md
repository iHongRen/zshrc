# zshrc

[![GitHub Release](https://img.shields.io/github/v/release/iHongRen/zshrc?style=flat-square)](https://github.com/iHongRen/zshrc/releases) [![Downloads](https://img.shields.io/github/downloads/iHongRen/zshrc/total?style=flat-square)](https://github.com/iHongRen/zshrc/releases) ![macOS](https://img.shields.io/badge/macOS-14.0%2B-black?style=flat-square&logo=apple) [![License](https://img.shields.io/github/license/iHongRen/zshrc?style=flat-square)](./LICENSE)

[中文 README](./README.md)

[zshrc](https://github.com/iHongRen/zshrc) is a minimal macOS app for viewing and editing `~/.zshrc`. It runs a syntax check when you save.

![](./screenshots/app.png)

### Installation

1. Recommended install script:

```sh
curl -fsSL https://raw.githubusercontent.com/iHongRen/zshrc/main/install.sh | sh
```

It installs to `/Applications/zshrc.app` by default.

2. Manual installation:

Download the latest `zshrc.dmg` from [GitHub Releases](https://github.com/iHongRen/zshrc/releases), install it, then run this command in Terminal to remove the quarantine attribute for the unsigned app:

```sh
xattr -dr com.apple.quarantine /Applications/zshrc.app
```

### Features

- Direct editing of `~/.zshrc`
- Line numbers and Shell syntax highlighting
- Search bar, match count, and previous/next match navigation
- Syntax validation on save
- Save status, syntax status, and cursor line/column display
- Zoom in, zoom out, and reset font size
- Light / dark / follow system appearance modes
- English / Simplified Chinese UI
- Reveal `.zshrc` in Finder
