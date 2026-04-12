"""
Glance SDK — Structured screen understanding for AI apps.

Replace expensive screenshot-to-vision-model pipelines with one line:

    from glance_sdk import screen
    context = screen()  # LLM-ready text, ~50ms, exact element positions

5x faster, 15x cheaper than sending screenshots to vision models.
"""

import json
import os
import subprocess
from typing import Optional

_BINARY = os.path.join(os.path.dirname(__file__), "bin", "glance")


def _run(args: list[str]) -> str:
    result = subprocess.run(
        [_BINARY] + args,
        capture_output=True,
        text=True,
        timeout=10,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "glance command failed")
    return result.stdout


def screen() -> str:
    """Get an LLM-ready text description of the current screen.

    Drop this directly into your Claude/GPT messages as context.
    Returns structured text with every UI element, label, state,
    and exact pixel coordinates.

    Example:
        from glance_sdk import screen

        context = screen()
        # Feed `context` into your LLM prompt as text — no screenshot needed.
    """
    return _run(["screen"]).strip()


def capture() -> dict:
    """Get full structured screen state as JSON.

    Returns:
        dict with keys: app, bundleId, window, captureTimeMs,
        elementCount, estimatedTokens, prompt, elements

    Example:
        from glance_sdk import capture

        state = capture()
        print(state["app"])           # "Safari"
        print(state["elementCount"])  # 342
        print(state["captureTimeMs"]) # 47.2
        print(state["prompt"])        # LLM-ready text
    """
    output = _run(["screen", "--json"])
    return json.loads(output)


def find(name: str) -> Optional[dict]:
    """Find a UI element by name. Returns exact pixel coordinates.

    Args:
        name: Element label or value to search for.

    Returns:
        dict with role, label, centerX, centerY, etc. or None if not found.

    Example:
        from glance_sdk import find

        btn = find("Submit")
        if btn:
            print(f"Click at ({btn['centerX']}, {btn['centerY']})")
    """
    try:
        output = _run(["find", name])
        result = json.loads(output)
        return result if result.get("found") else None
    except (RuntimeError, json.JSONDecodeError):
        return None


def check_access() -> bool:
    """Check if accessibility permission is granted."""
    try:
        _run(["check"])
        return True
    except RuntimeError:
        return False
