# 从源码构建

## 环境

在 **macOS 14 或更新版本**上构建。需要 Git、Swift 和 macOS SDK；推荐安装完整 Xcode、首次打开并完成组件安装。可先确认：

```bash
xcode-select -p
swift --version
git --version
```

Command Line Tools 也可使用；其 macOS 27 SDK 缺少 SwiftUI 宏插件时，现有脚本会尝试同目录的 macOS 26 SDK。没有可用旧 SDK 时请使用完整 Xcode，不要修改 `@State` 或禁用系统安全保护。

## 下载与构建

```bash
git clone -b feature/universal-clipboard https://github.com/LeeHero0803/tendedero.git
cd tendedero
scripts/package-release.sh 1.6.0
```

输出为 `build/Lineboard.app` 和以下可分发文件：

```text
build/release/Lineboard-1.6.0-universal.app.zip
build/release/Lineboard-1.6.0-universal.dmg
build/release/build-info.json
build/release/SHA256SUMS.txt
```

脚本编译 arm64 与 x86_64，合并为通用可执行文件，然后检查架构和签名。没有测试步骤。版本参数必须使用 `主版本.次版本.修订号`。

启动：

```bash
open build/Lineboard.app
```

安装时先从菜单退出旧 App，再把 `Lineboard.app` 拖入「应用程序」。首次替换可能需要重新授权文件夹访问。不要让旧版 Tendedero 与 Lineboard 同时运行；使用新版本前关闭旧版开机启动。设置与历史通过保留的 Bundle ID 兼容。

## 开发构建

为保持原有本地工作流，以下命令仍生成原路径（仅供本地开发使用）：

```bash
scripts/build-app.sh debug
open build/Tendedero.app
```

用于公开分发时必须使用 `package-release.sh`，它会使用独立的 Lineboard 名称和图标，并附带原版权声明。源码许可证要求修改／分发版更换名称和图标，详见 [LICENSE](../LICENSE)。

## 发布与校验

仓库的 `Build macOS release` GitHub Actions 工作流运行于 macOS runner，执行相同的打包脚本，上传工作流产物并准备 `lineboard-v1.6.0` Release 草稿。构建失败时不产生可发布的安装包。维护者在 Releases 页面确认附件后发布草稿；功能分支上的工作流通过相关构建文件变更触发。

下载后可在附件所在目录执行：

```bash
shasum -a 256 -c SHA256SUMS.txt
```

当前自动构建使用 ad-hoc 签名，**未取得 Apple 公证**。Release 的 `build-info.json` 记录确切源码提交。GitHub 自动生成的 `Source code (zip/tar.gz)` 只是源码，不能当作 `.app` 安装。
