// The Sonnet tasks are stubs until plan tasks B1.6/B1.7 replace their bodies.
// This test pins what other agents build on: the export names and that a
// stub fails as a refundable bad_request (nobody billed it).

import { assertEquals, assertRejects } from "@std/assert";

import { AiError } from "../../_shared/errors.ts";
import { FakeClaude } from "../../_shared/testing/fake_claude.ts";
import * as avoChat from "./avo_chat.ts";
import * as listImport from "./list_import.ts";
import * as mealPhoto from "./meal_photo.ts";

const STUBS = { avo_chat: avoChat, meal_photo: mealPhoto, list_import: listImport };

for (const [name, task] of Object.entries(STUBS)) {
  Deno.test(`${name} stub exports parseInput and handler and answers a refundable bad_request`, async () => {
    const claude = new FakeClaude();
    const input = task.parseInput({ any: "thing" });
    const err = await assertRejects(
      () => task.handler({ userId: "u1", locale: "de", input, claude, isPro: false }),
      AiError,
    );
    assertEquals(err.code, "bad_request");
    assertEquals(err.refundable, true);
    assertEquals(claude.calls.length, 0);
  });
}
