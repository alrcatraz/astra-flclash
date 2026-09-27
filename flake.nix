{
  description = "astra-flclash Android build environment (Flutter + JDK + Android SDK + Go + Rust)";

  inputs = {
    # nixos-25.05 pins Flutter 3.32 / Dart <3.10 — too old for FlClash's
    # `sdk: '>=3.10.0'`. Unstable carries the 3.47.x stable series.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true; # Android SDK components are under non-open licenses
          android_sdk.accept_license = true;
        };
      };

      # Writable scratch for build caches. Defaults under /tmp so the shell works
      # out of the box; override per machine via FLCLASH_BUILD_HOME.
      buildHome = builtins.getEnv "FLCLASH_BUILD_HOME";
      cacheRoot = if buildHome == "" then "/tmp/flclash-build" else buildHome;

      # Port of a local HTTP listener fronting the artifact hosts, if any. Left
      # empty the probe below simply fails and nothing is exported, so this stays
      # correct on machines without such a listener.
      proxyPort = builtins.getEnv "FLCLASH_PROXY_PORT";

      # FlClash needs compileSdk/targetSdk 36 and NDK r28c (upstream CI env).
      # The `jni` pub plugin pins compileSdk 35, so both platforms are declared.
      androidSdk = pkgs.androidenv.composeAndroidPackages {
        platformVersions = [ "36" "35" ];
        buildToolsVersions = [ "36.0.0" "35.0.0" ];
        # :core (cmake-plugin) hard-requires cmake;3.22.1 from the SDK.
        # Correct attribute names (verified against compose-android-packages.nix):
        includeCmake = true;
        cmakeVersions = [ "3.22.1" ];
        includeNDK = true;
        ndkVersion = "28.2.13676358";
        useGoogleAPIs = false;
        includeEmulator = false;
        includeSystemImages = false;
      };
    in
    {
      devShells.${system}.android = pkgs.mkShell {
        packages = with pkgs; [
          jdk17
          git
          clang
          cmake
          ninja
          go
          flutter
          which
          androidSdk.androidsdk
          # plugins/rust_api builds via Dart native-assets and hard-requires
          # rustup (toolchain pinned to 1.95.0 in rust-toolchain.toml).
          rustup
        ];
        ANDROID_HOME = "${androidSdk.androidsdk}/libexec/android-sdk";
        ANDROID_SDK_ROOT = "${androidSdk.androidsdk}/libexec/android-sdk";
        JAVA_HOME = "${pkgs.jdk17}";
        # Gradle/maven caches and rustup toolchains run into tens of GB. The
        # Nix sandbox only allows writes to $TMPDIR, /private/tmp and the
        # store — so on a small tmpfs root a big build dies mid-link with
        # "Disk quota exceeded". Point these at a real filesystem via
        # extra-sandbox-paths when running locally, e.g.
        #   FLCLASH_BUILD_HOME=/path/to/disk nix develop .#android \
        #     --option extra-sandbox-paths /path/to/disk
        GRADLE_USER_HOME = "${cacheRoot}/gradle";
        CARGO_HOME = "${cacheRoot}/cargo";
        RUSTUP_HOME = "${cacheRoot}/rustup";
        shellHook = ''
          mkdir -p "$GRADLE_USER_HOME" "$CARGO_HOME" "$RUSTUP_HOME"
          # The NDK clang wrapper resolves its builtin headers relative to the
          # *invocation path*; bindgen (rquickjs-sys) then can't find stdbool.h.
          # Our forked build.rs reads a JSON array of flag-groups from these
          # env vars. native_asset.dart only copies WHITESPACE-separated tokens
          # verbatim into cargo's env, so each group must be ONE token: encode
          # the whole array with spaces escaped as \t (serde_json unescapes it).
          ndk="${androidSdk.androidsdk}/libexec/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64"
          bargs=$(printf '[["-isystem","%s/lib/clang/19/include"],["-isystem","%s/sysroot/usr/include/arm-linux-androideabi"],["-isystem","%s/sysroot/usr/include"]]' "$ndk" "$ndk" "$ndk" | sed "s/ /\\\\t/g")
          export RQUICKJS_BINDGEN_CLANG_ARGS="$bargs"
          export BINDGEN_EXTRA_CLANG_ARGS_armv7_linux_androideabi="$bargs"
          export BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android="$bargs"
          export BINDGEN_EXTRA_CLANG_ARGS_x86_64_linux_android="$bargs"
          # Gradle and cargo ignore the lowercase *_proxy vars Java/Dart honour;
          # behind the GFW their artifact hosts (services.gradle.org, crates.io)
          # need the local proxy explicitly. Only when it is actually listening.
          if timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/${proxyPort}" 2>/dev/null; then
            export http_proxy=http://127.0.0.1:${proxyPort} https_proxy=http://127.0.0.1:${proxyPort}
            test -f "$GRADLE_USER_HOME/gradle.properties" || cat > "$GRADLE_USER_HOME/gradle.properties" <<'PROPS'
systemProp.http.proxyHost=127.0.0.1
systemProp.http.proxyPort=${proxyPort}
systemProp.https.proxyHost=127.0.0.1
systemProp.https.proxyPort=${proxyPort}
PROPS
          fi
          # Mirror the repo's pinned toolchain into the disposable rustup home.
          if ! ${pkgs.rustup}/bin/rustup toolchain list | grep -q '^1\.95\.0'; then
            ${pkgs.rustup}/bin/rustup toolchain install 1.95.0 --profile minimal \
              -t aarch64-linux-android,armv7-linux-androideabi,x86_64-linux-android || true
          fi
        '';
      };
    };
}
