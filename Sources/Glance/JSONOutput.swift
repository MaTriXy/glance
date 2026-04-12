import Foundation

/// Codable wrappers for JSON serialization (CGRect isn't Codable)
extension ScreenState {

    /// Full screen state as a JSON string
    public var json: String {
        let obj = ScreenStateOutput(
            app: app,
            bundleId: bundleId,
            window: window,
            captureTimeMs: round(captureTimeMs * 100) / 100,
            elementCount: elementCount,
            estimatedTokens: estimatedTokens,
            prompt: prompt,
            elements: elements.map { $0.jsonElement }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(obj) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

extension UIElement {

    public var jsonElement: UIElementOutput {
        UIElementOutput(
            role: role,
            label: label,
            value: value,
            x: Int(frame.origin.x),
            y: Int(frame.origin.y),
            width: Int(frame.width),
            height: Int(frame.height),
            centerX: Int(center.x),
            centerY: Int(center.y),
            focused: isFocused,
            enabled: isEnabled
        )
    }
}

// MARK: - Codable output types

public struct ScreenStateOutput: Codable {
    let app: String
    let bundleId: String
    let window: String
    let captureTimeMs: Double
    let elementCount: Int
    let estimatedTokens: Int
    let prompt: String
    let elements: [UIElementOutput]
}

public struct UIElementOutput: Codable {
    let role: String
    let label: String?
    let value: String?
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let centerX: Int
    let centerY: Int
    let focused: Bool
    let enabled: Bool
}
