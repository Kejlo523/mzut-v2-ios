# mzutv2 iOS

Oficjalny port iOS aplikacji `mzut-v2` (bez Wear/watch).  
Projekt jest oparty o SwiftUI + modul core z logika API, sesji i repozytoriow danych.

## Najwazniejsze informacje

- Nazwa aplikacji: `mzutv2`
- Bundle ID: `mzutv2`
- Minimalny iOS: `16.0`
- Generator projektu: `XcodeGen` (`project.yml`)
- Schemat build/test: `mZUTiOSApp`

## Co jest w repo

- `Sources/mZUTCore` - logika domenowa i komunikacja z serwerem (auth, plan, oceny, info, aktualnosci RSS, obecnosci, ustawienia, linki).
- `Sources/mZUTiOSApp` - warstwa UI w SwiftUI.
- `Tests/mZUTCoreTests` - testy jednostkowe warstwy core.
- `scripts/ios_capture_artifacts.sh` - automatyczne screenshoty + walkthrough video.
- `.github/workflows/ios-cloud-build.yml` - build/test/screenshoty/artefakty w GitHub Actions.

## Szybki start (lokalnie, macOS)

Wymagania:

- macOS
- Xcode 16+ (z iOS Simulator SDK)
- Homebrew
- `xcodegen` (`brew install xcodegen`)

Kroki:

1. Wygeneruj projekt:

```bash
xcodegen generate
```

2. Build:

```bash
xcodebuild \
  -scheme mZUTiOSApp \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -sdk iphonesimulator \
  build
```

3. Testy:

```bash
xcodebuild \
  -scheme mZUTiOSApp \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -sdk iphonesimulator \
  test
```

## CI / GitHub Actions

Workflow: `.github/workflows/ios-cloud-build.yml`

Workflow uruchamia:

1. Generowanie projektu (`xcodegen generate`)
2. Build i testy na iOS Simulator
3. Build unsigned iPhoneOS
4. Paczkowanie artefaktow instalacyjnych
5. Automatyczne screenshoty ekranow + walkthrough video

Opcjonalne sekrety (do automatycznego logowania i pelnych screenow):

- `MZUT_LOGIN`
- `MZUT_PASSWORD`

## Artefakty z CI

Artefakt: `ios-visual-artifacts`

Typowe pliki:

- `artifacts/screenshots/login.png`
- `artifacts/screenshots/home.png`
- `artifacts/screenshots/plan_day.png`
- `artifacts/screenshots/plan_week.png`
- `artifacts/screenshots/plan_month.png`
- `artifacts/screenshots/plan_week_album_57796.png`
- `artifacts/screenshots/grades.png`
- `artifacts/screenshots/info.png`
- `artifacts/screenshots/news.png`
- `artifacts/screenshots/attendance.png`
- `artifacts/screenshots/links.png`
- `artifacts/screenshots/settings.png`
- `artifacts/walkthrough.mp4`
- `artifacts/install/mzutv2-simulator-app.zip`
- `artifacts/install/mzutv2-iphoneos-unsigned.ipa`
- `artifacts/install/README_INSTALL.txt`

## Instalacja na iPhone

`mzutv2-iphoneos-unsigned.ipa` z CI jest unsigned i nie zainstaluje sie bez podpisu.

Opcje:

1. Apple Developer Program (platny) - podpis i dystrybucja (TestFlight / Ad Hoc).
2. Darmowe konto Apple + Xcode - uruchamianie bezposrednio z Xcode na podlaczonym iPhonie (certyfikat tymczasowy, ograniczenia Apple).

## Uwaga dot. bezpieczenstwa

Nie wrzucaj danych logowania do repo.  
Do CI uzywaj tylko GitHub Secrets (`MZUT_LOGIN`, `MZUT_PASSWORD`).
