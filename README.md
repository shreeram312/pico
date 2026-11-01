# Pico

A tiny popup for the text you select, in any Mac app. Fix it, translate it, make it formal, or flip Hinglish / Tenglish / Tanglish between English letters and native script, with one shortcut.

Select text → **⌃⌥ Space** → pick an action → **⏎** replaces it in place.

- Works everywhere: WhatsApp Web, Mail, Slack, Notion, VS Code, Safari…
- Built for Indian languages: understands romanized Hindi, Marathi, Telugu, Tamil, Kannada and more, and keeps them romanized unless you ask to change script
- Actions: Fix · To native script · To romanized · To English · To my language · Formal · Shorter · Draft reply · Explain · your own custom actions
- Bring your own API key: **Anthropic (Claude), OpenAI, Grok (xAI), Gemini**, or any OpenAI-compatible server (Ollama, LM Studio, OpenRouter…). Keys live in your Mac's Keychain. Pico has **no server, no accounts, no analytics**; requests go straight to the provider you chose.
- Open source (MIT), menu bar only, ~2 MB

## Install

1. Download the latest `Pico-x.y.z.dmg` from [Releases](../../releases) and drag Pico to Applications.
2. First launch: **right-click Pico → Open → Open**. (Pico isn't notarized by Apple yet, so macOS warns once. If you see "damaged", run `xattr -dr com.apple.quarantine /Applications/Pico.app`.)
3. Allow **Accessibility** when asked (System Settings → Privacy & Security → Accessibility). Pico needs it to read the selected text and replace it.
4. Open Settings from the menu bar icon, pick a provider, paste its API key ([Anthropic](https://platform.claude.com/settings/keys) · [OpenAI](https://platform.openai.com/api-keys) · [xAI](https://console.x.ai) · [Gemini](https://aistudio.google.com/apikey)), and choose your language.

### Providers

| Provider       | Default model      | Notes                                                                                                       |
| -------------- | ------------------ | ----------------------------------------------------------------------------------------------------------- |
| Anthropic      | `claude-opus-5-5`  | Native Messages API, streaming, low effort for speed                                                        |
| OpenAI         | `gpt-6.1-sol`      | Chat completions                                                                                            |
| Grok (xAI)     | `grok-4.7`         | OpenAI-compatible endpoint                                                                                  |
| Gemini         | `gemini-3.8-flash` | Google's OpenAI-compatible endpoint                                                                         |
| Custom / local | `gemma3:4b`        | Any OpenAI-compatible base URL, e.g. `http://localhost:11434/v1` for Ollama (no key needed). Fully offline. You run the model server yourself: `brew install ollama && brew services start ollama && ollama pull gemma3:4b`. Gemma 3 and Qwen 3 handle Indic languages far better than Llama. |

The model field accepts any model id, so new models work without an app update.

Or with Homebrew (once the tap is published):

```bash
brew install --cask shreeram312/tap/pico
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

- `HotKey.swift`: global ⌃⌥ Space via the Carbon hotkey API
- `SelectionService.swift`: reads the selection through the Accessibility API, falling back to a simulated ⌘C; replaces via Accessibility or a simulated ⌘V, restoring your clipboard
- `Provider.swift` / `LLMClient.swift` / `ClaudeClient.swift`: provider list, the OpenAI-compatible streaming client (OpenAI, xAI, Gemini, local servers) and the native Claude client
- `Actions.swift`: the built-in actions and the shared system prompt
- `PopupController.swift` / `PopupView.swift`: a non-activating floating panel, so the app you're typing in keeps focus

## Privacy

Your API keys are stored in the macOS Keychain and sent only to the provider you selected. The selected text is sent to that provider when you run an action, and nowhere else. With a local server (Ollama) nothing leaves your Mac at all. Pico makes no other network requests. Read the code; it's short.

## Roadmap

- Voice input: hold the shortcut, speak Hinglish, get text
- Custom shortcut
- Recent results history
- Notarized builds

## License

MIT
