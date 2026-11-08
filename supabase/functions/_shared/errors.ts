// Error codes of the `ai` edge function (client contract, plan task B1.1).
//
// Every failure leaves the function as `{code, message, retry_after_s?}` with
// the HTTP status below. `message` is a short localized fallback text; the app
// maps `code` to its own strings. The internal Error message is for our logs
// only and never reaches the response body.

export type Locale = "de" | "en";

export type AiErrorCode =
  | "unauthorized"
  | "bad_request"
  | "quota_exceeded"
  | "rate_limited"
  | "ai_disabled"
  | "refused"
  | "no_items_found"
  | "unreadable_image"
  | "no_food_detected"
  | "provider_error"
  | "timeout";

export const AI_ERROR_STATUS: Readonly<Record<AiErrorCode, number>> = {
  unauthorized: 401,
  bad_request: 400,
  quota_exceeded: 429,
  rate_limited: 429,
  ai_disabled: 503,
  refused: 422,
  no_items_found: 422,
  unreadable_image: 422,
  no_food_detected: 422,
  provider_error: 502,
  timeout: 504,
};

const MESSAGES: Readonly<Record<AiErrorCode, Readonly<Record<Locale, string>>>> = {
  unauthorized: {
    de: "Bitte melde dich erneut an.",
    en: "Please sign in again.",
  },
  bad_request: {
    de: "Diese Anfrage konnte Avo nicht verarbeiten.",
    en: "Avo couldn't process this request.",
  },
  quota_exceeded: {
    de: "Für heute ist das Limit erreicht. Morgen geht es weiter.",
    en: "You've reached today's limit. It resets tomorrow.",
  },
  rate_limited: {
    de: "Gerade ist viel los. Versuch es gleich noch einmal.",
    en: "It's busy right now. Try again in a moment.",
  },
  ai_disabled: {
    de: "Avo ist gerade nicht verfügbar.",
    en: "Avo isn't available right now.",
  },
  refused: {
    de: "Dabei kann Avo nicht helfen.",
    en: "Avo can't help with that.",
  },
  no_items_found: {
    de: "Avo hat darauf keine Artikel gefunden.",
    en: "Avo didn't find any items in that image.",
  },
  unreadable_image: {
    de: "Das Bild war schwer zu lesen. Versuch es mit mehr Licht.",
    en: "That image was hard to read. Try again with more light.",
  },
  no_food_detected: {
    de: "Avo hat darin kein Essen erkannt.",
    en: "Avo didn't recognize any food in that.",
  },
  provider_error: {
    de: "Da ist etwas schiefgelaufen. Versuch es gleich noch einmal.",
    en: "Something went wrong. Try again in a moment.",
  },
  timeout: {
    de: "Das hat zu lange gedauert. Versuch es noch einmal.",
    en: "That took too long. Please try again.",
  },
};

export interface AiErrorOptions {
  /** Seconds the client should wait before retrying (sent as `retry_after_s`). */
  retryAfterS?: number;
  /**
   * True when nobody billed the call (an HTTP error status from the provider,
   * a lost connection, or a task that stopped before calling Claude), so the
   * consumed quota is given back.
   */
  refundable?: boolean;
}

export class AiError extends Error {
  readonly code: AiErrorCode;
  readonly retryAfterS?: number;
  readonly refundable: boolean;

  constructor(code: AiErrorCode, message?: string, options: AiErrorOptions = {}) {
    super(message ?? code);
    this.name = "AiError";
    this.code = code;
    this.retryAfterS = options.retryAfterS;
    this.refundable = options.refundable ?? false;
  }

  get status(): number {
    return AI_ERROR_STATUS[this.code];
  }
}

export interface AiErrorBody {
  code: AiErrorCode;
  message: string;
  retry_after_s?: number;
}

export function userMessage(code: AiErrorCode, locale: Locale): string {
  return MESSAGES[code][locale];
}

export function errorBody(err: AiError, locale: Locale): AiErrorBody {
  const body: AiErrorBody = { code: err.code, message: userMessage(err.code, locale) };
  if (err.retryAfterS !== undefined) body.retry_after_s = err.retryAfterS;
  return body;
}
