# SIHHA Backend (Node.js + PostgreSQL)

This backend replaces Firebase for:
- Authentication
- Users/doctors/admin
- Chat rooms and messages
- Consultation requests
- Audio/image/profile uploads
- Health blogs

## 1) Local run

```bash
cd backend
npm install
copy .env.example .env
npm run dev
```

Backend starts on `http://localhost:3000`.

Required DB env:
- `DATABASE_URL` (recommended)
- Optional: `PGSSLMODE_REQUIRE=true` for managed PG with SSL.

Health check:

```bash
GET http://localhost:3000/api/health
```

Before using voice calls, configure LiveKit variables in `.env`:
- `LIVEKIT_URL` (self-hosted WSS URL)
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`
- Optional: `LIVEKIT_TOKEN_TTL_SECONDS`, `LIVEKIT_ROOM_PREFIX`

Before using AI triage, configure OpenAI variables in `.env`:
- `OPENAI_API_KEY` (server-side only, never expose in Flutter)
- Optional: `OPENAI_TRIAGE_MODEL` (default: `gpt-4o-mini`)
- Optional: `TRIAGE_ENABLE_MODERATION=true` (default enabled)

## 2) SQLite -> PostgreSQL migration

If you have existing SQLite data:

1. Set target PostgreSQL in `.env`:
- `DATABASE_URL=postgresql://...`
2. Set source SQLite path (optional, defaults to `./data/sihha.db`):
- `SQLITE_MIGRATION_PATH=./data/sihha.db`
3. Run migration:

```bash
npm run migrate:sqlite:pg
```

Optional full overwrite of target data:

```bash
set MIGRATE_TRUNCATE_TARGET=true
npm run migrate:sqlite:pg
```

## 3) Flutter connection

The app reads backend URL from:
- Dart define `API_BASE_URL`
- Default: `http://10.0.2.2:3000/api` (Android emulator)

Examples:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Real device example:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000/api
```

## 4) API summary

- `POST /api/auth/signup`
- `POST /api/auth/signin`
- `GET /api/auth/me`
- `POST /api/auth/logout`
- `POST /api/auth/change-password`
- `GET /api/doctors`
- `PUT /api/users/me/doctor-profile`
- `POST /api/users/me/photo` (multipart, field: `photo`)
- `POST /api/rooms/create-or-get`
- `GET /api/rooms`
- `GET /api/rooms/:roomId/messages`
- `POST /api/rooms/:roomId/messages/text`
- `POST /api/uploads/audio` (multipart, field: `audio`)
- `POST /api/uploads/image` (multipart, field: `image`)
- `POST /api/rooms/:roomId/messages/audio`
- `POST /api/rooms/:roomId/messages/image`
- `POST /api/rooms/:roomId/close`
- `GET /api/rooms/:roomId/live/status`
- `POST /api/rooms/:roomId/live/request`
- `POST /api/rooms/:roomId/live/accept`
- `POST /api/rooms/:roomId/live/reject`
- `POST /api/rooms/:roomId/live/stop`
- `POST /api/rooms/:roomId/live/join`
- `GET /api/blogs`
- `POST /api/blogs`
- `POST /api/triage/analyze`

## 5) Triage endpoint (`POST /api/triage/analyze`)

Requires auth token (`Authorization: Bearer <jwt>`).

Example request body:

```json
{
  "age": 28,
  "sex": "female",
  "weightKg": 60,
  "pregnant": false,
  "symptoms": "حمى 39 مع سعال وضيق نفس منذ يومين",
  "duration": "2 days",
  "language": "ar"
}
```

Response shape:

```json
{
  "risk_level": "high",
  "red_flags": ["ضيق نفس", "حمى مرتفعة"],
  "follow_up_questions": ["هل يوجد ألم صدر؟", "هل قياس الأكسجين متاح؟", "هل الأعراض تتفاقم بسرعة؟"],
  "suggested_specialty": "general_practice",
  "self_care": ["اشرب سوائل", "راقب الحرارة"],
  "seek_urgent_care_if": ["تفاقم ضيق النفس", "زرقة", "إغماء"],
  "summary_for_doctor": "مريضة 28 سنة... (ملخص منظم)"
}
```

Notes:
- Guardrails are enforced: no diagnosis, no medication doses.
- Inputs can be moderated (`omni-moderation-latest`) before analysis.
- Every triage call is stored in `triage_audit_logs` for audit/quality.
- Emergency safety reminder is always included in urgent-care guidance.

## 6) Docker run

```bash
cd backend
docker build -t sihha-backend .
docker run -p 3000:3000 \
  -e JWT_SECRET=your-secret \
  -e DATABASE_URL=postgresql://postgres:postgres@host.docker.internal:5432/sihha \
  -e PUBLIC_BASE_URL=http://localhost:3000 \
  -v %cd%/uploads:/app/uploads \
  sihha-backend
```

## 7) Production notes

- Keep PostgreSQL backups enabled.
- Use object storage for uploads (S3/R2/Spaces) for scale.
- Add rate limiting + structured logs.
- Enforce HTTPS + strict CORS allow-list.
