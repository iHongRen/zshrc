# ZshrcEditor

[中文 README](./README.md)

`ZshrcEditor` is a lightweight macOS editor for `~/.zshrc`, focused on making shell configuration editing, saving, and validation faster and clearer.

### Screenshots

Place screenshots in your preferred location, then replace the placeholder links below.

```md
![Main window](./Screenshots/en-main.png)
![Search and status](./Screenshots/en-search-and-status.png)
```

Screenshot placeholders:

![Main window placeholder](./Screenshots/en-main.png)
![Search and status placeholder](./Screenshots/en-search-and-status.png)

### Features

- Direct editing of `~/.zshrc`
- Line numbers and shell syntax highlighting
- Search bar with match count and previous/next navigation
- Syntax validation before save
- Runs `source ~/.zshrc` in a child shell after saving
- Status feedback for save state, syntax state, and cursor position
- Zoom in, zoom out, and reset font size
- Light / dark / follow system appearance modes
- English / Simplified Chinese UI
- Syncs content after external `.zshrc` edits when returning to the app
- Reveal `.zshrc` in Finder

### Good Fit For

- Maintaining shell configuration in a focused macOS desktop app
- Validating `source ~/.zshrc` without switching back to Terminal every time
- Getting clearer feedback than a plain text editor provides

### Run

1. Open [ZshrcEditor.xcodeproj](/Users/cxy/Desktop/CXY/zshrc/ZshrcEditor/ZshrcEditor.xcodeproj) in Xcode
2. Select the `ZshrcEditor` scheme
3. Run the app

### Project Layout

- [ZshrcEditor](/Users/cxy/Desktop/CXY/zshrc/ZshrcEditor)
  Application source code
- [scripts](/Users/cxy/Desktop/CXY/zshrc/scripts)
  Helper scripts

### Suggested Screenshot Filenames

- `Screenshots/zh-main.png`
- `Screenshots/zh-search-and-status.png`
- `Screenshots/en-main.png`
- `Screenshots/en-search-and-status.png`
