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

DMG 打开后会显示带背景和箭头的 Finder 安装窗口，将左侧 Lineboard 图标拖到右侧「应用程序」即可安装。打包时需要 Finder 保存窗口布局；本地首次运行可能提示允许终端控制 Finder。许可证亦包含在 App 资源中，完整附加说明位于磁盘映像的隐藏 `.info` 目录。

## 开发构建

为保持原有本地工作流，以下命令仍生成原路径（仅供本地开发使用）：

```bash
scripts/build-app.sh debug
open build/Tendedero.app
```

用于公开分发时必须使用 `package-release.sh`，它会使用独立的 Lineboard 名称和图标，并附带原版权声明。源码许可证要求修改／分发版更换名称和图标，详见 [LICENSE](../LICENSE)。

## 发布与校验

### 日常构建

每次向 `feature/universal-clipboard` 上传提交，`Build macOS development` 工作流都会在 macOS runner 上编译 Apple Silicon＋Intel 通用版，并生成 DMG、App ZIP、校验文件和源码提交信息；不运行测试。

打开仓库 [Actions](https://github.com/LeeHero0803/tendedero/actions)，选择最新成功的 `Build macOS development` 记录，在页面底部 **Artifacts** 下载产物（需要登录 GitHub），解压后即可取得 DMG 或 App ZIP。产物保留 30 天，文件名含 `dev`、构建序号与提交号；`build-info.json` 的 `channel` 为 `development`。它不会创建或修改 Release。当前开发包的应用版本基线为 `1.6.1`，定义在 `.github/workflows/build.yml` 中。

### 正式发布

确认某次提交可发布后，为该提交推送一个新的版本标签，例如：

```bash
git tag -a lineboard-v1.6.1 <已确认的完整提交号> -m "Lineboard 1.6.1"
git push origin lineboard-v1.6.1
```

`Prepare macOS release` 仅在推送 `lineboard-v主版本.次版本.修订号` 标签时运行，按标签构建并创建带附件的 Release 草稿。维护者检查后在 Releases 页面点击 **Publish release** 正式发布。如果存在 `docs/releases/版本号.md`，将使用该文件作更新说明，否则自动生成。普通分支提交不会触发正式发布。

每个版本使用新标签；已存在的 Release 会让流程停止，附件不会被覆盖。发布后继续开发时，应更新开发工作流的版本基线。构建失败时不创建 Release。

下载后可在附件所在目录执行：

```bash
shasum -a 256 -c SHA256SUMS.txt
```

当前自动构建使用 ad-hoc 签名，**未取得 Apple 公证**。Release 的 `build-info.json` 记录确切源码提交。GitHub 自动生成的 `Source code (zip/tar.gz)` 只是源码，不能当作 `.app` 安装。
