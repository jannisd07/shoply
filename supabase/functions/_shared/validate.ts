// Input checks for task inputs. Every failure is an AiError('bad_request');
// the internal message names the field but never repeats the user's text.

import { AiError } from "./errors.ts";

/** Upper bound for any free-text field in a task input (plan B1.1). */
export const MAX_TEXT_CHARS = 4000;

export function requireObject(value: unknown, field: string): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new AiError("bad_request", `${field}: expected an object`);
  }
  return value as Record<string, unknown>;
}

export interface TextOptions {
  max?: number;
}

export function requireText(value: unknown, field: string, options: TextOptions = {}): string {
  const text = optionalText(value, field, options);
  if (text === undefined) throw new AiError("bad_request", `${field}: required`);
  return text;
}

export function optionalText(value: unknown, field: string, options: TextOptions = {}): string | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "string") throw new AiError("bad_request", `${field}: expected a string`);
  const text = value.trim();
  if (text.length === 0) return undefined;
  const max = options.max ?? MAX_TEXT_CHARS;
  if (text.length > max) throw new AiError("bad_request", `${field}: longer than ${max} characters`);
  return text;
}

export interface Bounds {
  min: number;
  max: number;
}

export function requireArray(value: unknown, field: string, bounds: Bounds): unknown[] {
  if (!Array.isArray(value)) throw new AiError("bad_request", `${field}: expected an array`);
  if (value.length < bounds.min || value.length > bounds.max) {
    throw new AiError("bad_request", `${field}: expected ${bounds.min}-${bounds.max} entries, got ${value.length}`);
  }
  return value;
}

export function optionalInt(value: unknown, field: string, bounds: Bounds): number | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "number" || !Number.isInteger(value) || value < bounds.min || value > bounds.max) {
    throw new AiError("bad_request", `${field}: expected an integer ${bounds.min}-${bounds.max}`);
  }
  return value;
}
