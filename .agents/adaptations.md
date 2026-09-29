# Fork Adaptations (public layer)

A fork of [chen08209/FlClash](https://github.com/chen08209/FlClash) (GPL-3.0) adding a
deterministic automation surface so **Samsung One UI Modes and Routines** (and
Tasker/MacroDroid) can drive the proxy without ambiguous toggles or third-party click
macros. It also carries a Nix dev shell so the Android build is reproducible rather than
dependent on whatever happens to be installed on one machine.

Branch map, remote topology and other operating facts live in the gitignored
`AGENTS.local.md` — this file is safe to publish.

## Why this fork exists

Upstream ships only one app shortcut (`toggle`) and three Activity-mounted intents
(`START`/`STOP`/`TOGGLE`). For routine-driven automation that means:

- **Toggle is state-ambiguous** — a routine firing "toggle" cannot know whether it ends in
  on or off; start and stop are separate, deterministic actions.
- **No mode control** — switching rule/direct/global proxy modes had no external interface
  at all (upstream PRs #2288 and #1288 propose exactly this but sit unreviewed).
- **No profile control** — selecting between subscription profiles externally was impossible.

## Adaptations over upstream `main`

| Area | Change | Branch |
|:-----|:-------|:-------|
| App shortcuts | Start / Stop / Toggle dynamic shortcuts (adapts upstream PR #2288 onto current main) | `feat/app-shortcuts-start-stop` |
| Outbound mode | `CHANGE_MODE` broadcast receiver + `MODE_RULE/GLOBAL/DIRECT` actions + optional mode shortcuts; Kotlin→Dart bridge with cold-start replay via `ModeRequest` (adapts upstream PR #1288) | `feat/broadcast-change-mode` |
| Profiles | Optional per-profile shortcuts (`profile_<id>`), `selectProfile` channel call → `setProfileAndAutoApply`; opt-in via `--dart-define flclash.show_profile_shortcuts=true` | `feat/profile-app-shortcuts` |
| Linux runtime | geo-file refresh after core update; keep the IPC connection alive while a half-written frame waits on a suspended host | `main` |
| Build | Nix dev shell pinning the Android toolchain | `main` |

## External interface contract (post-integration)

```text
Broadcast (adb shell am broadcast -a <action> com.follow.clash):
  com.follow.clash.action.START | STOP | TOGGLE
  com.follow.clash.action.CHANGE_MODE   extra: mode=rule|global|direct

App shortcuts (visible to Modes and Routines → "open app"):
  start / stop / toggle                     always
  mode_rule / mode_global / mode_direct     default on (dart-define to disable)
  profile_<id>                              default off (dart-define to enable)

Cold-start semantics: if no Flutter engine is alive, mode/profile requests are parked in
ModeRequest and replayed when MainActivity configures the engine — requests are never
silently dropped.
```

## Building

The Android toolchain comes from the flake, not from whatever the host happens to have:

```bash
nix develop .#android   # flutter, jdk17, android sdk + ndk, cmake, go, rustup
cd android && ./gradlew :app:assembleDebug
```

The shell is `devShells.x86_64-linux.android`; the `.#android` selector matters because it
is not the default attribute.

Two settings are read from the environment because they are host-specific and neither
belongs in a repository:

- `FLCLASH_BUILD_HOME` — where Gradle/Cargo/rustup caches live (default
  `/tmp/flclash-build`). These need tens of GB; on a host whose root is tmpfs a large
  build dies mid-link, so point this at real disk there.
- `FLCLASH_PROXY_PORT` — a local listener fronting `services.gradle.org` and `crates.io`
  for hosts on networks that block them. Unset, the probe simply fails to match and the
  shell behaves as before.

Release signing is upstream's own `.github/workflows/build.yaml`, which reads
`${{ secrets.KEYSTORE }}` and friends. **No key material is committed here**, and this
repository defines no signing workflow of its own.

## Upstream attribution

Copyright of the original author is retained and GPL-3.0 applies unchanged. Feature
commits carry `Co-authored-by:` trailers crediting the upstream PR authors. Fork-specific
work is kept out of any branch submitted upstream, so review sees only the feature.

## Related agent docs

- [.agents/project.md](project.md) — overview, versions, build dependencies.
- [.agents/commands.md](commands.md) — build, development, test commands.
- [.agents/rules.md](rules.md) — lint, testing, workflow rules.
