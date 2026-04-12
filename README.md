# Glance

**Structured screen understanding for AI apps.**

Every AI screen companion sends a full 2MB screenshot to a vision model on every interaction. It's slow, expensive, and the AI has to *guess* where UI elements are.

Glance reads the macOS accessibility tree instead — giving your AI structured text with every element's role, label, value, and **exact pixel coordinates**. One function call. ~30ms. No screenshots.

## Why

| | Screenshot | Glance |
|---|---|---|
| **Speed** | 2–5 seconds | ~0.8 seconds |
| **Tokens** | ~3,000 (image) | ~500 (text) |
| **Cost** | ~$0.03 / query | ~$0.001 / query |
| **Positions** | AI guesses from pixels | Exact from OS |
| **Upload** | 2MB image to cloud | Nothing — local text |

Text works great for ~70% of interactions (productivity apps, browsers, dev tools). For canvas apps and games, fall back to screenshots. Your AI doesn't need to *see* the screen most of the time — it just needs to *know* what's on it.

## Install

```bash
# JavaScript / TypeScript
npm install glance-sdk

# Python
pip install glance-sdk

# Swift — add to Package.swift
.package(url: "https://github.com/rishabhsai/glance", from: "0.1.0")
```

## Usage

```javascript
import { screen, capture, find } from 'glance-sdk'

// LLM-ready text — drop directly into your prompt
const context = await screen()

// Full structured data
const state = await capture()
console.log(state.app)           // "Safari"
console.log(state.elementCount)  // 342
console.log(state.captureTimeMs) // 47.2

// Find element by name → exact pixel coordinates
const btn = await find('Submit')
console.log(btn.centerX, btn.centerY)  // 520, 340
```

```python
from glance_sdk import screen, capture, find

context = screen()       # LLM-ready text
state = capture()        # full structured data
btn = find("Submit")     # exact position
```

```swift
import Glance

let context = try Glance.screen()         // LLM-ready text
let state = try Glance.capture()          // structured data
let btn = try Glance.find("Submit")       // exact position
print(btn?.center)                        // CGPoint(x: 520, y: 340)
```

## What your LLM receives

Instead of a 2MB image, your AI gets structured text like this (~500 tokens):

```
[App: DaVinci Resolve 19.1 | Window: "Project 1 - Edit"]

## Focused
- [Slider] "Midtones" value=0.32 at (510,390) [FOCUSED]

## Controls
- [Button] "Cut" at (120,42)
- [Button] "Color" at (680,42)
- [PopUpButton] "Node" value="Corrector 1" at (820,42)

## Input Fields
- [Slider] "Lift" value=0.15 at (400,380)
- [Slider] "Gamma" value=-0.08 at (560,380)
- [Slider] "Gain" value=0.22 at (720,380)
```

The coordinates are exact — from the OS, not guessed by a vision model.

## Smart fallback

Some apps don't expose accessibility data. Detect this and fall back:

```javascript
const state = await capture()

if (state.elementCount > 5) {
  // structured text works — fast and cheap
  sendToLLM({ role: 'user', content: state.prompt })
} else {
  // canvas app — fall back to screenshot
  const img = await captureScreenshot()
  sendToLLM({ role: 'user', content: [{ type: 'image', data: img }] })
}
```

## What it works with

**Great for** (full element data): Chrome, Safari, Firefox, Arc, VS Code, Cursor, Slack, Discord, Notion, Terminal, all native macOS apps, all Electron apps, web page content

**Partial** (menus and toolbars, not canvas): DaVinci Resolve, Adobe apps, Figma desktop, Blender

**Use screenshot fallback**: Games, Canvas/WebGL, remote desktop

## CLI

The CLI outputs structured data to stdout — use from any language:

```bash
glance                     # LLM-ready text
glance screen --json       # full JSON
glance find "Submit"       # find element position
glance check               # verify accessibility permission
```

## API

Four functions:

- **`screen()`** → LLM-ready string with all elements and positions
- **`capture()`** → full structured object (app, window, elements, metrics)
- **`find(name)`** → element by label with exact pixel coordinates
- **`checkAccess()`** → boolean, check if accessibility permission is granted

## How it works

Glance reads the macOS accessibility tree (`AXUIElement` API) — the same structured data VoiceOver uses. Every app exposes its UI elements through this tree: buttons, text fields, sliders, links, with their labels, values, states, and positions.

The SDK reads this tree in ~30ms, formats it into LLM-optimized text, and returns it. No screenshots captured, no images uploaded, no vision model needed.

**Permission**: Requires macOS Accessibility permission (System Settings → Privacy & Security → Accessibility). Same permission Clicky and similar tools already need.

## License

MIT
