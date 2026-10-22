# 上传到 GitHub 与发布版本

推荐仓库名：`image-cropper`。

推荐描述：`原生 macOS 图片裁剪工具：拖动框选，松开自动保存。Swift + AppKit + ImageIO。`

推荐 Topics：`macos`、`swift`、`appkit`、`image-cropper`、`image-processing`、`productivity`。

## 上传源码

在 GitHub 创建名为 `image-cropper` 的空仓库，按需选择公开或私有。不要自动生成 README、许可证或 .gitignore，本项目已经包含。

解压仓库 ZIP，在终端进入 `image-cropper` 目录。将 `YOUR_USERNAME` 替换为自己的 GitHub 用户名，执行：

```bash
git init -b main
git add .
git commit -m "Initial release: native macOS image cropper"
git remote add origin https://github.com/YOUR_USERNAME/image-cropper.git
git push -u origin main
```

如果 Git 提示缺少作者信息，先用 `git config user.name` 和 `git config user.email` 设置提交署名及邮箱，可使用 GitHub 的 noreply 邮箱。通过自己的 GitHub 登录流程认证，不要将令牌写进项目。

本地交付目录已初始化 `main` 分支，没有提交或远程地址。ZIP 不包含 `.git` 历史，以上命令也适用于 ZIP 解压后的项目。

也可在网页上传，但必须包含隐藏文件 `.github/workflows/build.yml`、`.gitignore` 和 `.gitattributes`。Finder 中按 `⌘ Shift .` 显示隐藏文件。README 应直接位于 GitHub 仓库根目录，不要多套一层文件夹。

## 自动构建

向 `main` 推送、推送 `v*` 标签、向 `main` 提交 PR 或手动运行工作流时，会在 macOS runner 上执行测试和双架构构建。完成后可在 Actions 运行详情页下载 `image-cropper-mac` artifact，其中包含安装 ZIP 和校验文件，保留 14 天。

工作流仅申请 `contents: read`，无需额外密钥，不会自动发布 Release。云端工作流需上传后才能实际验证。若仓库禁止运行 Actions，需要由所有者启用。

采用官方 [actions/checkout](https://github.com/actions/checkout) 与 [actions/upload-artifact](https://github.com/actions/upload-artifact)。

## 发布 App

1. 更新 `Resources/Info.plist` 的 `CFBundleShortVersionString`，递增 `CFBundleVersion`，填写 `CHANGELOG.md`。
2. 执行 `bash scripts/test.sh` 和 `bash scripts/package.sh`。
3. 提交版本变更，创建并推送对应标签，例如 `v1.0.0`。
4. 在 GitHub Releases 页面选择标签，填写说明，将 `dist/image-cropper-mac-v1.0.0.zip` 与对应 `.sha256` 文件作为附件上传。
5. 确认后发布 Release。也可使用该标签的 Actions 产物；校验文件须与实际发布的 ZIP 配套。

安装包作为 Release 附件发布，不加入源码历史。`.build/`、`dist/` 和本机临时文件已被忽略。

当前 App 使用 ad-hoc 本地签名，未经 Apple 公证，应在发布说明中告知使用者。若配置 Developer ID 签名和公证，应在生成最终 ZIP 前完成，再重新生成校验文件。
