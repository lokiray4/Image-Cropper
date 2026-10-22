# 图片随手裁 · Image Cropper

原生 Mac 图片框选截图工具：打开图片，拖动框选，松开鼠标后自动保存为 PNG。支持 macOS 12 或以上、Apple 芯片与 Intel。

## 使用

1. 打开 **图片随手裁.app**，点击“打开图片…”选择本机图片。
2. 在图片内按住鼠标左键拖动框选。选区外会变暗，下方显示截图像素尺寸。
3. 松开鼠标后，截图立即自动保存。可以在同一张图上反复框选，每次生成一个独立文件。
4. 默认保存在原图所在目录下新建的 **逐图截图** 文件夹；也可点击“选择保存文件夹…”指定其他位置。
5. 点击“显示刚保存的图片”在 Finder 中定位文件，或点击“打开保存位置”查看所有截图。

截图使用原始像素，保留透明通道，不改变原图。文件名包含原图名称和时间戳，不覆盖已存在的截图。裁剪结果是静态 PNG；GIF、多页图只使用第一帧／页。支持 JPG、PNG、HEIC、TIFF 等系统可读取的格式，并处理 EXIF 旋转方向。

拖动须至少达到 3 × 3 屏幕点，避免误触产生文件。Esc 可清除当前选区或取消正在进行的框选；已经自动保存的文件会保留。窗口可放大或全屏，图片始终完整适应画布。选区采用矩形，框选后可直接重新拖动产生下一张截图。

自定义保存文件夹在本次应用会话中持续有效，换图后仍使用该文件夹；重新启动应用后恢复默认位置。全部操作在本机完成，无需联网、上传或屏幕录制权限。若原图目录不可写，请选择其他保存位置。

## 快捷键

| 快捷键 | 操作 |
| --- | --- |
| ⌘ O | 打开图片 |
| ⌘ Shift S | 选择保存文件夹 |
| ⌘ L | 打开保存位置 |
| ⌃ ⌘ F | 切换全屏 |
| Esc | 清除／取消选区 |
| ⌘ Q | 退出 |

## 首次打开

解压 ZIP 后双击 App，也可拖到“应用程序”文件夹。应用使用本地 ad-hoc 签名，未经 Apple 公证。若系统拦截，可在“系统设置 → 隐私与安全性”中查看对应的“仍要打开”选项。

## 源码构建

使用 Swift / AppKit / ImageIO，无第三方依赖。需要 Apple Command Line Tools 或 Xcode。仓库根目录执行：

```bash
bash scripts/test.sh
bash scripts/build.sh
open "dist/图片随手裁.app"
```

构建产物包含 arm64 与 x86_64 两个架构。测试验证屏幕选区到原图像素映射、裁剪内容、自动保存、不覆盖、越界处理和 EXIF 方向。

源码构建已使用 Swift 6.1 验证，采用 Swift 5 语言模式。不需要 Xcode 项目文件。首次安装开发工具可执行 `xcode-select --install`。也可以用 `bash scripts/build.sh /path/to/output` 指定输出目录。

## 生成安装包

```bash
bash scripts/package.sh
```

脚本重新构建双架构 App，进行本地签名与架构检查，然后在 `dist/` 生成：

```text
dist/
├── 图片随手裁.app
├── image-cropper-mac-v1.0.0.zip
└── image-cropper-mac-v1.0.0.zip.sha256
```

## 项目结构

```text
Sources/main.swift          AppKit 界面与鼠标框选
Sources/CropEngine.swift    图片方向、坐标映射、裁剪和保存
Tests/CropTests.swift       独立裁剪与输出测试
Resources/Info.plist        应用元数据
scripts/                   构建、测试、打包与编译器配置
docs/                      使用和 GitHub 发布说明
.github/workflows/         macOS 自动构建与测试
```

## GitHub 自动构建

推送到 `main`、推送 `v*` 标签、向 `main` 提交 Pull Request 或手动运行工作流时，GitHub Actions 会测试、构建并提供安装 ZIP 和校验文件。工作流只使用仓库读取权限，不自动创建公开 Release。

完整操作见 [GitHub 上传与发布指南](docs/github.md)。开发和手动界面检查见 [贡献指南](CONTRIBUTING.md)，详细使用说明见 [使用指南](docs/usage.md)。

## 许可证

采用 [MIT License](LICENSE)。
