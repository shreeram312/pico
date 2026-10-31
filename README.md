# Pico

A tiny popup for the text you select, in any Mac app. Fix it, translate it, make it formal, or flip Hinglish / Tenglish / Tanglish between English letters and native script, with one shortcut.

Select text → **⌥ Space** → pick an action → **⏎** replaces it in place.

- Works everywhere: WhatsApp Web, Mail, Slack, Notion, VS Code, Safari…
- Built for Indian languages: understands romanized Hindi, Marathi, Telugu, Tamil, Kannada and more, and keeps them romanized unless you ask to change script
- Actions: Fix · To native script · To romanized · To English · To my language · Formal · Shorter · Draft reply · Explain · your own custom actions
- Bring your own Anthropic API key. It lives in your Mac's Keychain. Pico has **no server, no accounts, no analytics**; requests go straight to Anthropic.
- Open source (MIT), menu bar only, ~2 MB

## Install

1. Download the latest `Pico-x.y.z.dmg` from [Releases](../../releases) and drag Pico to Applications.
2. First launch: **right-click Pico → Open → Open**. (Pico isn't notarized by Apple yet, so macOS warns once. If you see "damaged", run `xattr -dr com.apple.quarantine /Applications/Pico.app`.)
3. Allow **Accessibility** when asked (System Settings → Privacy & Security → Accessibility). Pico needs it to read the selected text and replace it.
4. Open Settings from the menu bar icon, paste your [Anthropic API key](https://platform.claude.com/settings/keys), and choose your language.

Or with Homebrew (once the tap is published):

```bash
brew install --cask GITHUB_USER/tap/pico
```

## Custom actions

Add your own actions in `~/Library/Application Support/Pico/actions.json` (Settings → Custom actions → Reveal creates an example):

```json
[
  {
    "id": "whatsapp",
    "title": "WhatsApp style",
    "icon": "message",
    "prompt": "Rewrite this as a friendly WhatsApp message in {{language}}, with one or two fitting emoji."
  }
]
```

`{{language}}` is replaced with the language and script you chose in Settings. `icon` is any SF Symbol name.

## Build from source

Requires macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`). Full Xcode is optional.

```bash
swift build                 # compile
scripts/build-app.sh        # assemble build/Pico.app (debug)
open build/Pico.app
```

Release build (universal) and DMG:

```bash
scripts/build-app.sh 0.1.0
scripts/make-dmg.sh 0.1.0
```

Pushing a tag like `v0.1.0` runs the same steps in GitHub Actions and attaches the DMG to a release.

## How it works

- `HotKey.swift`: global ⌥ Space via the Carbon hotkey API
- `SelectionService.swift`: reads the selection through the Accessibility API, falling back to a simulated ⌘C; replaces via Accessibility or a simulated ⌘V, restoring your clipboard
- `ClaudeClient.swift`: streams from the Claude Messages API with your key
- `Actions.swift`: the built-in actions and the shared system prompt
- `PopupController.swift` / `PopupView.swift`: a non-activating floating panel, so the app you're typing in keeps focus

## Privacy

Your API key is stored in the macOS Keychain and sent only to `api.anthropic.com`. The selected text is sent to Anthropic when you run an action, and nowhere else. Pico makes no other network requests. Read the code; it's short.

## Roadmap

- Voice input: hold the shortcut, speak Hinglish, get text
- Custom shortcut
- Offline local model option
- Recent results history
- Notarized builds

## License

MIT
