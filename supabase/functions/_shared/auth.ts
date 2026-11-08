// Caller identity for the `ai` function: the app's Supabase JWT, checked with
// auth.getUser() against SUPABASE_URL + SUPABASE_ANON_KEY (plan B1.1).
// Anonymous users are rejected: a throwaway account would otherwise get a
// fresh free quota every time.
//
// The Supabase gateway checks the JWT too (verify_jwt) and answers an expired
// token with its own 401 body; the app treats every HTTP 401 as
// `unauthorized`, whatever the body says.

import { createClient } from "@supabase/supabase-js";

import { AiError } from "./errors.ts";

export interface AuthClient {
  auth: {
    getUser(): PromiseLike<{ data: { user: { id: string; is_anonymous?: boolean } | null }; error: unknown }>;
  };
}

export interface AuthClientOptions {
  global: { headers: { Authorization: string } };
  auth: { persistSession: false; autoRefreshToken: false };
}

export type AuthClientFactory = (url: string, anonKey: string, options: AuthClientOptions) => AuthClient;

export interface AuthEnv {
  url: string;
  anonKey: string;
  createClient: AuthClientFactory;
}

export function defaultAuthEnv(): AuthEnv {
  return {
    url: Deno.env.get("SUPABASE_URL") ?? "",
    anonKey: Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    createClient: (url, anonKey, options) => createClient(url, anonKey, options),
  };
}

/** A failed lookup that says nothing about the token (auth server unreachable). */
function isTransient(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const { name, status } = error as { name?: unknown; status?: unknown };
  return name === "AuthRetryableFetchError" || (typeof status === "number" && status >= 500);
}

/** The caller's user id. Throws AiError('unauthorized'), or provider_error when auth is down. */
export async function getUserId(req: Request, env: AuthEnv = defaultAuthEnv()): Promise<string> {
  const match = /^Bearer\s+(\S+)\s*$/i.exec(req.headers.get("Authorization") ?? "");
  if (!match) throw new AiError("unauthorized", "missing bearer token");

  let result: Awaited<ReturnType<AuthClient["auth"]["getUser"]>>;
  try {
    result = await env.createClient(env.url, env.anonKey, {
      global: { headers: { Authorization: `Bearer ${match[1]}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    }).auth.getUser();
  } catch {
    throw new AiError("provider_error", "auth lookup failed");
  }
  if (result.error && isTransient(result.error)) throw new AiError("provider_error", "auth unavailable");
  const user = result.data.user;
  if (result.error || !user?.id) throw new AiError("unauthorized", "invalid token");
  if (user.is_anonymous === true) throw new AiError("unauthorized", "anonymous user");
  return user.id;
}
