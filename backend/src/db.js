const { Pool } = require("pg");

class PostgresCompatDb {
  constructor(pool) {
    this._pool = pool;
  }

  async get(sql, ...params) {
    const result = await this._query(sql, params);
    return result.rows[0];
  }

  async all(sql, ...params) {
    const result = await this._query(sql, params);
    return result.rows;
  }

  async run(sql, ...params) {
    const result = await this._query(sql, params);
    return {
      changes: Number(result.rowCount || 0),
      lastID: undefined,
    };
  }

  async exec(sql) {
    await this._pool.query(sql);
  }

  async close() {
    await this._pool.end();
  }

  async _query(sql, params) {
    const { text, placeholders } = toPostgresPlaceholders(sql);
    if (placeholders !== params.length) {
      throw new Error(
        `SQL placeholder mismatch: expected ${placeholders}, got ${params.length}.`,
      );
    }
    return this._pool.query(text, params);
  }
}

function toPostgresPlaceholders(sql) {
  let text = "";
  let placeholders = 0;
  let inSingleQuote = false;
  let inDoubleQuote = false;

  for (let i = 0; i < sql.length; i += 1) {
    const ch = sql[i];
    const next = i + 1 < sql.length ? sql[i + 1] : "";

    if (!inDoubleQuote && ch === "'") {
      text += ch;
      if (inSingleQuote && next === "'") {
        text += next;
        i += 1;
      } else {
        inSingleQuote = !inSingleQuote;
      }
      continue;
    }

    if (!inSingleQuote && ch === '"') {
      text += ch;
      inDoubleQuote = !inDoubleQuote;
      continue;
    }

    if (!inSingleQuote && !inDoubleQuote && ch === "?") {
      placeholders += 1;
      text += `$${placeholders}`;
      continue;
    }

    text += ch;
  }

  return { text, placeholders };
}

function parseBooleanEnv(name, fallback = false) {
  const raw = String(process.env[name] || "").trim().toLowerCase();
  if (!raw) {
    return fallback;
  }
  return raw === "1" || raw === "true" || raw === "yes" || raw === "on";
}

function buildPoolConfig() {
  const databaseUrl = String(process.env.DATABASE_URL || "").trim();
  const sslEnabled = parseBooleanEnv("PGSSLMODE_REQUIRE", false);

  if (databaseUrl) {
    return {
      connectionString: databaseUrl,
      ssl: sslEnabled ? { rejectUnauthorized: false } : false,
      max: Number(process.env.PG_POOL_MAX || 20),
      idleTimeoutMillis: Number(process.env.PG_IDLE_TIMEOUT_MS || 30000),
    };
  }

  const host = String(process.env.PGHOST || "").trim();
  const user = String(process.env.PGUSER || "").trim();
  const password = String(process.env.PGPASSWORD || "").trim();
  const database = String(process.env.PGDATABASE || "").trim();
  const port = Number(process.env.PGPORT || 5432);

  if (!host || !user || !database) {
    throw new Error(
      "PostgreSQL configuration missing. Set DATABASE_URL or PGHOST/PGUSER/PGDATABASE.",
    );
  }

  return {
    host,
    user,
    password,
    database,
    port,
    ssl: sslEnabled ? { rejectUnauthorized: false } : false,
    max: Number(process.env.PG_POOL_MAX || 20),
    idleTimeoutMillis: Number(process.env.PG_IDLE_TIMEOUT_MS || 30000),
  };
}

async function ensureColumn(db, tableName, columnName, definition) {
  const row = await db.get(
    `SELECT 1
     FROM information_schema.columns
     WHERE table_schema = current_schema()
       AND table_name = ?
       AND column_name = ?
     LIMIT 1`,
    tableName,
    columnName,
  );
  if (row) {
    return;
  }
  await db.exec(`ALTER TABLE ${tableName} ADD COLUMN ${columnName} ${definition};`);
}

