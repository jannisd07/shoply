// Task `list_import` (plan B1.7): a photo of a shopping list -> items.
// The work is in _shared/list_import_core.ts, shared with the old
// extract-shopping-list function.
//
// Model claude-sonnet-5-5, adaptive thinking, effort medium, server-side
// fallback, JSON schema answer, one call (one quota unit) per note.
//
// Input  {image_b64, media_type: "image/jpeg"|"image/png"|"image/webp"}, at most 5 MB as base64
// Result {items: [{name, quantity: number|null, unit: "g"|"kg"|"ml"|"l"|"pack"|"bottle"|"can"|"box"|"bunch"|null,
//                  category_id, confidence: 0..1}], unparsed_lines: [string]}
//        unit null means pieces; confidence below 0.75 means "please check this line".
// Errors unreadable_image (photo not readable, or no JPEG/PNG/WebP), no_items_found (no products on it)

import { type ImageInput, parseImageInput } from "../../_shared/image_input.ts";
import { extractShoppingList } from "../../_shared/list_import_core.ts";
import type { TaskContext, TaskInput, TaskResult } from "./types.ts";

/** Leaves room inside the app's 30 s photo deadline for auth and quota. */
const TIMEOUT_MS = 27_000;

export interface ListImportInput {
  image: ImageInput;
}

export function parseInput(raw: TaskInput): ListImportInput {
  return { image: parseImageInput(raw) };
}

export async function handler(ctx: TaskContext<ListImportInput>): Promise<TaskResult> {
  const { list, usage } = await extractShoppingList(ctx.input.image, {
    client: ctx.claude,
    locale: ctx.locale,
    timeoutMs: TIMEOUT_MS,
  });
  return { result: list, usage };
}
