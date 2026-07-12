# Resona

**A native local music player for iPhone and iPad.**

Resona is an offline-first music player for the music you already own. It aims to make importing, browsing, and listening to local music feel simple and familiar on Apple platforms—without accounts, subscriptions, or streaming services.

> [!NOTE]
> Resona is an early-stage learning project and is not currently available on the App Store.

## Principles

- **Native by design** — Built around standard iOS components, interactions, accessibility, and adaptive layouts.
- **Local first** — Music stays on the device and remains available offline.
- **Focused** — A clean library and playback experience without unnecessary services or settings.
- **Reliable** — Playback, queues, metadata, and system controls take priority over decorative features.

## Planned Experience

- Import music from the Files app
- Browse songs by album, artist, or title
- Read embedded metadata and artwork
- Manage the playback queue, shuffle, and repeat modes
- Continue playing in the background
- Use Lock Screen, Control Center, and headphone controls
- Restore the previous queue and playback position
- Support iPhone, iPad, Dark Mode, Dynamic Type, and VoiceOver

## Status

Resona is currently in the foundation stage. Development is focused on the core path from importing a local audio file to playing it reliably in the foreground and background. Features and interface details may change as the project evolves.

## Run Locally

1. Open `Resona.xcodeproj` in Xcode.
2. Select an iPhone or iPad simulator, or a connected device.
3. Choose a signing team if required, then run the `Resona` scheme.

The current project targets iOS 26 or later.

## Technology

Resona is being built with Swift, SwiftUI, SwiftData, AVFoundation, and MediaPlayer.
