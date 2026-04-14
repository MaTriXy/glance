#!/usr/bin/env swift
//
//  Glance SDK Demo — Side-by-side comparison
//  Screenshot mode vs Glance mode, same question, same model
//

import Foundation
import ScreenCaptureKit
import AppKit

// ── Config ──
let API_KEY = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
let MODEL = "claude-sonnet-4-6"
let QUESTION = "How do I find or search for a domain name on this website?"

// ── ANSI colors ──
let BOLD = "\u{1B}[1m"
let DIM = "\u{1B}[2m"
let RESET = "\u{1B}[0m"
let CYAN = "\u{1B}[36m"
let GREEN = "\u{1B}[32m"
let RED = "\u{1B}[31m"
let YELLOW = "\u{1B}[33m"

// ── Glance SDK (inline for demo) ──
func readAccessibilityTree() -> (prompt: String, elementCount: Int, timeMs: Double)? {
    guard AXIsProcessTrusted() else { return nil }

    let start = CFAbsoluteTimeGetCurrent()

    // Get element at mouse cursor position (instead of frontmost app)
    let mouseLocation = NSEvent.mouseLocation
    let screenHeight = NSScreen.main?.frame.height ?? 0
    let flippedY = screenHeight - mouseLocation.y  // Convert from bottom-left to top-left origin

    let systemWide = AXUIElementCreateSystemWide()
    var elementRef: AXUIElement?
    AXUIElementCopyElementAtPosition(systemWide, Float(mouseLocation.x), Float(flippedY), &elementRef)

    // Walk up to find the window and app
    var windowElement: AXUIElement?
    var appElement: AXUIElement?
    var current = elementRef

    while let el = current {
        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        if role == "AXWindow" { windowElement = el }
        if role == "AXApplication" { appElement = el; break }

        var parentRef: AnyObject?
        AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &parentRef)
        current = parentRef as! AXUIElement?
    }

    // Get app name
    var appName = "Unknown"
    if let app = appElement {
        var titleRef: AnyObject?
        AXUIElementCopyAttributeValue(app, kAXTitleAttribute as CFString, &titleRef)
        appName = (titleRef as? String) ?? "Unknown"
    }

    // Get window title
    var windowTitle = "Untitled"
    var windowRef: AnyObject? = windowElement
    if let w = windowRef {
        var titleRef: AnyObject?
        AXUIElementCopyAttributeValue(w as! AXUIElement, kAXTitleAttribute as CFString, &titleRef)
        windowTitle = (titleRef as? String) ?? "Untitled"
    }

    // Walk tree
    var elements: [(role: String, label: String?, value: String?, x: Int, y: Int)] = []

    func walk(_ el: AXUIElement, depth: Int) {
        guard depth < 30 else { return }  // Deeper traversal to reach web content
        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleRef)
        let role = (roleRef as? String) ?? "AXUnknown"

        // Include web content elements: AXWebArea, AXGroup, AXRow, AXCell, AXList, AXListItem
        let dominated = ["AXButton","AXTextField","AXTextArea","AXStaticText","AXLink",
                         "AXSlider","AXCheckBox","AXRadioButton","AXPopUpButton",
                         "AXMenuButton","AXSearchField","AXImage","AXHeading",
                         "AXTabGroup","AXTab","AXToolbar","AXMenuItem","AXSwitch",
                         "AXWebArea","AXGroup","AXRow","AXCell","AXList","AXListItem",
                         "AXTable","AXColumn","AXSection","AXArticle","AXBanner","AXForm"]

        if dominated.contains(role) {
            var labelRef: AnyObject?, descRef: AnyObject?, valRef: AnyObject?
            AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &labelRef)
            AXUIElementCopyAttributeValue(el, kAXDescriptionAttribute as CFString, &descRef)
            AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &valRef)

            let label = (labelRef as? String) ?? (descRef as? String)
            var value = valRef as? String
            if let v = value, v.count > 80 { value = String(v.prefix(80)) + "..." }

            var pos = CGPoint.zero, size = CGSize.zero
            var posRef: AnyObject?, sizeRef: AnyObject?
            AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef)
            AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRef)
            if let p = posRef { AXValueGetValue(p as! AXValue, .cgPoint, &pos) }
            if let s = sizeRef { AXValueGetValue(s as! AXValue, .cgSize, &size) }

            if size.width > 1 && size.height > 1 {
                let clean = role.hasPrefix("AX") ? String(role.dropFirst(2)) : role
                elements.append((clean, label, value, Int(pos.x + size.width/2), Int(pos.y + size.height/2)))
            }
        }

        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &childrenRef)
        if let children = childrenRef as? [AXUIElement] {
            for child in children { walk(child, depth: depth + 1) }
        }
    }

    // Walk from the window we found under the cursor, or fallback to the element itself
    if let w = windowElement {
        walk(w, depth: 0)
    } else if let el = elementRef {
        walk(el, depth: 0)
    }

    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

    // Format prompt
    var lines = ["[App: \(appName) | Window: \"\(windowTitle)\"]", ""]
    for el in elements.prefix(200) {  // More elements to capture web content
        var line = "- [\(el.role)]"
        if let l = el.label, !l.isEmpty { line += " \"\(l)\"" }
        if let v = el.value, !v.isEmpty { line += " value=\"\(v)\"" }
        line += " at (\(el.x),\(el.y))"
        lines.append(line)
    }

    return (lines.joined(separator: "\n"), elements.count, elapsed)
}

