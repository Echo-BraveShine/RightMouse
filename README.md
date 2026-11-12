# RightMouse

简体中文 · [English](README.en.md)

让访达右键更顺手。在当前目录新建文件、快速归档、复制路径，或直接打开终端。

[官网](https://echo-braveshine.github.io/RightMouse/) · [下载](https://github.com/Echo-BraveShine/RightMouse/releases) · [问题反馈](https://github.com/Echo-BraveShine/RightMouse/issues) · [请我喝杯咖啡](https://buymeacoffee.com/1239383708p)

**macOS 13+ · Apple 芯片与 Intel · 简体中文 / English**

## 功能

| 功能 | 用法 |
| --- | --- |
| 新建文件 | 在文件夹空白处右键，从模板新建文件。支持为同一后缀导入多个模板并重命名，菜单显示为 `后缀(模板名)`。 |
| 移动到、复制到 | 批量归档到常用目录，或临时选择目标文件夹。 |
| 常用目录 | 从右键菜单打开常用文件夹。 |
| 复制路径 | 选中项目时复制其路径，多选时每行一个。空白处右键可复制当前文件夹路径。 |
| 在终端中打开 | 从当前目录、所选文件夹或文件所在目录打开系统终端。 |
| 菜单与外观 | 拖动排序，自定义显示项，语言与外观都可以跟随系统，也可手动选择。macOS 26+ 支持液态玻璃。 |

## 安装与更新

1. 从 [GitHub Releases](https://github.com/Echo-BraveShine/RightMouse/releases) 下载通用版 ZIP，解压后将 RightMouse 拖到「应用程序」。
2. 打开 RightMouse，通过「扩展设置」在 macOS 系统设置中启用访达扩展。
3. 在本地文件夹空白处右键，选择「新建文件」试用。

当前发布脚本使用临时签名。公开分发前应配置 Apple Developer ID 签名与公证。访达菜单覆盖本地文件夹和挂载卷。文件操作需要相应权限，部分目录需要通过系统选择器授权。macOS 可能对「桌面」「文稿」「下载」等位置要求单独授权。

打开 **通用 → 版本与支持 → 检查更新** 查看 GitHub 上的正式发布版本。发现新版时，可在 App 内下载、安装并重新启动。

## Homebrew

首个 GitHub Release 发布且 cask 同步后，可通过 Homebrew 安装和升级。

```sh
brew tap echo-braveshine/rightmouse https://github.com/Echo-BraveShine/RightMouse.git
brew install --cask echo-braveshine/rightmouse/rightmouse
brew upgrade --cask --greedy echo-braveshine/rightmouse/rightmouse
```

## 本地开发

用包含 macOS 26 或更新 SDK 的 Xcode 打开 `RightMouse.xcodeproj`，选择 RightMouse → My Mac 运行。

```sh
./scripts/build-release.sh
```

构建脚本生成通用版 ZIP 和 SHA-256 校验文件。发布及官网部署步骤见 [发布说明](RELEASING.md)。

如果 RightMouse 对你有帮助，欢迎 [请我喝杯咖啡](https://buymeacoffee.com/1239383708p)，支持后续开发。
