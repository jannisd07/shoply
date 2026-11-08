// Photo input of the Sonnet photo tasks (meal_photo, list_import and the old
// extract-shopping-list wrapper): base64 checks, the 5 MB limit and the real
// image type taken from the bytes.

import { assertEquals, assertThrows } from "@std/assert";

import { AiError } from "./errors.ts";
import {
  encodeBase64,
  imageBlock,
  imageFromBytes,
  MAX_IMAGE_BASE64_CHARS,
  parseImageInput,
  sniffImageType,
} from "./image_input.ts";

function bytesOf(head: number[], length = 64): Uint8Array {
  const bytes = new Uint8Array(length);
  bytes.set(head);
  return bytes;
}

function ascii(text: string): number[] {
  return [...text].map((c) => c.charCodeAt(0));
}

const JPEG = bytesOf([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, ...ascii("JFIF")]);
const PNG = bytesOf([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const WEBP = bytesOf([...ascii("RIFF"), 0x24, 0, 0, 0, ...ascii("WEBPVP8 ")]);
const HEIC = bytesOf([0, 0, 0, 0x18, ...ascii("ftypheic")]);
const GIF = bytesOf(ascii("GIF89a"));
const PDF = bytesOf(ascii("%PDF-1.7"));

Deno.test("sniffImageType reads JPEG, PNG and WebP from the bytes and nothing else", () => {
  assertEquals(sniffImageType(JPEG), "image/jpeg");
  assertEquals(sniffImageType(PNG), "image/png");
  assertEquals(sniffImageType(WEBP), "image/webp");
  assertEquals(sniffImageType(HEIC), null);
  assertEquals(sniffImageType(GIF), null);
  assertEquals(sniffImageType(PDF), null);
  assertEquals(sniffImageType(new Uint8Array([0xff, 0xd8])), null);
  // RIFF alone is not enough (WAV and AVI are RIFF too).
  assertEquals(sniffImageType(bytesOf([...ascii("RIFF"), 0, 0, 0, 0, ...ascii("WAVE")])), null);
});

Deno.test("encodeBase64 matches btoa and round-trips large photos", () => {
  assertEquals(encodeBase64(new Uint8Array([])), "");
  assertEquals(encodeBase64(new Uint8Array([0, 1, 2, 250, 255])), btoa(String.fromCharCode(0, 1, 2, 250, 255)));
  const big = new Uint8Array(300_001).map((_, i) => (i * 31) % 256);
  const decoded = Uint8Array.from(atob(encodeBase64(big)), (c) => c.charCodeAt(0));
  assertEquals(decoded, big);
});

Deno.test("parseImageInput accepts a JPEG, PNG or WebP photo as base64", () => {
  assertEquals(parseImageInput({ image_b64: encodeBase64(JPEG), media_type: "image/jpeg" }), {
    data: encodeBase64(JPEG),
    mediaType: "image/jpeg",
  });
  assertEquals(parseImageInput({ image_b64: encodeBase64(PNG), media_type: "image/png" }).mediaType, "image/png");
  assertEquals(parseImageInput({ image_b64: encodeBase64(WEBP), media_type: "image/webp" }).mediaType, "image/webp");
});

Deno.test("parseImageInput trusts the bytes when the declared type is another supported one", () => {
  // The API rejects a media_type that does not match the data; the bytes win.
  assertEquals(parseImageInput({ image_b64: encodeBase64(PNG), media_type: "image/jpeg" }).mediaType, "image/png");
});

Deno.test("parseImageInput answers bad_request for a missing, malformed or oversized photo", () => {
  const oversized = "A".repeat(MAX_IMAGE_BASE64_CHARS + 4);
  const bad: Array<Record<string, unknown>> = [
    {},
    { media_type: "image/jpeg" },
    { image_b64: "", media_type: "image/jpeg" },
    { image_b64: 42, media_type: "image/jpeg" },
    { image_b64: encodeBase64(JPEG) },
    { image_b64: encodeBase64(JPEG), media_type: "image/heic" },
    { image_b64: encodeBase64(JPEG), media_type: "image/gif" },
    { image_b64: `data:image/jpeg;base64,${encodeBase64(JPEG)}`, media_type: "image/jpeg" },
    { image_b64: `${encodeBase64(JPEG)}\n`, media_type: "image/jpeg" },
    { image_b64: "abc", media_type: "image/jpeg" },
    { image_b64: oversized, media_type: "image/jpeg" },
  ];
  for (const raw of bad) {
    const err = assertThrows(() => parseImageInput(raw), AiError);
    assertEquals(err.code, "bad_request", JSON.stringify(raw).slice(0, 80));
    assertEquals(err.message.includes(encodeBase64(JPEG)), false, "the photo never appears in an error");
  }
});

Deno.test("parseImageInput accepts exactly 5 MB of base64", () => {
  // 63 bytes encode without padding, so more base64 can follow.
  const head = encodeBase64(JPEG.subarray(0, 63));
  const atLimit = head + "A".repeat(MAX_IMAGE_BASE64_CHARS - head.length);
  assertEquals(parseImageInput({ image_b64: atLimit, media_type: "image/jpeg" }).data.length, MAX_IMAGE_BASE64_CHARS);
  assertEquals(MAX_IMAGE_BASE64_CHARS, 5 * 1024 * 1024);
});

Deno.test("parseImageInput answers unreadable_image for well-formed base64 that is no supported photo", () => {
  for (const bytes of [HEIC, GIF, PDF, new Uint8Array(3)]) {
    const err = assertThrows(
      () => parseImageInput({ image_b64: encodeBase64(bytes), media_type: "image/jpeg" }),
      AiError,
    );
    assertEquals(err.code, "unreadable_image");
  }
});

Deno.test("imageFromBytes encodes a stored photo and rejects what Claude cannot read", () => {
  assertEquals(imageFromBytes(PNG), { data: encodeBase64(PNG), mediaType: "image/png" });
  for (const bytes of [HEIC, new Uint8Array(0)]) {
    assertEquals(assertThrows(() => imageFromBytes(bytes), AiError).code, "unreadable_image");
  }
  // 4 MB of bytes is about 5.3 MB of base64: over the limit.
  const big = new Uint8Array(4 * 1024 * 1024);
  big.set(JPEG);
  assertEquals(assertThrows(() => imageFromBytes(big), AiError).code, "unreadable_image");
});

Deno.test("imageBlock is a base64 image block for the user turn", () => {
  assertEquals(imageBlock({ data: "abcd", mediaType: "image/webp" }), {
    type: "image",
    source: { type: "base64", media_type: "image/webp", data: "abcd" },
  });
});