// ── Screenshot capture ──
func captureScreenshot() async -> (base64: String, sizeKB: Double, timeMs: Double)? {
    let start = CFAbsoluteTimeGetCurrent()

    guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
          let display = content.displays.first else { return nil }

    let filter = SCContentFilter(display: display, excludingWindows: [])
    let config = SCStreamConfiguration()
    let aspect = CGFloat(display.width) / CGFloat(display.height)
    config.width = 1280
    config.height = Int(1280.0 / aspect)

    guard let cgImage = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config),
          let jpegData = NSBitmapImageRep(cgImage: cgImage).representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    else { return nil }

    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
    let base64 = jpegData.base64EncodedString()
    let sizeKB = Double(jpegData.count) / 1024.0

    return (base64, sizeKB, elapsed)
}

// ── Claude API call ──
func callClaude(messages: [[String: Any]], label: String) async -> (response: String, timeMs: Double)? {
    var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(API_KEY, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.timeoutInterval = 60

    let body: [String: Any] = [
        "model": MODEL,
        "max_tokens": 512,
        "messages": messages
    ]

    guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
    request.httpBody = bodyData

    let start = CFAbsoluteTimeGetCurrent()

    guard let (data, response) = try? await URLSession.shared.data(for: request),
          let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        print("\(RED)  API error for \(label)\(RESET)")
        return nil
    }

    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let content = json["content"] as? [[String: Any]],
          let text = content.first?["text"] as? String else { return nil }

    return (text, elapsed)
}

