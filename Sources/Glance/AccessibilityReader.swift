import Foundation
import ApplicationServices
import AppKit

/// Core engine that reads the macOS accessibility tree
public final class AccessibilityReader {

    /// Prompt the system accessibility permission dialog if needed
    @discardableResult
    public static func ensurePermission() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Check permission without prompting
    public static var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    // MARK: - Public capture

    /// Read the full UI tree of the frontmost application
    public static func captureFrontmost() -> ScreenState? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return capture(app: app)
    }

    /// Read the full UI tree of a specific running application
    public static func capture(pid: pid_t) -> ScreenState? {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        return capture(app: app)
    }

    /// Read the full UI tree of a specific NSRunningApplication
    public static func capture(app runningApp: NSRunningApplication) -> ScreenState? {
        let start = CFAbsoluteTimeGetCurrent()

        let pid = runningApp.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        let appName = runningApp.localizedName ?? "Unknown"
        let bundleId = runningApp.bundleIdentifier ?? "unknown"

        // Focused window
        let windowTitle = axAttribute(axApp, kAXFocusedWindowAttribute)
            .flatMap { axStringAttribute($0, kAXTitleAttribute) }
            ?? axAttribute(axApp, kAXMainWindowAttribute)
                .flatMap { axStringAttribute($0, kAXTitleAttribute) }
            ?? "Untitled"

        // Walk the tree from the focused window (or first window)
        let rootWindow: AXUIElement? =
            axAttribute(axApp, kAXFocusedWindowAttribute).map { $0 as! AXUIElement }
            ?? axAttribute(axApp, kAXMainWindowAttribute).map { $0 as! AXUIElement }

        var flatElements: [UIElement] = []
        if let root = rootWindow {
            collectElements(root, depth: 0, maxDepth: 12, into: &flatElements)
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000 // ms

        let focused = flatElements.first(where: \.isFocused)

        let prompt = PromptFormatter.format(
            app: appName,
            window: windowTitle,
            elements: flatElements,
            focused: focused
        )

        return ScreenState(
            app: appName,
            bundleId: bundleId,
            window: windowTitle,
            elements: flatElements,
            focusedElement: focused,
            captureTimeMs: elapsed,
            prompt: prompt
        )
    }

    // MARK: - Tree traversal

    private static let meaningfulRoles: Set<String> = [
        "AXButton", "AXTextField", "AXTextArea", "AXStaticText", "AXLink",
        "AXSlider", "AXCheckBox", "AXRadioButton", "AXPopUpButton",
        "AXMenuButton", "AXComboBox", "AXSearchField", "AXSecureTextField",
        "AXImage", "AXHeading", "AXTabGroup", "AXTab", "AXTable",
        "AXOutline", "AXList", "AXMenuItem", "AXToolbar", "AXSwitch",
        "AXStepper", "AXDisclosureTriangle", "AXCell", "AXRow",
        "AXColorWell", "AXIncrementor", "AXWindow", "AXWebArea",
    ]

    private static func collectElements(
        _ element: AXUIElement,
        depth: Int,
        maxDepth: Int,
        into result: inout [UIElement]
    ) {
        guard depth < maxDepth else { return }

        let role = axString(element, kAXRoleAttribute) ?? "AXUnknown"

        // Determine if this element is worth reporting
        let isMeaningful = meaningfulRoles.contains(role)

        if isMeaningful {
            let label = axString(element, kAXTitleAttribute)
                ?? axString(element, kAXDescriptionAttribute)
            let rawValue = axString(element, kAXValueAttribute)
            let value: String? = {
                guard let v = rawValue else { return nil }
                if role == "AXSecureTextField" { return "********" }
                return v.count > 120 ? String(v.prefix(120)) + "..." : v
            }()

            let frame = axFrame(element)
            let isFocused = axBool(element, kAXFocusedAttribute)
            let isEnabled = axBool(element, kAXEnabledAttribute) ?? true

            // Only include elements that have some size on screen
            if frame.width > 1 && frame.height > 1 {
                let cleanRole = role.hasPrefix("AX") ? String(role.dropFirst(2)) : role
                let el = UIElement(
                    id: "\(depth)-\(result.count)-\(cleanRole)-\(label ?? "")",
                    role: cleanRole,
                    label: label?.isEmpty == true ? nil : label,
                    value: value?.isEmpty == true ? nil : value,
                    frame: frame,
                    isFocused: isFocused ?? false,
                    isEnabled: isEnabled,
                    depth: depth
                )
                result.append(el)
            }
        }

        // Always recurse into children
        guard let children = axAttribute(element, kAXChildrenAttribute) as? [AXUIElement] else {
            return
        }
        for child in children {
            collectElements(child, depth: depth + 1, maxDepth: maxDepth, into: &result)
        }
    }

    // MARK: - AX helpers

    private static func axAttribute(_ el: AXUIElement, _ attr: String) -> AnyObject? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(el, attr as CFString, &value)
        return err == .success ? value : nil
    }

    private static func axString(_ el: AXUIElement, _ attr: String) -> String? {
        axAttribute(el, attr) as? String
    }

    private static func axStringAttribute(_ el: AnyObject, _ attr: String) -> String? {
        // swiftlint:disable:next force_cast
        let axEl = el as! AXUIElement
        return axString(axEl, attr)
    }

    private static func axBool(_ el: AXUIElement, _ attr: String) -> Bool? {
        axAttribute(el, attr) as? Bool
    }

    private static func axFrame(_ el: AXUIElement) -> CGRect {
        var pos = CGPoint.zero
        var size = CGSize.zero

        if let posRef = axAttribute(el, kAXPositionAttribute) {
            // AXValue wrapping a CGPoint
            AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
        }
        if let sizeRef = axAttribute(el, kAXSizeAttribute) {
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        }
        return CGRect(origin: pos, size: size)
    }
}
