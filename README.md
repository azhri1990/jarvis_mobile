# JARVIS Mobile

Iron-Man-style Android HUD for the local JARVIS gateway.

## First mobile slice

- Reactor HUD with speech input.
- Text command console.
- Gateway health check.
- Skill-aware command routing with on-device confirmation for sensitive actions.
- Configurable laptop gateway URL and bearer token.
- No credentials are embedded in the app source.

The default URL is `http://127.0.0.1:5000`, which is useful for an Android
emulator or a gateway running on the phone. For a laptop gateway, use its LAN
address in the settings screen and ensure the gateway is deliberately bound to
the LAN interface. Use a trusted network; HTTP is enabled only for this local
development slice and should be replaced with HTTPS before remote access.

## Build

Install Flutter, then run:

```bash
flutter pub get
flutter test
flutter build apk --release
```

## Build without local Flutter

Push the repository to GitHub, then open **Actions → JARVIS Android build →
Run workflow**. The workflow runs analysis, widget tests, and the release APK
build. Download `jarvis-mobile-release-apk` from the completed workflow's
Artifacts section.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
