# astra-flclash — FlClash fork for Samsung Modes and Routines control

A private fork of [chen08209/FlClash](https://github.com/chen08209/FlClash)
(GPL-3.0) adding a deterministic automation surface so **Samsung One UI Modes
and Routines** (and Tasker/MacroDroid) can drive the proxy without ambiguous
toggles or third-party click macros.

## Why this fork exists

Upstream ships only one app shortcut (`toggle`) and three Activity-mounted
intents (`START`/`STOP`/`TOGGLE`). For routine-driven automation that means:

- **Toggle is state-ambiguous** — a routine firing "toggle" cannot know whether
  it ends in on or off; start and stop are separate, deterministic actions.
- **No mode control** — switching rule/direct/global proxy modes had no external
  interface at all (upstream PRs #2288 and #1288 propose exactly this but sit
  unreviewed).
- **No profile control** — selecting between subscription profiles externally
  was impossible.

## Adaptations over upstream `main`

| Area | Change | Branch |
|:-----|:-------|:-------|
| App shortcuts | Start / Stop / Toggle dynamic shortcuts (adapts upstream PR #2288 onto current main) | `feat/app-shortcuts-start-stop` |
| Outbound mode | `CHANGE_MODE` broadcast receiver + `MODE_RULE/GLOBAL/DIRECT` actions + optional mode shortcuts; Kotlin→Dart bridge with cold-start replay via `ModeRequest` (adapts upstream PR #1288) | `feat/broadcast-change-mode` |
| Profiles | Optional per-profile shortcuts (`profile_<id>`), `selectProfile` channel call → `setProfileAndAutoApply`; opt-in via `--dart-define flclash.show_profile_shortcuts=true` | same branch |

### External interface contract (post-integration)

```text
Broadcast (adb shell am broadcast -a <action> com.follow.clash):
  com.follow.clash.action.START | STOP | TOGGLE
  com.follow.clash.action.CHANGE_MODE   extra: mode=rule|global|direct

App shortcuts (visible to Modes and Routines → "open app"):
  start / stop / toggle            always
  mode_rule / mode_global / mode_direct     default on (dart-define to disable)
  profile_<id>                            default off (dart-define to enable)

Cold-start semantics: if no Flutter engine is alive, mode/profile requests are
parked in ModeRequest and replayed when MainActivity configures the engine —
requests are never silently dropped.
```

## Building

GitHub Actions workflow `.github/workflows/android-build.yml` builds inside Nix
(`nix-community/flake-compat`-free: plain `nix build` of a dev shell providing
Flutter 3.47.1, JDK 17, Android SDK platform/build-tools matching
`compileSdk`, and Go for the core). Release signing keys come from repository
secrets (`KEYSTORE_B64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) and
are never committed.

Local dev shell:

```bash
nix develop .#android   # flutter, gradlew, go available
./gradlew -p android :app:assembleDebug
```

## Upstream attribution

Copyright (c) original author chen08209 retained; GPL-3.0 applies unchanged.
Feature commits carry `Co-authored-by:` trailers crediting the upstream PR
authors (cc_du for #2288, kmod-midori for #1288). If upstream ever merges these
PRs, this fork rebases back onto vanilla FlClash.
