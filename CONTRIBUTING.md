# Contributing / 参与贡献

English and Chinese are both welcome. / 欢迎中文或英文。

1. Search existing issues before opening a new one. Include macOS version, Mac chip, app version, reproduction steps, and expected/actual behavior. Do not include private screen contents or credentials.
2. For a new feature or a broad change, open an issue first. Keep pull requests focused.
3. Build with `zsh build.sh`, run the app's `--self-test`, and run `python3 scripts/check_localizations.py`.
4. Keep English and Chinese string keys and format placeholders in sync. Avoid adding raw user-facing strings in Swift views.
5. For timer, language, or window changes, describe the manual checks you performed. Do not claim hardware testing you did not perform.
6. By contributing, you agree that your contribution is distributed under this project's MIT license. Preserve notices for any third-party material you introduce.

提交问题前请先搜索已有反馈，并注明系统、芯片、版本、复现步骤和预期行为。较大的改动请先讨论，提交前运行构建与检查。界面文字请同时更新中英文资源；描述实际完成的测试，不要把未做的实机验证写成已完成。请勿上传个人敏感信息或密钥。
