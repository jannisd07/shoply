import { assertEquals, assertRejects } from "@std/assert";

import { type AuthClientFactory, getUserId } from "./auth.ts";
import { AiError } from "./errors.ts";

function factory(result: { id?: string; error?: boolean }, seen: string[] = []): AuthClientFactory {
  return (_url, _key, options) => {
    seen.push(options.global.headers.Authorization);
    return {
      auth: {
        getUser: () =>
          Promise.resolve({
            data: { user: result.id ? { id: result.id } : null },
            error: result.error ? { message: "invalid" } : null,
          }),
      },
    };
  };
}

const ENV = { url: "http://supabase.test", anonKey: "anon" };

function request(authorization?: string) {
  const headers = new Headers();
  if (authorization !== undefined) headers.set("Authorization", authorization);
  return new Request("http://localhost/ai", { method: "POST", headers });
}

Deno.test("getUserId rejects a request without a bearer token before any network call", async () => {
  const seen: string[] = [];
  for (const header of [undefined, "", "Basic abc", "Bearer   "]) {
    const err = await assertRejects(
      () => getUserId(request(header), { ...ENV, createClient: factory({ id: "u" }, seen) }),
      AiError,
    );
    assertEquals(err.code, "unauthorized");
  }
  assertEquals(seen, []);
});

Deno.test("getUserId verifies the caller's JWT and returns the user id", async () => {
  const seen: string[] = [];
  const id = await getUserId(request("Bearer jwt-123"), { ...ENV, createClient: factory({ id: "user-1" }, seen) });
  assertEquals(id, "user-1");
  assertEquals(seen, ["Bearer jwt-123"]);
});

Deno.test("getUserId maps a rejected JWT to unauthorized", async () => {
  const err = await assertRejects(
    () => getUserId(request("Bearer expired"), { ...ENV, createClient: factory({ error: true }) }),
    AiError,
  );
  assertEquals(err.code, "unauthorized");
});

function factoryWith(
  result: { data: { user: { id: string; is_anonymous?: boolean } | null }; error: unknown },
): AuthClientFactory {
  return () => ({ auth: { getUser: () => Promise.resolve(result) } });
}

Deno.test("getUserId keeps an auth outage apart from a bad token", async () => {
  const transient = [
    { name: "AuthRetryableFetchError", message: "fetch failed" },
    { name: "AuthApiError", status: 503, message: "unavailable" },
    { name: "AuthApiError", status: 500, message: "boom" },
  ];
  for (const error of transient) {
    const err = await assertRejects(
      () => getUserId(request("Bearer jwt"), { ...ENV, createClient: factoryWith({ data: { user: null }, error }) }),
      AiError,
    );
    assertEquals(err.code, "provider_error", JSON.stringify(error));
  }
});

Deno.test("getUserId treats a 4xx from auth as unauthorized", async () => {
  for (const status of [400, 401, 403]) {
    const err = await assertRejects(
      () =>
        getUserId(request("Bearer jwt"), {
          ...ENV,
          createClient: factoryWith({ data: { user: null }, error: { name: "AuthApiError", status } }),
        }),
      AiError,
    );
    assertEquals(err.code, "unauthorized", String(status));
  }
});

Deno.test("getUserId maps a failing client factory or a rejected lookup to provider_error", async () => {
  const throwing: AuthClientFactory = () => {
    throw new Error("supabaseUrl is required.");
  };
  const rejecting: AuthClientFactory = () => ({ auth: { getUser: () => Promise.reject(new TypeError("network")) } });
  for (const createClient of [throwing, rejecting]) {
    const err = await assertRejects(() => getUserId(request("Bearer jwt"), { ...ENV, createClient }), AiError);
    assertEquals(err.code, "provider_error");
  }
});

Deno.test("getUserId rejects anonymous users so throwaway accounts get no AI quota", async () => {
  const err = await assertRejects(
    () =>
      getUserId(request("Bearer anon-jwt"), {
        ...ENV,
        createClient: factoryWith({ data: { user: { id: "anon-1", is_anonymous: true } }, error: null }),
      }),
    AiError,
  );
  assertEquals(err.code, "unauthorized");
});
