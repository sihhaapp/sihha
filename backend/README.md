# SIHHA Backend (Node.js + SQLite)

This backend replaces Firebase completely for:
- Authentication
- Users/doctors
- Chat rooms and messages
- Audio uploads
- Health blogs
- Profile photos

## 1) Local run

```bash
cd backend
npm install
copy .env.example .env
npm run dev
```

Backend starts on `http://localhost:3000`.

Before using voice calls, configure LiveKit variables in `.env`:
- `LIVEKIT_URL` (self-hosted WSS URL)
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`
- Optional: `LIVEKIT_TOKEN_TTL_SECONDS`, `LIVEKIT_ROOM_PREFIX`

Health check:

```bash
GET http://localhost:3000/api/health
```

## 2) Flutter connection

The app reads backend URL from:
- Dart define `API_BASE_URL`
- Default: `http://10.0.2.2:3000/api` (Android emulator)

Examples:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Real device example (replace with your PC LAN IP):

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000/api
```

## 3) API summary

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
- `POST /api/rooms/:roomId/messages/audio`
- `GET /api/rooms/:roomId/live/status`
- `POST /api/rooms/:roomId/live/request`
- `POST /api/rooms/:roomId/live/accept`
- `POST /api/rooms/:roomId/live/reject`
- `POST /api/rooms/:roomId/live/stop`
- `POST /api/rooms/:roomId/live/join`
- `GET /api/blogs`
- `POST /api/blogs`

## 4) Hosting notes

For production hosting, use a service that supports:
- Node.js runtime
- Persistent disk storage (for SQLite + uploads), or migrate to PostgreSQL + object storage

### Docker build

```bash
cd backend
docker build -t sihha-backend .
docker run -p 3000:3000 \
  -e JWT_SECRET=your-secret \
  -e PUBLIC_BASE_URL=http://localhost:3000 \
  -v %cd%/data:/app/data \
  -v %cd%/uploads:/app/uploads \
  sihha-backend
```

Recommended production improvements:
- Move from SQLite to PostgreSQL
- Store uploads in object storage (S3/R2/Supabase Storage)
- Add rate limiting and structured logging
- Add HTTPS-only and strict CORS origin allow-list
