import Foundation
import Glance

// MARK: - CLI entry point

let args = CommandLine.arguments.dropFirst() // drop executable name
let command = args.first ?? "screen"
let flags = Set(args.dropFirst())

func printUsage() {
    let usage = """
    glance — structured screen understanding for AI

    Usage:
      glance screen              LLM-ready text of current screen (default)
      glance screen --json       Full structured JSON output
      glance find "Submit"       Find element by name, return position
      glance elements            List all elements as JSON
      glance check               Check accessibility permission status

    Options:
      --json                     Output as JSON instead of text
      --compact                  Compact JSON (no pretty-printing)
      --help                     Show this help

    Examples:
      glance                     # Quick screen context for an LLM
      glance screen --json       # Full structured data
      glance find "Send"         # Get exact coordinates of "Send" button

    """
    print(usage)
}

func exitError(_ message: String) -> Never {
    fputs("error: \(message)\n", stderr)
    exit(1)
}

// MARK: - Permission check

func ensureAccess() {
    guard Glance.hasAccess else {
        Glance.requestAccess()
        exitError(
            "Accessibility permission required.\n"
            + "Grant access in: System Settings → Privacy & Security → Accessibility\n"
            + "Then run this command again."
        )
    }
}

// MARK: - Commands

switch command {
case "--help", "-h", "help":
    printUsage()

case "check":
    if Glance.hasAccess {
        print("✓ Accessibility permission granted")
    } else {
        print("✗ Accessibility permission not granted")
        print("  Grant access in: System Settings → Privacy & Security → Accessibility")
        exit(1)
    }

case "screen", "--json":
    // `glance` with no args, or `glance screen`, or `glance --json`
    ensureAccess()
    do {
        let state = try Glance.capture()
        if flags.contains("--json") || command == "--json" {
            print(state.json)
        } else {
            print(state.prompt)
            fputs("\n--- \(state.elementCount) elements in \(String(format: "%.1f", state.captureTimeMs))ms | ~\(state.estimatedTokens) tokens ---\n", stderr)
        }
    } catch {
        exitError(error.localizedDescription)
    }

case "find":
    ensureAccess()
    guard let name = args.dropFirst().first else {
        exitError("Usage: glance find \"element name\"")
    }
    do {
        if let element = try Glance.find(name) {
            let output: [String: Any] = [
                "found": true,
                "role": element.role,
                "label": element.label as Any,
                "centerX": Int(element.center.x),
                "centerY": Int(element.center.y),
                "x": Int(element.frame.origin.x),
                "y": Int(element.frame.origin.y),
                "width": Int(element.frame.width),
                "height": Int(element.frame.height),
            ]
            if let data = try? JSONSerialization.data(
                withJSONObject: output,
                options: [.prettyPrinted, .sortedKeys]
            ) {
                print(String(data: data, encoding: .utf8) ?? "{}")
            }
        } else {
            print("{\"found\": false}")
            exit(1)
        }
    } catch {
        exitError(error.localizedDescription)
    }

case "elements":
    ensureAccess()
    do {
        let state = try Glance.capture()
        let elements = state.elements.map { $0.jsonElement }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(elements) {
            print(String(data: data, encoding: .utf8) ?? "[]")
        }
    } catch {
        exitError(error.localizedDescription)
    }

default:
    // If the first arg doesn't match a command, treat it as `glance screen`
    ensureAccess()
    do {
        let state = try Glance.capture()
        print(state.prompt)
        fputs("\n--- \(state.elementCount) elements in \(String(format: "%.1f", state.captureTimeMs))ms | ~\(state.estimatedTokens) tokens ---\n", stderr)
    } catch {
        exitError(error.localizedDescription)
    }
}
