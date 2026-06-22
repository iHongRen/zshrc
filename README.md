# ZshrcEditor

[English README](./README.en.md)

`ZshrcEditor` 是一个面向 macOS 的轻量级 `~/.zshrc` 编辑器，专注于让 Shell 配置文件的查看、编辑、保存和验证更直接。

### 截图

请将截图文件放到合适位置后，替换下面的占位链接。

```md
![主界面截图](./Screenshots/zh-main.png)
![搜索与语法状态截图](./Screenshots/zh-search-and-status.png)
```

截图占位：

![主界面截图占位](./Screenshots/zh-main.png)
![搜索与语法状态截图占位](./Screenshots/zh-search-and-status.png)

### 功能特性

- 直接编辑 `~/.zshrc`
- 行号显示与 Shell 语法高亮
- 搜索栏、结果计数、上一个/下一个匹配跳转
- 保存时执行语法检查
- 保存成功后使用子进程执行 `source ~/.zshrc`
- 显示保存状态、语法状态、光标行列号
- 支持放大、缩小、恢复默认字号
- 支持浅色 / 深色 / 跟随系统
- 支持英文 / 简体中文界面
- 当外部编辑器修改 `.zshrc` 后，回到 App 可同步刷新内容
- 可以在 Finder 中定位 `.zshrc`

### 适用场景

- 想用一个更专注的 macOS 桌面工具维护 Shell 配置
- 不希望每次手动切换到终端验证 `source ~/.zshrc`
- 需要比纯文本编辑器更明确的状态反馈

### 运行方式

1. 使用 Xcode 打开 [ZshrcEditor.xcodeproj](/Users/cxy/Desktop/CXY/zshrc/ZshrcEditor/ZshrcEditor.xcodeproj)
2. 选择 `ZshrcEditor` scheme
3. 运行 App

### 项目结构

- [ZshrcEditor](/Users/cxy/Desktop/CXY/zshrc/ZshrcEditor)
  应用源码
- [scripts](/Users/cxy/Desktop/CXY/zshrc/scripts)
  辅助脚本

### 截图文件建议

如果你准备补截图，建议使用下面这些文件名：

- `Screenshots/zh-main.png`
- `Screenshots/zh-search-and-status.png`
- `Screenshots/en-main.png`
- `Screenshots/en-search-and-status.png`
