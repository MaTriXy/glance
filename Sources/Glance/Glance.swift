import Foundation
import AppKit

/// Glance SDK — structured screen understanding for AI companions.
///
/// Replace expensive screenshot-to-vision-model pipelines with one line:
///
///     let prompt = try Glance.screen()
///
/// Returns an LLM-ready string with every UI element, its label, state, and
/// **exact pixel coordinates** — 5× faster, 15× cheaper than sending screenshots.
public enum Glance {

    // MARK: - Quick API (what 90% of users need)

    /// Get an LLM-ready text description of the current screen.
    ///
    ///     let prompt = try Glance.screen()
    ///     // Feed `prompt` directly into your Claude/GPT messages as text.
    ///
    public static func screen() throws -> String {
        try capture().prompt
    }

    /// Get the full structured screen state.
    ///
    ///     let state = try Glance.capture()
    ///     print(state.app)           // "Safari"
    ///     print(state.elementCount)  // 342
    ///     print(state.captureTimeMs) // 47.2
    ///     print(state.prompt)        // LLM-ready text
    ///
    public static func capture() throws -> ScreenState {
        guard AccessibilityReader.hasPermission else {
            AccessibilityReader.ensurePermission()
            throw GlanceError.permissionRequired
        }
        guard let state = AccessibilityReader.captureFrontmost() else {
            throw GlanceError.noApp
        }
        return state
    }

    /// Capture a specific app by process ID.
    public static func capture(pid: pid_t) throws -> ScreenState {
        guard AccessibilityReader.hasPermission else {
            AccessibilityReader.ensurePermission()
            throw GlanceError.permissionRequired
        }
        guard let state = AccessibilityReader.capture(pid: pid) else {
            throw GlanceError.noApp
        }
        return state
    }

    // MARK: - Element lookup (for pointing / clicking)

    /// Find a UI element by name. Returns exact coordinates for Clicky-style pointing.
    ///
    ///     if let btn = try Glance.find("Submit") {
    ///         print(btn.center) // CGPoint(x: 520, y: 340) — exact position
    ///     }
    ///
    public static func find(_ name: String) throws -> UIElement? {
        let state = try capture()
        return state.elements.first {
            $0.label?.localizedCaseInsensitiveContains(name) == true
            || $0.value?.localizedCaseInsensitiveContains(name) == true
        }
    }

    /// Find all elements matching a role (e.g. "Button", "TextField").
    public static func findAll(role: String) throws -> [UIElement] {
        let state = try capture()
        return state.elements.filter { $0.role == role }
    }

    // MARK: - Permission check

    /// Check if accessibility permission is granted. Prompts the user if not.
    @discardableResult
    public static func requestAccess() -> Bool {
        AccessibilityReader.ensurePermission()
    }

    /// Check permission status without prompting.
    public static var hasAccess: Bool {
        AccessibilityReader.hasPermission
    }
}

// MARK: - Errors

public enum GlanceError: Error, LocalizedError {
    case permissionRequired
    case noApp

    public var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return "Accessibility permission required. Enable in System Settings → Privacy & Security → Accessibility."
        case .noApp:
            return "Could not read the frontmost application."
        }
    }
}
