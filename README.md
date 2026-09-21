# dim_buraxilish_ft — Mobile

Приложение сканирования для системы контроля допуска на экзамен "Buraxılış" (DİM, Азербайджан): скан imtahan rəhbərləri/nəzarətçilər/участников на входе в здание, офлайн-очередь, push/emergency-уведомления. Общесистемное описание — `D:/Others Programs/BuraxilishBackend/docs/SYSTEM_OVERVIEW.md`.

## Стек

Flutter (Dart SDK `>=3.1.3 <4.0.0`) · `dio` (HTTP) + `http` (точечно) · `provider` (state) · `sqflite` (офлайн-БД) · `flutter_secure_storage` (токены) · `mobile_scanner` (QR/Barcode) · `signalr_netcore` (emergency) · `firebase_messaging` (push).

## Сборка и запуск на реальном устройстве

Эмулятор не используется — приложение работает с камерой и требует реальное устройство.

```
flutter pub get
flutter run --release
```

## Base URL

Захардкожен в коде: `HttpService.baseUrl` в `lib/services/http_service.dart` (сейчас `https://eservices.dim.gov.az/buraxilishScan/api/api`). Отдельной dev/staging конфигурации и флейворов сборки нет — при необходимости смены окружения нужно менять константу в нескольких местах (см. `docs/ARCHITECTURE.md`, раздел 13).

## Сборка релиза

- **iOS**: через `codemagic.yaml` (workflow `ios-release`) — `flutter build ipa --release`, публикация в TestFlight. Релиза для iOS на данный момент нет (инфраструктура готова, причина — организационная).
- **Android**: публикуется в Google Play. Сборка — `C:\Users\kamran.kz\Documents\bats\dimburaxilish\build_release.bat` (apk + aab → `D:\FlutterBuilds\dim_buraxilish_ft\<timestamp>\`). Требует `android/key.properties` (keyAlias/keyPassword/storeFile/storePassword) — не в git. Перед сборкой поднять `version` в `pubspec.yaml`.

## Документация

- `docs/ARCHITECTURE.md` — стек, версия/сборка, провайдеры, сервисы, экраны, auth, офлайн-режим (SQLite/sync), сканирование, push/emergency, статистика, карта API-вызовов, мёртвый код
- `D:/Others Programs/BuraxilishBackend/docs/SYSTEM_OVERVIEW.md` — общесистемный контекст, роли, глоссарий, сквозные контракты

Связанный документ: `../SUPERVISOR_ENDPOINTS_ANALYSIS.md` (анализ эндпоинтов супервайзеров).
