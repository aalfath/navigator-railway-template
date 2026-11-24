// Creates the first account (which Navigator makes the administrator) through the
// app's own sign-up endpoint on a loopback-only server. Exits non-zero on failure.
const port = process.env.BOOTSTRAP_PORT;
const base = `http://127.0.0.1:${port}`;
const email = process.env.ADMIN_EMAIL;
const password = process.env.ADMIN_PASSWORD;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitForServer() {
  const deadline = Date.now() + 240_000;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(`${base}/ping`);
      if (res.ok) return;
    } catch {}
    await sleep(1000);
  }
  throw new Error("the temporary server did not answer /ping within 240 s");
}

async function main() {
  await waitForServer();
  const headers = { "Content-Type": "application/json" };
  if (process.env.BETTER_AUTH_URL) headers.Origin = new URL(process.env.BETTER_AUTH_URL).origin;
  const res = await fetch(`${base}/api/auth/sign-up/email`, {
    method: "POST",
    headers,
    body: JSON.stringify({ name: "Admin", email, password }),
  });
  const text = await res.text();
  if (res.ok) {
    console.log(`[navigator] admin account ${email} created`);
    return;
  }
  if (/already exists/i.test(text)) {
    console.log(`[navigator] admin account ${email} already exists`);
    return;
  }
  throw new Error(`sign-up returned HTTP ${res.status}: ${text.slice(0, 300)}`);
}

main().catch((err) => {
  console.error(`[navigator] admin bootstrap failed: ${err.message}`);
  process.exit(1);
});
