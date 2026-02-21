# mZUT iOS

Repozytorium zawiera port iOS aplikacji `mzut-v2` (tylko aplikacja iOS, bez WearOS/watch).

## Zakres
- `Sources/mZUTCore`: warstwa logiki (sesja, auth, API, plan, oceny, info, news, obecnosci, linki, ustawienia).
- `Sources/mZUTiOSApp`: SwiftUI UI (login, home, plan, oceny, info, news, obecnosci, przydatne strony, ustawienia).
- `Tests/mZUTCoreTests`: testy jednostkowe warstwy core.

## Build i test (macOS)
Wymagania:
- macOS
- Xcode 16+
- XcodeGen (`brew install xcodegen`)

Kroki:
1. `xcodegen generate`
2. `xcodebuild -scheme mZUTiOSApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
3. `xcodebuild -scheme mZUTiOSApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test`

## CI i screenshoty
Workflow: `.github/workflows/ios-cloud-build.yml`

Zakres workflow:
- generowanie projektu,
- build + test na symulatorze iOS,
- automatyczne screenshoty wszystkich ekranow (`login`, `home`, `plan`, `grades`, `info`, `news`, `attendance`, `links`, `settings`),
- artefakt video `walkthrough.mp4`.
