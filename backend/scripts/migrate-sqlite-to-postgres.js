const fs = require("fs");
const path = require("path");
const sqlite3 = require("sqlite3");
const { open } = require("sqlite");

const envPath = path.resolve(__dirname, "..", ".env");
if (fs.existsSync(envPath)) {
  require("dotenv").config({ path: envPath });
} else {
  require("dotenv").config();
}

const { initDb } = require("../src/db");

const TABLES_IN_ORDER = [
  "users",
  "rooms",
  "messages",
  "room_presence",
  "live_sessions",
  "blogs",
  "app_presence",
  "user_daily_activity",
  "consultation_requests",
];

function parseBoolEnv(name, fallback = false) {
  const value = String(process.env[name] || "").trim().toLowerCase();
  if (!value) {
    return fallback;
  }
  return value === "1" || value === "true" || value === "yes" || value === "on";
}

function normalizeValue(value) {
  if (Buffer.isBuffer(value)) {
    return value.toString("utf8");
  }
  return value;
}

async function readTableColumns(sqliteDb, tableName) {
  const columns = await sqliteDb.all(`PRAGMA table_info(${tableName})`);
  return columns.map((column) => column.name);
}

async function migrateTable(sqliteDb, postgresDb, tableName) {
  const columns = await readTableColumns(sqliteDb, tableName);
  if (columns.length === 0) {
    console.log(`[skip] ${tableName}: no columns in source.`);
    return 0;
  }

  const rows = await sqliteDb.all(`SELECT * FROM ${tableName}`);
  if (rows.length === 0) {
    console.log(`[ok] ${tableName}: 0 rows.`);
    return 0;
  }

  const columnList = columns.join(", ");
  const placeholders = columns.map(() => "?").join(", ");
  const insertSql = `
    INSERT INTO ${tableName} (${columnList})
    VALUES (${placeholders})
    ON CONFLICT DO NOTHING
  `;

  let inserted = 0;
  for (const row of rows) {
    const values = columns.map((columnName) => normalizeValue(row[columnName]));
    const result = await postgresDb.run(insertSql, ...values);
    inserted += Number(result.changes || 0);
  }

  console.log(
    `[ok] ${tableName}: source=${rows.length}, inserted=${inserted}, skipped=${rows.length - inserted}.`,
  );
  return inserted;
}

async function main() {
  const sqlitePathRaw =
    process.env.SQLITE_MIGRATION_PATH ||
    process.env.DATABASE_PATH ||
    "./data/sihha.db";
  const sqlitePath = path.resolve(__dirname, "..", sqlitePathRaw);

  if (!fs.existsSync(sqlitePath)) {
    throw new Error(
      `SQLite source file not found: ${sqlitePath}. Set SQLITE_MIGRATION_PATH in .env.`,
    );
  }
  if (!process.env.DATABASE_URL && !process.env.PGHOST) {
    throw new Error(
      "PostgreSQL target is not configured. Set DATABASE_URL (recommended) or PGHOST/PGUSER/PGDATABASE.",
    );
  }

  console.log(`[start] SQLite -> PostgreSQL migration`);
  console.log(`[source] ${sqlitePath}`);
  console.log(
    `[target] ${process.env.DATABASE_URL ? "DATABASE_URL" : "PGHOST/PGUSER/PGDATABASE"}`,
  );

  const sqliteDb = await open({
    filename: sqlitePath,
    driver: sqlite3.Database,
  });
  const postgresDb = await initDb();

  try {
    const truncateTarget = parseBoolEnv("MIGRATE_TRUNCATE_TARGET", false);
    if (truncateTarget) {
      console.log("[info] MIGRATE_TRUNCATE_TARGET enabled: truncating target tables.");
      await postgresDb.exec(`
        TRUNCATE TABLE
          consultation_requests,
          user_daily_activity,
          app_presence,
          blogs,
          live_sessions,
          room_presence,
          messages,
          rooms,
          users
        RESTART IDENTITY CASCADE;
      `);
    }

    await postgresDb.exec("BEGIN;");
    let totalInserted = 0;
    for (const tableName of TABLES_IN_ORDER) {
      totalInserted += await migrateTable(sqliteDb, postgresDb, tableName);
    }
    await postgresDb.exec("COMMIT;");
    console.log(`[done] Migration committed successfully. total_inserted=${totalInserted}`);
  } catch (error) {
    await postgresDb.exec("ROLLBACK;");
    console.error("[error] Migration rolled back.", error);
    process.exitCode = 1;
  } finally {
    await sqliteDb.close();
    await postgresDb.close();
  }
}

main().catch((error) => {
  console.error("[fatal] Migration failed before transaction.", error);
  process.exit(1);
});
