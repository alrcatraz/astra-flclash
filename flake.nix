{
  description = "astra-flclash Android build environment (Flutter + JDK + Android SDK + Go)";

  inputs = {
    # nixos-25.05 pins Flutter 3.32 / Dart <3.10 — too old for FlClash's
    # `sdk: '>=3.10.0'`. unstable carries Flutter 3.47.x; androidenv is
    # identical in substance on both.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          android_sdk.accept_license = true;
          allowUnfree = true;
        };
      };

      # FlClash needs compileSdk/targetSdk 36 and NDK r28c (upstream CI env).
      androidSdk = pkgs.androidenv.composeAndroidPackages {
        platformVersions = [ "36" ];
        buildToolsVersions = [ "36.0.0" ];
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
        ];
        ANDROID_HOME = "${androidSdk.androidsdk}/libexec/android-sdk";
        ANDROID_SDK_ROOT = "${androidSdk.androidsdk}/libexec/android-sdk";
        JAVA_HOME = "${pkgs.jdk17}";
        GRADLE_USER_HOME = "/tmp/flclash-gradle-home";
      };
    };
}
