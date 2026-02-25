# SIHHA App

Flutter client for SIHHA telehealth platform.

## Architecture

- Mobile app: Flutter
- Backend API: Node.js + Express + PostgreSQL
- Media uploads: local `backend/uploads`

Firebase has been removed from runtime flow.

## Run backend

```bash
cd backend
npm install
copy .env.example .env
npm run dev
```

## Run Flutter app

Android emulator:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Real device:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:3000/api
```

See `backend/README.md` for API and hosting details.
