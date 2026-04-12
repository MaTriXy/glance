export interface UIElement {
  role: string;
  label: string | null;
  value: string | null;
  x: number;
  y: number;
  width: number;
  height: number;
  centerX: number;
  centerY: number;
  focused: boolean;
  enabled: boolean;
}

export interface ScreenState {
  app: string;
  bundleId: string;
  window: string;
  captureTimeMs: number;
  elementCount: number;
  estimatedTokens: number;
  prompt: string;
  elements: UIElement[];
}

export interface FindResult extends UIElement {
  found: true;
}

/**
 * Get an LLM-ready text description of the current screen.
 * Drop this directly into your Claude/GPT messages.
 */
export function screen(): Promise<string>;

/**
 * Get full structured screen state as JSON.
 */
export function capture(): Promise<ScreenState>;

/**
 * Find a UI element by name. Returns exact pixel coordinates.
 */
export function find(name: string): Promise<FindResult | null>;

/**
 * Check if accessibility permission is granted.
 */
export function checkAccess(): Promise<boolean>;
