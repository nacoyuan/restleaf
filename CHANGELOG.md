# Changelog

## 1.2.0 — 2026-10-25

- Add a single heads-up when 5 minutes remain before a break.
- Automatically show the final `5:00` → `0:00` countdown beside the menu bar icon, even if the usual remaining-minutes option is off.
- Show the normal break reminder at zero. Away pauses the countdown; resuming preserves it without repeating the heads-up.
- Refresh every second only during the final countdown, and cache menu bar state icons.
- Expand timer checks to 33 and bilingual strings to 50.

## 1.1.0 — 2026-10-25

- Add English and Simplified Chinese, following system language with a manual setting.
- Rename the manual pause control to Away / Resume Timer (离开 / 恢复计时).
- Rename Restart Timer to Start Over (重新开始).
- Preserve remaining time when resuming and preserve the lid-open fresh-cycle rule.
- Add bilingual documentation, MIT license, contribution/issue templates, and CI checks.
- Remove the compile-time dependency on the macOS 27-only menu-image API.

## 1.0.3 — 2026-10-25

- Consolidate manual pause/resume and remove timed-away schedules.

## 1.0.1–1.0.2 — 2026-10-25

- Stop timing on lid close and start a fresh cycle when the session becomes available.
- Keep settings and quit menu entries text-only.

## 1.0.0 — 2026-10-24

- Initial personal-use release.
