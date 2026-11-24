// Small database helper for the start script, using the app's bundled `postgres` driver.
//   node db.mjs wait          -> exits 0 once the database answers (up to 180 s)
//   node db.mjs users         -> prints the number of accounts (0 if the table doesn't exist yet)
//   node db.mjs role <email>  -> prints the role of that account
import postgres from "postgres"; // copied from upstream's lockfile into ./node_modules

const url = process.env.POSTGRES_URL || process.env.DATABASE_URL;
const [cmd, arg] = process.argv.slice(2);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const connect = () => postgres(url, { max: 1, connect_timeout: 5, idle_timeout: 1, onnotice: () => {} });

async function main() {
  if (cmd === "wait") {
    const deadline = Date.now() + 180_000;
    let last;
    while (Date.now() < deadline) {
      const sql = connect();
      try {
        await sql`select 1`;
        await sql.end();
        return;
      } catch (err) {
        last = err;
        await sql.end({ timeout: 1 }).catch(() => {});
        await sleep(2000);
      }
    }
    throw new Error(`Postgres did not answer within 180 s (${last?.message})`);
  }
  const sql = connect();
  try {
    if (cmd === "users") {
      const [{ exists }] = await sql`select to_regclass('public."user"') is not null as exists`;
      if (!exists) return console.log(0);
      const [{ n }] = await sql`select count(*)::int as n from "user"`;
      console.log(n);
    } else if (cmd === "role") {
      const rows = await sql`select role from "user" where lower(email) = lower(${arg})`;
      console.log(rows[0]?.role ?? "");
    } else {
      throw new Error(`unknown command ${cmd}`);
    }
  } finally {
    await sql.end({ timeout: 1 });
  }
}

main().catch((err) => {
  console.error(`[navigator] ${err.message}`);
  process.exit(1);
});