// ── Main ──
func main() async {
    print("")
    print("\(BOLD)  ┌─────────────────────────────────────────┐\(RESET)")
    print("\(BOLD)  │  Glance SDK — Speed Comparison Demo     │\(RESET)")
    print("\(BOLD)  └─────────────────────────────────────────┘\(RESET)")
    print("")
    print("  \(DIM)Question: \"\(QUESTION)\"\(RESET)")
    print("  \(DIM)Model: \(MODEL)\(RESET)")
    print("")

    // ═══════════════════════════════════════════
    // COUNTDOWN - give user time to position mouse
    // ═══════════════════════════════════════════
    print("  \(YELLOW)⚡ Hover your mouse over the target window!\(RESET)")
    print("")
    for i in (1...3).reversed() {
        print("  \(BOLD)Capturing in \(i)...\(RESET)")
        Thread.sleep(forTimeInterval: 1)
    }
    print("  \(GREEN)📸 Capturing now!\(RESET)")
    print("")

    guard let screenshot = await captureScreenshot() else {
        print("  Failed to capture screenshot")
        return
    }

    guard let glance = readAccessibilityTree() else {
        print("  Failed to read accessibility tree (check accessibility permission)")
        return
    }

    // ═══════════════════════════════════════════
    // TEST 1: Screenshot mode
    // ═══════════════════════════════════════════
    print("  \(RED)━━━ Screenshot Mode ━━━\(RESET)")
    print("")
    print("  \(DIM)Capture:\(RESET)  \(String(format: "%.0f", screenshot.timeMs))ms  (\(String(format: "%.0f", screenshot.sizeKB))KB JPEG)")

    let screenshotMessages: [[String: Any]] = [[
        "role": "user",
        "content": [
            ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": screenshot.base64]],
            ["type": "text", "text": QUESTION]
        ]
    ]]

    let payloadSize = Double((try? JSONSerialization.data(withJSONObject: screenshotMessages))?.count ?? 0) / 1024.0
    print("  \(DIM)Payload:\(RESET) \(String(format: "%.0f", payloadSize))KB sent to Claude")
    print("  \(DIM)Waiting for Claude...\(RESET)")

    guard let screenshotResult = await callClaude(messages: screenshotMessages, label: "screenshot") else {
        print("  \(RED)Screenshot API call failed\(RESET)")
        return
    }

    let screenshotTotal = screenshot.timeMs + screenshotResult.timeMs
    print("  \(DIM)Claude:\(RESET)  \(String(format: "%.0f", screenshotResult.timeMs))ms")
    print("  \(RED)\(BOLD)Total:   \(String(format: "%.0f", screenshotTotal))ms\(RESET)")
    print("")
    print("  \(DIM)Response:\(RESET)")
    let screenshotLines = screenshotResult.response.prefix(500)
    print("  \(DIM)\(screenshotLines)...\(RESET)")

    print("")
    print("")

    // ═══════════════════════════════════════════
    // TEST 2: Glance mode (using pre-captured data)
    // ═══════════════════════════════════════════
    print("  \(GREEN)━━━ Glance Mode ━━━\(RESET)")
    print("")
    print("  \(DIM)Capture:\(RESET)  \(String(format: "%.0f", glance.timeMs))ms  (\(glance.elementCount) elements)")

    let glanceMessages: [[String: Any]] = [[
        "role": "user",
        "content": glance.prompt + "\n\n" + QUESTION
    ]]

    let glancePayload = Double((try? JSONSerialization.data(withJSONObject: glanceMessages))?.count ?? 0) / 1024.0
    print("  \(DIM)Payload:\(RESET) \(String(format: "%.1f", glancePayload))KB sent to Claude")
    print("  \(DIM)Waiting for Claude...\(RESET)")

    guard let glanceResult = await callClaude(messages: glanceMessages, label: "glance") else {
        print("  \(RED)Glance API call failed\(RESET)")
        return
    }

    let glanceTotal = glance.timeMs + glanceResult.timeMs
    print("  \(DIM)Claude:\(RESET)  \(String(format: "%.0f", glanceResult.timeMs))ms")
    print("  \(GREEN)\(BOLD)Total:   \(String(format: "%.0f", glanceTotal))ms\(RESET)")
    print("")
    print("  \(DIM)Response:\(RESET)")
    let glanceLines = glanceResult.response.prefix(500)
    print("  \(DIM)\(glanceLines)...\(RESET)")

    print("")
    print("")

    // ═══════════════════════════════════════════
    // Summary
    // ═══════════════════════════════════════════
    let speedup = screenshotTotal / glanceTotal
    let costRatio = payloadSize / glancePayload

    print("  \(BOLD)━━━ Results ━━━\(RESET)")
    print("")
    print("  \(BOLD)                Screenshot     Glance\(RESET)")
    print("  \(DIM)Capture time    \(String(format: "%5.0f", screenshot.timeMs))ms       \(String(format: "%5.0f", glance.timeMs))ms\(RESET)")
    print("  \(DIM)Payload         \(String(format: "%5.0f", payloadSize))KB       \(String(format: "%5.1f", glancePayload))KB\(RESET)")
    print("  \(DIM)Claude time     \(String(format: "%5.0f", screenshotResult.timeMs))ms       \(String(format: "%5.0f", glanceResult.timeMs))ms\(RESET)")
    print("  \(BOLD)Total           \(String(format: "%5.0f", screenshotTotal))ms       \(String(format: "%5.0f", glanceTotal))ms\(RESET)")
    print("")
    print("  \(GREEN)\(BOLD)⚡ Glance was \(String(format: "%.1f", speedup))× faster\(RESET)")
    print("  \(GREEN)\(BOLD)💰 Glance sent \(String(format: "%.0f", costRatio))× less data\(RESET)")
    print("")
}

// Run
let semaphore = DispatchSemaphore(value: 0)
Task {
    await main()
    semaphore.signal()
}
semaphore.wait()
