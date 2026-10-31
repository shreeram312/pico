# Pico

Native macOS menu bar app (Swift 5 language mode, SwiftUI + AppKit), built with Swift Package Manager only; there is no Xcode project. Target macOS 14+.

## Commands

```bash
swift build                      # compile (debug)
scripts/build-app.sh             # debug build → build/Pico.app
scripts/build-app.sh 0.1.0       # universal release build, version 0.1.0
scripts/make-dmg.sh 0.1.0        # build/Pico-0.1.0.dmg + sha256
open build/Pico.app              # run (quit any running copy first)
```

Accessibility permission is granted per app bundle path, so always run from `build/Pico.app`, not `swift run`.

## Layout

- `Sources/Pico/` — all app code; one type per file
- `Resources/Info.plist` — bundle metadata (`__VERSION__` / `__BUILD__` filled by the build script)
- `scripts/` — build and packaging; `.github/workflows/release.yml` runs them on `v*` tags
- `Casks/pico.rb` — Homebrew cask template

## Rules

- Zero third-party dependencies unless there is a strong reason; keep the binary tiny.
- Providers are called over raw HTTP: `ClaudeClient.swift` (native Messages API) and `OpenAICompatibleClient` in `LLMClient.swift` (OpenAI, xAI, Gemini, local servers). Add a provider in `Provider.swift`. Never embed an API key; users bring their own, stored in the Keychain per provider.
- Pico must never activate itself or steal focus from the target app: the popup is a `.nonactivatingPanel`.
- Prompts live in `Actions.swift`. Romanized Indian languages stay romanized unless an action asks to change script.
