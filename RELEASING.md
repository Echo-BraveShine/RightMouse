# 发布 RightMouse

## 构建与校验

使用包含 macOS 26 或更新 SDK 的 Xcode。运行 `./scripts/build-release.sh`，脚本会校验主应用与访达扩展都包含 arm64、x86_64，并在 `dist/` 生成 ZIP 和 `SHA256SUMS.txt`。

## GitHub Releases

1. 在 `App/Info.plist` 和 `FinderExtension/Info.plist` 中修改 `CFBundleShortVersionString`，两个值必须一致。
2. 提交两份 `Info.plist` 的版本变更。本地构建读取其中的 `CFBundleVersion`。
3. 在该提交打上匹配的标签，例如应用版本为 `0.0.1` 时使用 `v0.0.1`，再将标签推送到 GitHub。
4. Release 工作流验证标签与两份 plist 的版本一致，再把 `22 + GITHUB_RUN_NUMBER` 写入本次构建的两份 plist。重跑同一次工作流会沿用同一构建号。之后用 Sparkle 签名 ZIP，并发布 ZIP、校验文件、更新源和 GitHub 生成的发布说明。推送发布标签前，请确认该版本可公开分发。

如果标签已在 GitHub 上，但 Release 工作流没有运行，可以在 **Actions → Release → Run workflow** 选择 `main`，并输入现有标签（如 `v0.0.1`）。工作流会检出该标签的源码进行构建。已有空 Release 时，会把产物上传到该 Release。正常发版使用 `git push origin v0.0.1` 推送新标签来自动触发 Release。推送普通分支提交只触发各自适用的 CI 或官网工作流。

未配置 Apple 证书时，ZIP 使用临时签名。App 内的 Sparkle 通过 GitHub Releases 的 `appcast.xml` 检查并安装正式更新。

## Apple 签名与公证

在仓库 Actions Variables 中设置 `CODESIGN_IDENTITY` 为 Developer ID Application 签名标识。将 Base64 格式的证书包及其密码分别存为 `APPLE_CERTIFICATE_P12`、`APPLE_CERTIFICATE_PASSWORD`。将 App Store Connect 团队 API 密钥的原文、Key ID 和 Issuer ID 分别存为 `APPLE_NOTARY_KEY_P8`、`APPLE_NOTARY_KEY_ID`、`APPLE_NOTARY_ISSUER_ID`。工作流会在打包和 Sparkle 签名前完成公证并附加票据。配置 Apple 签名后，请使用包含新版打包脚本的标签构建。

## Sparkle 更新签名

- RightMouse 的公钥在 Xcode 的 RightMouse App 目标 Build Settings 中，由 `SPARKLE_PUBLIC_ED_KEY` 写入 App 的 `Info.plist`，对应本机钥匙串中的 Sparkle 账号 `RightMouse`。保留同一密钥，已安装的版本用它验证后续更新。
- 发布前，在 GitHub 仓库 **Settings → Secrets and variables → Actions** 添加 `SPARKLE_PRIVATE_KEY`，使用 RightMouse 对应的私钥。私钥只保存在钥匙串及受控的 Secret 中。
- 如需用 Sparkle 工具将本机密钥导入 GitHub，先用 `generate_keys --account RightMouse -x "$key_file"` 导出，再用 `gh secret set SPARKLE_PRIVATE_KEY --repo Echo-BraveShine/RightMouse < "$key_file"` 写入。将 `key_file` 设为只有当前用户可访问的临时路径，完成后移除临时文件。
- 本地验证可在构建后运行 `SPARKLE_KEYCHAIN_ACCOUNT=RightMouse python3 scripts/create-appcast.py`。脚本会使用 App 内置公钥验证签名，密钥不匹配时发布失败。

## Homebrew

发布成功后，工作流根据同一个发布 ZIP 的 SHA-256 生成并提交 `Casks/rightmouse.rb` 到默认分支。若分支保护禁止工作流推送，需通过允许的合并流程同步 cask。RightMouse 支持 Sparkle，因此通过 Homebrew 强制检查并升级时使用 `--greedy`。

```sh
brew tap echo-braveshine/rightmouse https://github.com/Echo-BraveShine/RightMouse.git
brew install --cask echo-braveshine/rightmouse/rightmouse
brew upgrade --cask --greedy echo-braveshine/rightmouse/rightmouse
```

## GitHub Pages

在 GitHub 仓库 **Settings → Pages → Source** 选择 **GitHub Actions**。推送 `website/` 变更到 `main`，或手动运行 Website 工作流。网站预计地址为 `https://echo-braveshine.github.io/RightMouse/`。

本地预览可运行 `python3 -m http.server --directory website`。中文版位于 `index.html`，英文版位于 `en.html`。

## 赞助入口

`.github/FUNDING.yml` 使用与 SimLaunch 相同的 Buy Me a Coffee 账号。README、官网和 App 直接链接到作者的赞助页面。


## GitHub Social preview

在仓库 **Settings → General → Social preview** 上传 [social-preview.png](website/assets/social-preview.png)（1280 × 640）。
