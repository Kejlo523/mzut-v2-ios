# mzutv2 iOS

`mzutv2 iOS` to aplikacja mobilna dla studentow ZUT.
To natywny port iOS (SwiftUI) aplikacji `mzut-v2`, zawierajacy logowanie i moduly takie jak plan, oceny, informacje o studiach, aktualnosci, obecnosci, linki i ustawienia.

## Build (macOS)

Wymagania:
- macOS
- Xcode 16+
- XcodeGen (`brew install xcodegen`)

Kroki:
1. W katalogu repo wygeneruj projekt:

```bash
xcodegen generate
```

2. Zbuduj aplikacje pod symulator:

```bash
xcodebuild \
  -scheme mZUTiOSApp \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -sdk iphonesimulator \
  build
```
