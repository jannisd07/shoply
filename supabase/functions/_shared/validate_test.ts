import { assertEquals, assertThrows } from "@std/assert";

import { AiError } from "./errors.ts";
import { MAX_TEXT_CHARS, optionalInt, optionalText, requireArray, requireObject, requireText } from "./validate.ts";

function code(fn: () => unknown): string {
  return assertThrows(fn, AiError).code;
}

Deno.test("requireObject accepts plain objects only", () => {
  assertEquals(requireObject({ a: 1 }, "input"), { a: 1 });
  assertEquals(code(() => requireObject([], "input")), "bad_request");
  assertEquals(code(() => requireObject(null, "input")), "bad_request");
  assertEquals(code(() => requireObject("x", "input")), "bad_request");
});

Deno.test("requireText trims, rejects empty and enforces the 4000 character limit", () => {
  assertEquals(requireText("  Milch ", "name"), "Milch");
  assertEquals(code(() => requireText("   ", "name")), "bad_request");
  assertEquals(code(() => requireText(5, "name")), "bad_request");
  assertEquals(requireText("x".repeat(MAX_TEXT_CHARS), "name").length, MAX_TEXT_CHARS);
  assertEquals(code(() => requireText("x".repeat(MAX_TEXT_CHARS + 1), "name")), "bad_request");
  assertEquals(code(() => requireText("x".repeat(11), "name", { max: 10 })), "bad_request");
});

Deno.test("optionalText returns undefined for missing or blank values", () => {
  assertEquals(optionalText(undefined, "q"), undefined);
  assertEquals(optionalText(null, "q"), undefined);
  assertEquals(optionalText("  ", "q"), undefined);
  assertEquals(optionalText(" 2 l ", "q"), "2 l");
  assertEquals(code(() => optionalText(3, "q")), "bad_request");
});

Deno.test("requireArray enforces its bounds", () => {
  assertEquals(requireArray([1, 2], "items", { min: 1, max: 2 }), [1, 2]);
  assertEquals(code(() => requireArray([], "items", { min: 1, max: 2 })), "bad_request");
  assertEquals(code(() => requireArray([1, 2, 3], "items", { min: 1, max: 2 })), "bad_request");
  assertEquals(code(() => requireArray("x", "items", { min: 0, max: 2 })), "bad_request");
});

Deno.test("optionalInt accepts integers in range", () => {
  assertEquals(optionalInt(undefined, "servings", { min: 1, max: 100 }), undefined);
  assertEquals(optionalInt(4, "servings", { min: 1, max: 100 }), 4);
  assertEquals(code(() => optionalInt(0, "servings", { min: 1, max: 100 })), "bad_request");
  assertEquals(code(() => optionalInt(2.5, "servings", { min: 1, max: 100 })), "bad_request");
  assertEquals(code(() => optionalInt("4", "servings", { min: 1, max: 100 })), "bad_request");
});
