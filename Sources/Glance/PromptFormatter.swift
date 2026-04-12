import Foundation

/// Converts structured screen state into LLM-optimized text
public struct PromptFormatter {

    public static func format(
        app: String,
        window: String,
        elements: [UIElement],
        focused: UIElement?
    ) -> String {
        var lines: [String] = []

        lines.append("[App: \(app) | Window: \"\(window)\"]")
        lines.append("")

        // Focused element first — most important context
        if let f = focused {
            lines.append("## Focused")
            lines.append(formatElement(f))
            lines.append("")
        }

        // Group elements by category
        let interactive = elements.filter { isInteractive($0) && $0.isFocused == false }
        let inputs = elements.filter { isInput($0) && $0.isFocused == false }
        let content = elements.filter { isContent($0) }

        if !interactive.isEmpty {
            lines.append("## Controls")
            for el in interactive.prefix(60) {
                lines.append(formatElement(el))
            }
            if interactive.count > 60 {
                lines.append("  ... and \(interactive.count - 60) more")
            }
            lines.append("")
        }

        if !inputs.isEmpty {
            lines.append("## Input Fields")
            for el in inputs.prefix(20) {
                lines.append(formatElement(el))
            }
            lines.append("")
        }

        if !content.isEmpty {
            lines.append("## Content")
            for el in content.prefix(40) {
                lines.append(formatElement(el))
            }
            if content.count > 40 {
                lines.append("  ... and \(content.count - 40) more")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Formatting

    private static func formatElement(_ el: UIElement) -> String {
        var parts: [String] = []
        parts.append("[\(el.role)]")

        if let label = el.label {
            parts.append("\"\(label)\"")
        }
        if let value = el.value {
            parts.append("value=\"\(value)\"")
        }
        parts.append("at (\(Int(el.center.x)),\(Int(el.center.y)))")

        if el.isFocused { parts.append("[FOCUSED]") }
        if !el.isEnabled { parts.append("[DISABLED]") }

        return "- " + parts.joined(separator: " ")
    }

    // MARK: - Categorization

    private static func isInteractive(_ el: UIElement) -> Bool {
        ["Button", "Link", "MenuItem", "Tab", "DisclosureTriangle",
         "MenuButton", "PopUpButton"].contains(el.role)
    }

    private static func isInput(_ el: UIElement) -> Bool {
        ["TextField", "TextArea", "SearchField", "SecureTextField",
         "Slider", "Checkbox", "Switch", "RadioButton", "ComboBox",
         "Stepper", "ColorWell", "Incrementor"].contains(el.role)
    }

    private static func isContent(_ el: UIElement) -> Bool {
        ["StaticText", "Heading", "Image", "Cell", "Row"].contains(el.role)
    }
}
