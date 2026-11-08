// Photo input of the Sonnet photo tasks (plan B1.7: meal_photo, list_import,
// and the old extract-shopping-list wrapper).
//
// A task input carries {image_b64, media_type}. The checks here run before any
// quota is used: a missing, malformed or oversized photo is bad_request (a
// client bug), well-formed bytes that are no JPEG, PNG or WebP (HEIC, GIF, a
// PDF) are unreadable_image (Claude cannot read them; the person can retry
// with another photo). The magic bytes decide the media type, because the API
// rejects a media_type that does not match the data.
//
// Image data never appears in an error message or a log line.

import type Anthropic from "@anthropic-ai/sdk";

import { AiError } from "./errors.ts";

export const IMAGE_MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
export type ImageMediaType = typeof IMAGE_MEDIA_TYPES[number];

/** Plan B1.1: a photo is at most 5 MB as base64 (the request body allows 6 MB). */
export const MAX_IMAGE_BASE64_CHARS = 5 * 1024 * 1024;

export interface ImageInput {
  /** Base64 without a data: prefix. */
  data: string;
  mediaType: ImageMediaType;
}

const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;
/** 16 base64 characters are the 12 bytes the WebP check needs. */
const SNIFF_CHARS = 16;

function startsWith(bytes: Uint8Array, head: readonly number[], offset = 0): boolean {
  if (bytes.length < offset + head.length) return false;
  return head.every((byte, i) => bytes[offset + i] === byte);
}

const RIFF = [0x52, 0x49, 0x46, 0x46];
const WEBP = [0x57, 0x45, 0x42, 0x50];

/** The type the bytes really have, or null for anything Claude cannot read here. */
export function sniffImageType(bytes: Uint8Array): ImageMediaType | null {
  if (startsWith(bytes, [0xff, 0xd8, 0xff])) return "image/jpeg";
  if (startsWith(bytes, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return "image/png";
  if (startsWith(bytes, RIFF) && startsWith(bytes, WEBP, 8)) return "image/webp";
  return null;
}

function isMediaType(value: unknown): value is ImageMediaType {
  return typeof value === "string" && (IMAGE_MEDIA_TYPES as readonly string[]).includes(value);
}

function headBytes(data: string): Uint8Array {
  return Uint8Array.from(atob(data.slice(0, SNIFF_CHARS)), (c) => c.charCodeAt(0));
}

/** Validates `image_b64` and `media_type` of a task input. */
export function parseImageInput(raw: Record<string, unknown>): ImageInput {
  const data = raw.image_b64;
  if (typeof data !== "string" || data.length === 0) throw new AiError("bad_request", "image_b64: required");
  if (data.length > MAX_IMAGE_BASE64_CHARS) throw new AiError("bad_request", "image_b64: larger than 5 MB");
  if (data.length % 4 !== 0 || !BASE64.test(data)) throw new AiError("bad_request", "image_b64: not base64");
  if (!isMediaType(raw.media_type)) throw new AiError("bad_request", "media_type: expected image/jpeg, png or webp");
  const mediaType = sniffImageType(headBytes(data));
  if (mediaType === null) throw new AiError("unreadable_image", "image is no JPEG, PNG or WebP");
  return { data, mediaType };
}

/** Bytes from storage as a photo for Claude; unreadable_image when too large or of another type. */
export function imageFromBytes(bytes: Uint8Array): ImageInput {
  if (Math.ceil(bytes.length / 3) * 4 > MAX_IMAGE_BASE64_CHARS) {
    throw new AiError("unreadable_image", "image larger than 5 MB as base64");
  }
  const mediaType = sniffImageType(bytes);
  if (mediaType === null) throw new AiError("unreadable_image", "image is no JPEG, PNG or WebP");
  return { data: encodeBase64(bytes), mediaType };
}

/** Standard base64 (with padding), in chunks so large photos do not overflow the call stack. */
export function encodeBase64(bytes: Uint8Array): string {
  const CHUNK = 0x8000;
  let binary = "";
  for (let i = 0; i < bytes.length; i += CHUNK) {
    binary += String.fromCharCode(...bytes.subarray(i, i + CHUNK));
  }
  return btoa(binary);
}

/** The photo as the first block of the user turn (image before text). */
export function imageBlock(image: ImageInput): Anthropic.ImageBlockParam {
  return { type: "image", source: { type: "base64", media_type: image.mediaType, data: image.data } };
}
