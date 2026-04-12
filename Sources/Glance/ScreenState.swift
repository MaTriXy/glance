import Foundation
import CoreGraphics

/// Structured representation of everything visible on screen
public struct ScreenState: Sendable {
    public let app: String
    public let bundleId: String
    public let window: String
    public let elements: [UIElement]
    public let focusedElement: UIElement?
    public let captureTimeMs: Double
    public let prompt: String

    public var elementCount: Int { elements.count }
    public var estimatedTokens: Int { max(1, prompt.count / 4) }
    public var estimatedCostCents: Double { Double(estimatedTokens) * 0.000315 }
}

/// A single UI element on screen with exact position and metadata
public struct UIElement: Identifiable, Sendable, Hashable {
    public let id: String
    public let role: String
    public let label: String?
    public let value: String?
    public let frame: CGRect
    public let isFocused: Bool
    public let isEnabled: Bool
    public let depth: Int

    public var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    public var displayName: String {
        label ?? value ?? role
    }

    public var roleIcon: String {
        switch role {
        case "Button":           return "button.programmable"
        case "TextField",
             "SearchField",
             "SecureTextField",
             "TextArea":         return "character.cursor.ibeam"
        case "Link":             return "link"
        case "Slider":           return "slider.horizontal.3"
        case "Checkbox",
             "Switch":           return "checkmark.square"
        case "RadioButton":      return "circle.inset.filled"
        case "PopUpButton",
             "MenuButton":       return "chevron.up.chevron.down"
        case "Image":            return "photo"
        case "StaticText",
             "Heading":          return "textformat"
        case "TabGroup", "Tab":  return "rectangle.split.3x1"
        case "Table":            return "tablecells"
        case "Toolbar":          return "rectangle.topthird.inset.filled"
        case "MenuItem":         return "list.bullet"
        case "Window":           return "macwindow"
        default:                 return "square.dashed"
        }
    }

    public var roleColor: RoleCategory {
        switch role {
        case "Button", "Link", "MenuItem":
            return .interactive
        case "TextField", "SearchField", "SecureTextField", "TextArea", "ComboBox":
            return .input
        case "Slider", "Checkbox", "Switch", "RadioButton", "PopUpButton", "Stepper":
            return .control
        case "StaticText", "Heading", "Image":
            return .content
        default:
            return .structural
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: UIElement, rhs: UIElement) -> Bool {
        lhs.id == rhs.id
    }
}

public enum RoleCategory: Sendable {
    case interactive  // buttons, links
    case input        // text fields
    case control      // sliders, checkboxes
    case content      // static text, headings
    case structural   // groups, areas
}
