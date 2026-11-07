# Shoply / Avo

Gemeinsame Einkaufslisten mit KI-Kategorien, Angebotspreisen, Rezepten und dem Assistenten Avo.
Flutter (iOS zuerst), Supabase als Backend, Riverpod für den Zustand, Gemini für KI.

## Schnellstart

```bash
git clone https://github.com/jannisd07/shoply.git && cd shoply
flutter pub get
cd ios && pod install && cd ..
flutter run -d <simulator-id>
```

Voraussetzungen: Flutter 3.47.x (wie in CI; `pubspec.lock` braucht Dart ≥ 3.11), Xcode, CocoaPods. Viele Plugins kommen über Swift Package Manager (`ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`), deshalb `Podfile.lock` und `Package.resolved` immer zusammen committen.

Drei Dateien sind absichtlich **nicht** im Repo und müssen per AirDrop vom anderen Mac kommen:

| Datei | Inhalt |
|---|---|
| `lib/core/config/env.dart` | Supabase-URL/Key, Gemini-Key, Google-OAuth-Client (Vorlage: `env.example.dart`) |
| `lib/firebase_options.dart` | Firebase-Konfiguration (`flutterfire configure`) |
| `ios/Runner/GoogleService-Info.plist` | Firebase iOS-Konfiguration |

## Prüfen

```bash
dart analyze          # muss 0 errors und 0 warnings zeigen
flutter test
flutter build ios --simulator --debug
```

GitHub führt `dart analyze --fatal-warnings` und `flutter test` bei jedem Push aus (`.github/workflows/check.yml`).
TestFlight läuft nur manuell (`.github/workflows/ios-testflight.yml`, braucht Repo-Secrets, siehe dort).

## Doku

| Datei | Wofür |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Regeln für Claude-Sessions: Skills, Zwei-Mac-Workflow, Konventionen |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Wie die App aufgebaut ist und wo was liegt |
| [docs/OPEN-ISSUES.md](docs/OPEN-ISSUES.md) | Was nur der Owner erledigen kann (Backend, Secrets, Produktentscheidungen) |
| [docs/DESIGN-STATUS.md](docs/DESIGN-STATUS.md) | Stand des Designs, Grundlage für den Redesign |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | Größere Änderungen am Repo |
