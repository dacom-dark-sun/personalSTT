# personalSTT

> Ultra-lightweight macOS menu-bar push-to-talk dictation — hold a key, talk, release, the text appears in the focused input field.

Native Swift + AppKit. Single binary, no Electron, no npm, no services. Transcription via OpenAI Whisper (`whisper-1`).

## Features

- **Two dictation modes**:
  - **Hold** — hold **Right ⌥** to record; release to transcribe and type.
  - **Toggle** — press **Right ⌘ + Right ⌥** together to start a hands-free session; recording continues after you release the keys. Press **Right ⌥** again to stop.
- **Types into the active input of any app** (browser, Slack, terminal, Notes…) via synthesized keyboard events. No clipboard pollution.
- **Audio feedback**: start/stop system sounds.
- **Visual feedback**: floating overlay on top of all windows with a pulsing red dot and elapsed timer.
- **Menu-bar resident** (🎙), no Dock icon, no window chrome.
- **Tiny**: one Swift binary, zero dependencies outside the macOS SDK.

## Requirements

- macOS 13+
- Swift 5.9+ (Xcode CLT is enough: `xcode-select --install`)
- An OpenAI API key with Whisper access

## Install

```bash
git clone https://github.com/dacom-dark-sun/personalSTT.git
cd personalSTT
./build.sh
open build/personal-stt.app
```

On first launch macOS will ask for three permissions — all required:

| Permission | Why |
|---|---|
| **Microphone** | to record you |
| **Input Monitoring** | to see the hotkey when the app isn't focused |
| **Accessibility** | to type the transcribed text into other apps |

If a prompt doesn't appear automatically, grant manually in *System Settings → Privacy & Security*.

## Config

Open *🎙 → Settings…* (⌘,) to edit. All values are saved to `~/.config/personal-stt/config.json` (chmod 600).

For scripted setup, the file format is:

```json
{
  "api_key": "sk-...",
  "base_url": "https://api.openai.com/v1",
  "model": "whisper-1",
  "language": "ru"
}
```

Env vars (read at launch only, overridden by Settings edits that save to the file):

| env var | json key | default |
|---|---|---|
| `OPENAI_API_KEY` | `api_key` | — (required) |
| `OPENAI_BASE_URL` | `base_url` | `https://api.openai.com/v1` |
| `OPENAI_WHISPER_MODEL` | `model` | `whisper-1` |
| `OPENAI_WHISPER_LANGUAGE` | `language` | `ru` |

`base_url` can point to any OpenAI-compatible endpoint (your own proxy, Azure OpenAI, etc.).

Hotkeys are fixed (Right ⌥ hold / Right ⌘+⌥ toggle) — not configurable.

## Usage

1. Launch the app (🎙 appears in the menu bar).
2. Focus any input in any app.

**Hold mode** — quick dictation:
- Hold **Right ⌥**. A "Tink" sound plays, a red `● REC  00:00` overlay appears.
- Speak.
- Release. A "Pop" sound plays, the overlay disappears, the transcribed text is typed into the focused input a moment later.

**Toggle mode** — long, hands-free sessions:
- Press **Right ⌘ + Right ⌥** together. Recording starts.
- Release both keys — recording continues.
- Press **Right ⌥** again (alone) to stop. Transcription is typed into whatever you've focused by then.

## Autostart on login

Open *🎙 → Settings…* and tick **Launch at login**. The app is registered via `SMAppService` (macOS 13+) and appears in *System Settings → General → Login Items*, where you can also toggle it manually.

## How it works

```
┌────────────────────────────────────────────────────────────┐
│  NSApplication (menu-bar, LSUIElement)                     │
│                                                            │
│  Hotkey (CGEventTap, flagsChanged)                         │
│     ├─ modifier down → AudioCapture.start()                │
│     │                  Sounds.start() + Overlay.show()     │
│     └─ modifier up   → AudioCapture.stop() → WAV Data      │
│                         Sounds.stop() + Overlay.hide()     │
│                         Transcriber.transcribe(wav) ──┐    │
│                                                       │    │
│  AudioCapture: AVAudioEngine + AVAudioConverter       │    │
│    input device → 16 kHz mono Int16 PCM → WAV buffer  │    │
│                                                       ▼    │
│  Transcriber: POST {base_url}/audio/transcriptions         │
│    multipart: file=audio.wav, model, language, text        │
│                                                       │    │
│  TextInjector (on success):                           ▼    │
│    CGEvent.keyboardSetUnicodeString via .cghidEventTap     │
│    → focused input of the frontmost app (no clipboard)     │
└────────────────────────────────────────────────────────────┘
```

Project layout:

```
Package.swift              SwiftPM manifest (macOS 13+ executable)
Info.plist                 LSUIElement, mic usage string
build.sh                   swift build -c release + .app bundle + ad-hoc codesign
Sources/PersonalSTT/
  App.swift                NSApplicationDelegate, status item, lifecycle
  Settings.swift           Settings window (NSGridView form)
  Config.swift             env + ~/.config/personal-stt/config.json
  Hotkey.swift             CGEventTap push-to-talk (modifier-only hold)
  AudioCapture.swift       AVAudioEngine → 16 kHz mono Int16 → WAV
  Transcriber.swift        Whisper API multipart POST
  TextInjector.swift       CGEvent.keyboardSetUnicodeString
  Overlay.swift            Borderless NSWindow on .screenSaver level
  Sounds.swift             NSSound Tink/Pop/Basso
```

## Debug / logs

All runtime info is emitted via `NSLog` with a `personal-stt:` prefix.

**Option A — run from terminal (easiest, see logs live):**
```bash
./build/personal-stt.app/Contents/MacOS/PersonalSTT
```
stdout/stderr stream right into the terminal.

**Option B — `log stream`:**
```bash
log stream --predicate 'eventMessage CONTAINS "personal-stt"' --info
```

**Option C — Console.app:**
*Menu bar 🎙 → Open Console (live logs)* — then filter by `personal-stt`.

## Troubleshooting

- **Hotkey does nothing** — check *System Settings → Privacy & Security → Input Monitoring*. The `.app` must be listed and enabled. After granting, relaunch the app.
- **Text doesn't appear in the focused field** — *Privacy & Security → Accessibility* must be enabled for the app. After granting, **fully quit and relaunch** (TCC caches the old trust decision per process).
- **"OPENAI_API_KEY not set" notification** — key wasn't loaded. If you set it only in your shell rc, launching from Finder won't see it; put it in `~/.config/personal-stt/config.json` instead.
- **Whisper HTTP 401/403** — bad key or the key lacks audio access.
- **No sound on start/stop** — your system alert sound is muted (*System Settings → Sound*).

## Contributing

PRs and issues welcome. The codebase is small on purpose — new features should be weighed against the "mini" ethos. Opinionated on what it shouldn't do:

- No clipboard writes.
- No bundled UI toolkits.
- No background network activity other than the per-utterance Whisper call.

## License

MIT — see [LICENSE](LICENSE).
