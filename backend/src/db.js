const fs = require("fs");
const path = require("path");
const sqlite3 = require("sqlite3");
const { open } = require("sqlite");

async function initDb(databasePath) {
  const absolutePath = path.resolve(databasePath);
  const dir = path.dirname(absolutePath);
  fs.mkdirSync(dir, { recursive: true });

  const db = await open({
    filename: absolutePath,
    driver: sqlite3.Database,
  });

  await db.exec("PRAGMA foreign_keys = ON;");

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

  await ensureMessagesTableSupportsNewTypes(db);
  await ensureMessageStatusColumns(db);
  await ensureUsersAdminColumns(db);
  await ensureAnalyticsTables(db);
  await ensureConsultationRequestColumns(db);

  return db;
}

async function ensureMessagesTableSupportsNewTypes(db) {
  const row = await db.get(
    "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'messages'",
  );
  const createSql = String(row?.sql || "");
  const hasImage = createSql.includes("'image'");
  const hasLive = createSql.includes("'live'");
  if (hasImage && hasLive) {
    return;
  }

  await db.exec(`
    BEGIN TRANSACTION;

    CREATE TABLE messages_new (
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

    INSERT INTO messages_new (
      id, room_id, sender_id, sender_name, type, content, duration_seconds, delivered_at, read_at, sent_at
    )
    SELECT
      id, room_id, sender_id, sender_name, type, content, duration_seconds, delivered_at, read_at, sent_at
    FROM messages;

    DROP TABLE messages;
    ALTER TABLE messages_new RENAME TO messages;

    CREATE INDEX IF NOT EXISTS idx_messages_room_sent ON messages(room_id, sent_at);

    COMMIT;
  `);
}

async function ensureMessageStatusColumns(db) {
  const columns = await db.all("PRAGMA table_info(messages)");
  const hasDeliveredAt = columns.some((c) => c.name === "delivered_at");
  const hasReadAt = columns.some((c) => c.name === "read_at");

  if (!hasDeliveredAt) {
    await db.exec("ALTER TABLE messages ADD COLUMN delivered_at TEXT;");
  }
  if (!hasReadAt) {
    await db.exec("ALTER TABLE messages ADD COLUMN read_at TEXT;");
  }
}

async function ensureUsersAdminColumns(db) {
  const columns = await db.all("PRAGMA table_info(users)");
  const hasIsDisabled = columns.some((c) => c.name === "is_disabled");
  const hasDisabledAt = columns.some((c) => c.name === "disabled_at");

  if (!hasIsDisabled) {
    await db.exec("ALTER TABLE users ADD COLUMN is_disabled INTEGER NOT NULL DEFAULT 0;");
  }
  if (!hasDisabledAt) {
    await db.exec("ALTER TABLE users ADD COLUMN disabled_at TEXT;");
  }
}

async function ensureAnalyticsTables(db) {
  await db.exec(`
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

    CREATE INDEX IF NOT EXISTS idx_app_presence_seen ON app_presence(last_seen_at);
    CREATE INDEX IF NOT EXISTS idx_daily_activity_date ON user_daily_activity(activity_date);
  `);
}

async function ensureConsultationRequestColumns(db) {
  const tableRow = await db.get(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'consultation_requests'",
  );
  if (!tableRow) {
    return;
  }

  const columns = await db.all("PRAGMA table_info(consultation_requests)");
  const hasTransferredBy = columns.some((c) => c.name === "transferred_by_doctor_id");
  const hasLinkedRoomId = columns.some((c) => c.name === "linked_room_id");

  if (!hasTransferredBy) {
    await db.exec("ALTER TABLE consultation_requests ADD COLUMN transferred_by_doctor_id TEXT;");
  }
  if (!hasLinkedRoomId) {
    await db.exec("ALTER TABLE consultation_requests ADD COLUMN linked_room_id TEXT;");
  }

  await db.exec(`
    CREATE INDEX IF NOT EXISTS idx_consult_req_target_status
      ON consultation_requests(target_doctor_id, status, updated_at DESC);
    CREATE INDEX IF NOT EXISTS idx_consult_req_patient_status
      ON consultation_requests(patient_id, status, updated_at DESC);
  `);
}

module.exports = {
  initDb,
};
