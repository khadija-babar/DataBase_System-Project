# BRT Peshawar Flutter Portal

This repository is now a **Flutter web app** for the BRT Peshawar management portal, configured for deployment on **Vercel**.

The app keeps the original bus-management concept and presents three role-based experiences:

- **Passenger:** plan a trip, book demo tickets, recharge a travel card, view bus occupancy, notifications, and complaints.
- **Driver:** view route assignments, assigned schedules, stops, and update a demo service status.
- **Admin:** monitor route statistics, active buses, bus occupancy, schedules, complaints, and send demo service notifications.

The SQL schema from the earlier database-focused version is preserved in `group13.sql` for reference.

## Tech stack

- Flutter web
- Dart
- Vercel static deployment

## Project structure

```text
.
├── lib/
│   └── main.dart
├── web/
│   ├── index.html
│   └── manifest.json
├── group13.sql
├── pubspec.yaml
└── vercel.json
```

## Run locally

Install Flutter, then run:

```bash
flutter pub get
flutter run -d chrome
```

## Build locally

```bash
flutter build web --release
```

The production build is written to `build/web`.

## Deploy on Vercel

This repo includes `vercel.json` with:

- a build command that installs Flutter stable if needed
- `flutter build web --release`
- `build/web` as the output directory
- a rewrite to support Flutter web routing

Import the repository into Vercel and deploy it with the included configuration.

## Notes

- The current Flutter app uses in-memory demo data so it can deploy as a static Vercel site.
- `group13.sql` remains available as the database schema reference for a future API/backend integration.
