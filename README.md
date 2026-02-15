# Whispr 🎙️

A native macOS menu bar app that turns your speech into clean, formatted text. Press **fn+Space** to start recording, press again to stop — transcribed and formatted text is automatically pasted into whatever you're typing in.

Think [Wispr Flow](https://wispr.com), but open source and DIY.

## How It Works

1. **Press fn+Space** → starts recording from your microphone
2. **Press fn+Space again** → stops recording, sends audio to OpenAI Whisper for transcription
3. **AI formatting** → raw transcript is cleaned up by GPT-4o-mini or Claude (your choice)
4. **Auto-paste** → formatted text is copied to clipboard and pasted into the focused input field

## Screenshots

*Coming soon — menu bar icon changes color when recording (red = recording, orange = processing)*

## Requirements

- **macOS 13.0+** (Ventura or later)
- **Xcode 15+** (for building)
- **OpenAI API key** (required for Whisper transcription)
- **Anthropic API key** (optional, for Claude-based formatting)

## Build & Install

### Option 1: Xcode

1. Clone the repo:
   ```bash
   git clone https://github.com/Swan15/whispr.git
   cd whispr
   ```

2. Open in Xcode:
   ```bash
   open Whispr.xcodeproj
   ```

3. Build and Run (⌘R)

### Option 2: Command Line

```bash
xcodebuild -project Whispr.xcodeproj -scheme Whispr -configuration Release build
```

The built app will be in `build/Release/Whispr.app`. Copy it to `/Applications`.

### Option 3: Quick Build Script

```bash
xcodebuild -project Whispr.xcodeproj \
  -scheme Whispr \
  -configuration Release \
  -derivedDataPath ./build \
  build

# Copy to Applications
cp -r build/Build/Products/Release/Whispr.app /Applications/
```

## Setup

### 1. Grant Permissions

On first launch, you'll need to grant two permissions:

- **Accessibility** → System Settings → Privacy & Security → Accessibility → Add Whispr
  - Required for: fn key detection, auto-paste (Cmd+V simulation)
  
- **Microphone** → System Settings → Privacy & Security → Microphone → Allow Whispr
  - Required for: audio recording

> ⚠️ **If the fn key doesn't work**, check that Whispr is in the Accessibility list and the toggle is ON. You may need to remove and re-add it after rebuilding.

### 2. Add API Keys

1. Click the mic icon in the menu bar
2. Open **Settings** (⌘,)
3. Go to the **API Keys** tab
4. Enter your OpenAI API key (required)
5. Optionally enter an Anthropic API key and select Claude as the formatting provider

### 3. Start Dictating!

- Press **fn+Space** → mic icon turns red (recording)
- Speak your text
- Press **fn+Space** again → icon turns orange (processing) → text is pasted

## Configuration

### System Prompt

Customize how your speech is formatted in **Settings → Formatting**. The default prompt:

> Format this transcribed speech into clean, well-structured text. Fix grammar, remove filler words (um, uh, like), and maintain the speaker's intent. If it's a message, keep it conversational. If it's technical/professional, format appropriately.

### Few-Shot Examples

Teach the formatter your preferences by adding correction examples in **Settings → Examples**:

- **Input**: "um so like I was thinking we should uh meet tomorrow at like 3pm"
- **Output**: "I was thinking we should meet tomorrow at 3pm."

Examples are stored in `~/.whispr/examples.json` and can be edited directly.

### Formatting Provider

Choose between:
- **OpenAI GPT-4o-mini** (default) — fast and cheap
- **Anthropic Claude** — requires separate API key

## Architecture

```
Whispr/Sources/
├── App/
│   ├── WhisprApp.swift          # App entry point, menu bar setup
│   └── AppState.swift           # Central state management, orchestration
├── Audio/
│   └── AudioRecorder.swift      # AVAudioEngine-based recording
├── KeyMonitor/
│   └── KeyMonitorManager.swift  # CGEventTap for fn key detection
├── Transcription/
│   └── WhisperService.swift     # OpenAI Whisper API client
├── Formatting/
│   ├── FormattingProvider.swift  # Protocol + example model
│   ├── OpenAIFormatter.swift    # GPT-4o-mini formatter
│   ├── AnthropicFormatter.swift # Claude formatter
│   └── ExamplesStore.swift      # ~/.whispr/examples.json management
├── Paste/
│   └── ClipboardPaster.swift    # Clipboard + Cmd+V simulation
├── MenuBar/
│   └── StatusBarController.swift # Menu bar icon and dropdown
└── Settings/
    └── SettingsView.swift       # SwiftUI settings window
```

## Technical Notes

### fn Key Detection

The fn key is detected via `CGEventTapCreate` monitoring `flagsChanged` events. The `maskSecondaryFn` flag indicates fn state. This requires Accessibility permissions.

### App Sandbox

The app runs **without** App Sandbox (`com.apple.security.app-sandbox = false`) because:
- `CGEventTap` requires unsandboxed access
- Global key monitoring needs Accessibility permissions
- Auto-paste simulates keyboard events

This means it can't be distributed on the Mac App Store, but works great for personal use.

### Audio Format

Recording uses `AVAudioEngine` capturing linear PCM at the system's default sample rate, saved as WAV. The file is sent to Whisper and deleted after processing.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| fn key not detected | Check Accessibility permission, remove & re-add Whispr |
| "Failed to create event tap" in console | Grant Accessibility access in System Settings |
| No audio recorded | Check Microphone permission in System Settings |
| Transcription fails | Verify OpenAI API key in Settings |
| Auto-paste doesn't work | Check Accessibility permission; try disabling and re-enabling |
| App doesn't appear in menu bar | Check if it's running; look for mic icon in menu bar |

## Roadmap

- [ ] Custom hotkey (not just fn)
- [x] Audio feedback (beep on start/stop)
- [x] Permission checks with user guidance
- [x] Minimum recording duration (discard accidental taps)
- [ ] Transcription history
- [ ] Local Whisper model (no API needed)
- [ ] Streaming transcription
- [ ] Multiple languages

## License

MIT — do whatever you want with it.

## Credits

Built with ❤️ as an open-source alternative to [Wispr Flow](https://wispr.com).
