const { execFile } = require("child_process");
const path = require("path");

const BINARY = path.join(__dirname, "bin", "glance");

function run(args) {
  return new Promise((resolve, reject) => {
    execFile(BINARY, args, { maxBuffer: 10 * 1024 * 1024 }, (err, stdout, stderr) => {
      if (err) {
        const message = stderr?.trim() || err.message;
        reject(new Error(message));
      } else {
        resolve(stdout);
      }
    });
  });
}

/**
 * Get an LLM-ready text description of the current screen.
 * Drop this directly into your Claude/GPT messages as context.
 *
 * @returns {Promise<string>} LLM-ready screen description with element positions
 *
 * @example
 * const { screen } = require('glance-sdk')
 * const context = await screen()
 * // Send `context` as a text message to Claude — no screenshot needed
 */
async function screen() {
  const output = await run(["screen"]);
  return output.trim();
}

/**
 * Get full structured screen state as JSON.
 *
 * @returns {Promise<Object>} Screen state with app, window, elements, prompt, and metrics
 *
 * @example
 * const { capture } = require('glance-sdk')
 * const state = await capture()
 * console.log(state.app)           // "Safari"
 * console.log(state.elementCount)  // 342
 * console.log(state.captureTimeMs) // 47.2
 * console.log(state.prompt)        // LLM-ready text
 */
async function capture() {
  const output = await run(["screen", "--json"]);
  return JSON.parse(output);
}

/**
 * Find a UI element by name. Returns exact pixel coordinates for pointing/clicking.
 *
 * @param {string} name - The element label or value to search for
 * @returns {Promise<Object|null>} Element with position, or null if not found
 *
 * @example
 * const { find } = require('glance-sdk')
 * const btn = await find("Submit")
 * if (btn) console.log(`Click at (${btn.centerX}, ${btn.centerY})`)
 */
async function find(name) {
  try {
    const output = await run(["find", name]);
    const result = JSON.parse(output);
    return result.found ? result : null;
  } catch {
    return null;
  }
}

/**
 * Check if accessibility permission is granted.
 * @returns {Promise<boolean>}
 */
async function checkAccess() {
  try {
    await run(["check"]);
    return true;
  } catch {
    return false;
  }
}

module.exports = { screen, capture, find, checkAccess };