async function ensureSchema(db) {
  await db.exec(`
    CREATE OR REPLACE FUNCTION datetime(input_value TEXT)
    RETURNS timestamptz
    LANGUAGE SQL
    IMMUTABLE
    AS $$
      SELECT CASE
        WHEN input_value IS NULL OR btrim(input_value) = '' THEN NULL
        ELSE input_value::timestamptz
      END
    $$;
  `);

  await db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      phone_number TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL CHECK(role IN ('patient', 'doctor')),
      photo_url TEXT NOT NULL DEFAULT '',
      specialty TEXT NOT NULL DEFAULT '',
      hospital_name TEXT NOT NULL DEFAULT '',
      experience_years INTEGER NOT NULL DEFAULT 0,
      study_years INTEGER NOT NULL DEFAULT 0,
      is_disabled INTEGER NOT NULL DEFAULT 0,
      disabled_at TEXT,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS rooms (
      id TEXT PRIMARY KEY,
      patient_id TEXT NOT NULL,
      patient_name TEXT NOT NULL,
      doctor_id TEXT NOT NULL,
      doctor_name TEXT NOT NULL,
      participant_ids TEXT NOT NULL,
      last_message TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      last_updated_at TEXT NOT NULL,
      is_closed INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(patient_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY(doctor_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      room_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      sender_name TEXT NOT NULL,
      type TEXT NOT NULL CHECK(type IN ('text', 'audio', 'image', 'live')),
      content TEXT NOT NULL,
      duration_seconds INTEGER NOT NULL DEFAULT 0,
      delivered_at TEXT,
      read_at TEXT,
      sent_at TEXT NOT NULL,
      FOREIGN KEY(room_id) REFERENCES rooms(id) ON DELETE CASCADE,
      FOREIGN KEY(sender_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS room_presence (
      room_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      last_seen_at TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY(room_id, user_id),
      FOREIGN KEY(room_id) REFERENCES rooms(id) ON DELETE CASCADE,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS live_sessions (
      room_id TEXT PRIMARY KEY,
      status TEXT NOT NULL CHECK(status IN ('idle', 'pending', 'active')),
      requested_by TEXT,
      requested_at TEXT,
      responded_at TEXT,
      FOREIGN KEY(room_id) REFERENCES rooms(id) ON DELETE CASCADE,
      FOREIGN KEY(requested_by) REFERENCES users(id) ON DELETE SET NULL
    );

    CREATE TABLE IF NOT EXISTS blogs (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      category TEXT NOT NULL,
      author_id TEXT NOT NULL,
      author_name TEXT NOT NULL,
      published_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(author_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS app_presence (
      user_id TEXT PRIMARY KEY,
      last_seen_at TEXT NOT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS user_daily_activity (
      user_id TEXT NOT NULL,
      activity_date TEXT NOT NULL,
      first_seen_at TEXT NOT NULL,
      last_seen_at TEXT NOT NULL,
      PRIMARY KEY(user_id, activity_date),
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS consultation_requests (
      id TEXT PRIMARY KEY,
      patient_id TEXT NOT NULL,
      target_doctor_id TEXT NOT NULL,
      subject_type TEXT NOT NULL CHECK(subject_type IN ('self', 'other')),
      subject_name TEXT NOT NULL,
      age_years INTEGER NOT NULL,
      gender TEXT NOT NULL CHECK(gender IN ('male', 'female')),
      weight_kg REAL NOT NULL,
      state_code TEXT NOT NULL,
      spoken_language TEXT NOT NULL CHECK(spoken_language IN ('ar', 'fr', 'bilingual')),
      symptoms TEXT NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('pending', 'accepted', 'rejected')) DEFAULT 'pending',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      responded_at TEXT,
      responded_by_doctor_id TEXT,
      transferred_by_doctor_id TEXT,
      linked_room_id TEXT,
      FOREIGN KEY(patient_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY(target_doctor_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY(responded_by_doctor_id) REFERENCES users(id) ON DELETE SET NULL,
      FOREIGN KEY(transferred_by_doctor_id) REFERENCES users(id) ON DELETE SET NULL,
      FOREIGN KEY(linked_room_id) REFERENCES rooms(id) ON DELETE SET NULL
    );

    CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
    CREATE INDEX IF NOT EXISTS idx_rooms_patient ON rooms(patient_id);
    CREATE INDEX IF NOT EXISTS idx_rooms_doctor ON rooms(doctor_id);
    CREATE INDEX IF NOT EXISTS idx_rooms_updated ON rooms(last_updated_at);
    CREATE INDEX IF NOT EXISTS idx_messages_room_sent ON messages(room_id, sent_at);
    CREATE INDEX IF NOT EXISTS idx_presence_room ON room_presence(room_id, last_seen_at);
    CREATE INDEX IF NOT EXISTS idx_live_sessions_status ON live_sessions(status);
    CREATE INDEX IF NOT EXISTS idx_blogs_published ON blogs(published_at);
    CREATE INDEX IF NOT EXISTS idx_app_presence_seen ON app_presence(last_seen_at);
    CREATE INDEX IF NOT EXISTS idx_daily_activity_date ON user_daily_activity(activity_date);
    CREATE INDEX IF NOT EXISTS idx_consult_req_target_status
      ON consultation_requests(target_doctor_id, status, updated_at DESC);
    CREATE INDEX IF NOT EXISTS idx_consult_req_patient_status
      ON consultation_requests(patient_id, status, updated_at DESC);
  `);

  await ensureColumn(db, "rooms", "is_closed", "INTEGER NOT NULL DEFAULT 0");
  await ensureColumn(db, "messages", "delivered_at", "TEXT");
  await ensureColumn(db, "messages", "read_at", "TEXT");
  await ensureColumn(db, "users", "is_disabled", "INTEGER NOT NULL DEFAULT 0");
  await ensureColumn(db, "users", "disabled_at", "TEXT");
  await ensureColumn(db, "consultation_requests", "transferred_by_doctor_id", "TEXT");
  await ensureColumn(db, "consultation_requests", "linked_room_id", "TEXT");
}

async function initDb() {
  const pool = new Pool(buildPoolConfig());
  const db = new PostgresCompatDb(pool);
  await db.exec("SELECT 1;");
  await ensureSchema(db);
  return db;
}

module.exports = {
  initDb,
};
