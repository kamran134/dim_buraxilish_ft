# Mobile (dim_buraxilish_ft) — архитектура

Общесистемный контекст: см. `D:/Others Programs/BuraxilishBackend/docs/SYSTEM_OVERVIEW.md`. Полная карта API бэкенда — `D:/Others Programs/BuraxilishBackend/docs/API.md`.

## 1. Стек

Версия приложения: `9.0.11+28` (`pubspec.yaml`), SDK `>=3.1.3 <4.0.0`.

| Пакет | Версия | Назначение |
|---|---|---|
| `dio` | ^5.3.4 | основной HTTP-клиент (`HttpService`), интерцепторы JWT/401 |
| `http` | ^1.1.0 | точечно — emergency/push сервисы, `notifications_provider`, отдельно от `HttpService` |
| `provider` | ^6.1.1 | state management, `ChangeNotifier` на все провайдеры |
| `go_router` | ^12.1.3 | объявлена, но **не используется** — навигация через `Navigator.push`/`MaterialPageRoute` |
| `sqflite` + `path` | ^2.3.0 / ^1.8.3 | офлайн-БД (`database_service.dart`) |
| `flutter_secure_storage` | ^9.2.2 | JWT/refresh-токен, device id |
| `shared_preferences` | ^2.2.2 | тема, шрифт |
| `mobile_scanner` | ^6.0.0 | сканер QR/Barcode |
| `permission_handler` | ^11.0.1 | разрешение камеры |
| `signalr_netcore` | ^1.4.4 | emergency-сообщения через SignalR hub |
| `firebase_core` / `firebase_messaging` | ^3.13.0 / ^15.2.4 | push-уведомления (FCM) |
| `device_info_plus` | ^11.2.0 | человекочитаемое имя устройства |
| `package_info_plus` | ^8.0.0 | версия приложения |
| `url_launcher` | ^6.2.6 | звонки (`CALL_PHONE` + `tel:` intent) |

`http` и `dio` дублируют друг друга по назначению — не критично, но неединообразно.

## 2. Версия / сборка

- **codemagic.yaml**: один workflow `ios-release` — `flutter build ipa --release`, подпись через `app_store_connect` integration, `GoogleService-Info.plist` из base64 env-переменной `GOOGLE_SERVICE_INFO_PLIST` (секрет не в репо), публикация в TestFlight, email-уведомление на `kazimi.msu@gmail.com`. Android-workflow в `codemagic.yaml` отсутствует — Android собирается вручную/локально.
- **Android** (`android/app/build.gradle`): `applicationId`/`namespace` = `com.dim.dim_buraxilish`, `compileSdkVersion`/`targetSdkVersion` = 36, `ndkVersion "27.0.12077973"`, `abiFilters 'arm64-v8a', 'x86_64'` (armeabi-v7a исключён). Подпись — `signingConfigs.release` читает `android/key.properties` (keyAlias/keyPassword/storeFile/storePassword); файл существует локально, в `.gitignore` (секреты не в git). `android/app/google-services.json` закоммичен в git — конфигурация Firebase-проекта, обычно допустимо коммитить (не серверный секрет). `buildTypes.release`: `minifyEnabled false`, `shrinkResources false` — обфускация/шринкинг выключены в релизе.
- **iOS**: конфигурация присутствует (`ios/Runner/Info.plist`, workspace), но релиза для iOS нет — инфраструктура для публикации (codemagic → TestFlight) настроена, причина отсутствия релиза организационная, не техническая.
- **Публикация Android**: Google Play (ранее раздавали APK напрямую). Сборка — `C:\Users\kamran.kz\Documents\bats\dimburaxilish\build_release.bat` (apk + aab + split-per-abi → `D:\FlutterBuilds\dim_buraxilish_ft\<timestamp>\`). Перед сборкой поднять `version` в `pubspec.yaml` (build number для Play должен расти).

## 3. `main.dart` — инициализация

`WidgetsFlutterBinding.ensureInitialized()` → загрузка версии приложения через `PackageInfo` → `Firebase.initializeApp()` → `EmergencyMessageService.instance.init(navigatorKey)` → `PushNotificationService.instance.init()` → `runApp`.

`MultiProvider` регистрирует: `ThemeProvider`, `FontProvider`, `AuthProvider`, `ParticipantProvider`, `SupervisorProvider`, `MonitorProvider`, `OfflineDatabaseProvider`, `UnsentDataProvider`, `SyncService.instance` (как `ChangeNotifier.value`), `NotificationsProvider.instance` (аналогично). `EnhancedParticipantProvider` **не зарегистрирован** — мёртвый код (см. раздел 12).

Роутинг — без `go_router`, стартовый экран `SplashScreen`, дальше вручную через `Navigator`. Redirect-логика по auth/роли не централизована в одном guard-слое: `splash_screen.dart` и `login_screen.dart` оба напрямую решают, показывать `RealDashboardScreen` или нет, на основе состояния `AuthProvider`.

## 4. Провайдеры (`lib/providers/`)

| Provider | Ответственность | Ключевое состояние |
|---|---|---|
| `auth_provider.dart` | Логин/логаут, состояние авторизации, посекундный lockout-таймер после неудачных попыток, инициирует push/emergency после логина | токен (делегировано в `HttpService`/secure_storage), lockout-таймер |
| `participant_provider.dart` | Сканирование/регистрация участников (buraxilish), офлайн-режим, статистика по залу | список отсканированных, `_isOnlineMode` (захардкожен `false`, мёртвая ветка) |
| `supervisor_provider.dart` | Сканирование/регистрация nəzarətçilər | аналогично participant |
| `monitor_provider.dart` | Сканирование/учёт imtahan rəhbərləri на входе в здание | аналогично |
| `offline_database_provider.dart` | Скачивание офлайн-базы участников/супервайзеров/мониторов на устройство | прогресс загрузки |
| `unsent_data_provider.dart` | Отображение несинхронизированной очереди, ручной sync | счётчики несинхронизированных записей |
| `theme_provider.dart` | Светлая/тёмная тема | `ThemeMode`, persisted в `shared_preferences` |
| `font_provider.dart` | Размер шрифта UI | persisted в `shared_preferences` |
| `notifications_provider.dart` (singleton) | Список emergency-уведомлений, unread count, REST-поллинг `/emergencyacks/pending` | список уведомлений |
| `enhanced_participant_provider.dart` | **мёртвый** — альтернативная реализация поверх `core/`-паттернов, нигде не подключена | — |

## 5. Сервисы (`lib/services/`)

| Файл | Назначение |
|---|---|
| `http_service.dart` (1400 строк) | Основной и реально используемый REST-клиент на `Dio`: логин, refresh (single-flight через `_refreshInFlight`), CRUD участников/супервайзеров/мониторов/протоколов/статистики/версии приложения (~30 эндпоинтов, см. раздел 9) |
| `http_service_cleaned.dart` (1008 строк) | **мёртвый файл** — нигде не импортируется, похоже на недоведённый рефакторинг `http_service.dart` |
| `database_service.dart` (1315 строк) | Вся офлайн-SQLite логика: 8 таблиц, CRUD, get/clear unsynced (см. раздел 7) |
| `sync_service.dart` | Фоновая синхронизация очереди — 30 сек таймер, 10 мин idle-таймаут (см. раздел 7) |
| `device_identity_service.dart` | Генерация/хранение стабильного `device_id` (16 случайных байт, `Random.secure()`) в secure_storage + человекочитаемое имя устройства |
| `emergency_message_service.dart` | SignalR-подключение к hub `/hubs/emergency`, health-таймер (10 сек), показ `EmergencyMessageDialog`, дедуп через `Set<int> _activeDialogIds` |
| `push_notification_service.dart` | FCM: разрешение, получение/загрузка/удаление токена (`/devicetokens`), обработка открытия по тапу (foreground/background/terminated через `getInitialMessage`) |
| `statistics_service.dart` (702 строки) | REST-запросы статистики по зданиям/залам/мониторам для дашборда |
| `statistics_event_bus.dart` | Broadcast `StreamController<String>` — событие «статистика обновилась» |
| `storage_service.dart` | Обёртка над `shared_preferences`, используется в мёртвом DI-слое (`ServiceFactory`) |
| `protocol_service.dart` | Работа с протоколами (заметки/отчёты) |

Репозитории (`lib/repositories/`: `auth_repository.dart`, `participant_repository.dart`) используются только мёртвым DI-слоем (`ServiceFactory`) и `enhanced_participant_provider.dart` — реальные провайдеры обращаются к `HttpService` напрямую.

## 6. Роуты и экраны (`lib/screens/`)

Навигация — `Navigator.push(MaterialPageRoute(...))`, без централизованного guard-слоя (см. раздел 3).

| Экран | Назначение |
|---|---|
| `splash_screen.dart` | Стартовый экран, решает, показывать логин или дашборд |
| `login_screen.dart` | Форма логина (юзернейм/пароль/дата экзамена) |
| `main_screen.dart` | Обёртка с нижней навигацией |
| `home_screen.dart` | Домашний экран после входа |
| `dashboard_screen.dart` | Старая версия дашборда, есть TODO «добавить реальную статистику» — фактически заменена, см. раздел 12 |
| `real_dashboard_screen.dart` | Актуальный дашборд (1529 строк, самый большой файл проекта) |
| `participant_screen.dart` | Сканирование/регистрация участников |
| `supervisor_screen.dart` | Сканирование/регистрация супервайзеров |
| `monitor_screen.dart` | Сканирование/регистрация мониторов на входе в здание |
| `monitor_search_screen.dart` | Поиск монитора (debounce 400мс) |
| `room_monitors_screen.dart` | Список мониторов по залу/комнате |
| `building_details_screen.dart` | Детали по зданию (для статистики) |
| `buildings_statistics_screen.dart` | Статистика по всем зданиям |
| `rooms_statistics_screen.dart` | Статистика по залам |
| `statistics_screen.dart` | Общий экран статистики (агрегатор вкладок) |
| `registered_people_screen.dart` | Список уже зарегистрированных |
| `database_people_screen.dart` | Просмотр локальной офлайн-базы людей |
| `offline_database_screen.dart` | Управление скачиванием офлайн-базы |
| `unsent_data_screen.dart` | Несинхронизированная очередь, ручной sync |
| `protocol_notes_screen.dart` | Заметки протокола экзамена |
| `protocol_reports_screen.dart` | Отчёты протокола |
| `notifications_screen.dart` | Список emergency/push уведомлений |
| `settings_screen.dart` | Тема/шрифт/настройки |

## 7. Auth

- Логин: `HttpService.login()` → `POST /auth/login` с `LoginModel` (userName/password/examDate/deviceId/deviceName). Ответ `LoginResponse` с `AccessTokenModel` (token/expiration/refreshToken).
- Хранение: `flutter_secure_storage`, ключи `jwt_token` (весь `AccessTokenModel` как JSON) и `auth` (bool-флаг).
- Refresh: `getToken()` проверяет `token.isExpired`, при истечении — `_refreshAccessToken()` → `_performRefresh()` → `POST /auth/refresh` (deviceId + refreshToken) через отдельный `_plainDio` (без auth-интерцептора, чтобы не зациклиться). Конкурентные refresh-запросы схлопываются через статический `_refreshInFlight` (single-flight).
- Logout: `removeToken()` удаляет оба ключа из secure_storage; `AuthProvider` дополнительно останавливает `SyncService.instance.stopTimer()`.
- Device identity: `DeviceIdentityService` — 16 случайных байт (`Random.secure()`), хранится в secure_storage под ключом `device_id`, генерируется один раз на инсталляцию; используется в login/refresh.
- FCM-токен: `PushNotificationService.activate(buildingCode)` после логина — запрашивает permission, получает FCM token, `POST /devicetokens`; `deactivate()` на логауте — `DELETE /devicetokens`.
- Lock-out: `AuthProvider` — посекундный `Timer.periodic` обратного отсчёта после N неудачных попыток; таймер не отменяется в `dispose()` (метод не переопределён — известный пункт из старого отчёта, не исправлен).

## 8. Офлайн-режим

### Схема SQLite (`database_service.dart`, версия БД = 7, файл `dim_buraxilish.db`)

| Таблица | PK | Назначение |
|---|---|---|
| `participants` | `external_id` (unique `is_N`) | Скачанная офлайн-база участников (ФИО, зал/место, фото, дата/время экзамена) |
| `registered_participants` | `is_N` | Очередь зарегистрированных участников, `online INTEGER DEFAULT 0` — флаг отправки на сервер |
| `registered_monitors` | `workNumber` | Очередь зарегистрированных мониторов, тоже с `online` |
| `supervisors` | — | Офлайн-база супервайзеров |
| `all_monitors` | — | Справочник всех мониторов (для офлайн-поиска) |
| `registered_supervisors` | `cardNumber` | Очередь зарегистрированных супервайзеров |
| `participant_violations` | — | Нарушения участников |
| `emergency_notifications` | — | Локальный кэш emergency-уведомлений |

Шифрования БД нет (обычный `sqflite`, не `sqflite_sqlcipher`) — ФИО, PIN (`idCardPin`), фото хранятся на устройстве в открытом виде.

Миграции: `_databaseVersion = 7`; `_onUpgrade` (`database_service.dart:190-260`) — пошаговая схема `if (oldVersion < 2) … if (oldVersion < 7)`, внутри шагов `CREATE TABLE IF NOT EXISTS` / `ALTER TABLE`. При добавлении таблицы/колонки: поднять `_databaseVersion` и добавить новый `if (oldVersion < N)` блок.

### `sync_service.dart`

- Периодический `Timer.periodic(30 сек)` стартует при первом сканировании (`notifyScan()`), автостоп после 10 мин простоя (`_idleTimer`).
- Глобальный лок `_syncLock` (статическое поле) — предотвращает одновременный запуск авто- и ручного sync.
- `_performSync()`: берёт несинхронизированные записи из БД, шлёт батчем, при успехе удаляет из очереди по конкретным ID/cardNumber (не «все с `online=0`» — закрывает гонку с новым сканом во время HTTP-запроса).
- `kickstartIfPending()` — вызывается при старте приложения/после логина, восстанавливает счётчики из БД, форсирует sync при наличии несинхронизированного (защита от «тихой» потери данных при перезапуске).
- Парсит маркер `PARTIAL_SYNC:{count}` из ответа сервера (см. `SYSTEM_OVERVIEW.md`, раздел «Сквозные контракты»).
- Retry — фиксированный интервал 30 сек, без экспоненциального backoff.

### `unsent_data`
`unsent_data_provider.dart` — читает счётчики/список несинхронизированного, вызывает `SyncService.syncNow()` вручную (экран `unsent_data_screen.dart`).

`offline_database_provider.dart` — скачивание офлайн-баз через `HttpService`, запись в `database_service.dart`. Явной проверки интернет-соединения до старта скачивания нет — только `try/catch` вокруг HTTP-вызовов с разбором текста исключения (`.contains('401')`, `.contains('404')`).

Конфликты разрешаются на основе ответа сервера (`PARTIAL_SYNC`) — сервер считается источником истины, отдельной клиент-серверной стратегии слияния нет.

## 9. Сканирование

- Пакет `mobile_scanner: ^6.0.0` (обёртка `lib/widgets/qr_scanner.dart`, 406 строк) — QR и Barcode одним и тем же `MobileScannerController`/`onDetect`.
- Защита от дублей: `DetectionSpeed.noDuplicates` в контроллере + дебаунс `_lastScanTime` (игнорирует сканы чаще 2 сек), плюс флаг `_isProcessing`.
- Разрешение камеры — через `permission_handler`, с обработкой «навсегда отказано».
- Вибрация — `HapticFeedback.mediumImpact()` при успешном распознавании кода (`qr_scanner.dart:152`); звукового сигнала нет.
- Ручной ввод — `manual_input_dialog.dart` (fallback, если сканер не читает).

## 10. Push / emergency messages

- `push_notification_service.dart` — FCM: background-handler (`@pragma('vm:entry-point')`), `onTokenRefresh` (автоперезалив токена), `onMessageOpenedApp`/`getInitialMessage()` — оба триггерят `EmergencyMessageService.checkPending()` (push используется как «разбуди и подтяни статус», не как единственный канал доставки контента).
- `emergency_message_service.dart` — реальное время через SignalR (`signalr_netcore`) к hub `/hubs/emergency`. Health-таймер каждые 10 сек проверяет `HubConnectionState`; переподключение на `AppLifecycleState.resumed`, отключение на `paused`. Диалог `EmergencyMessageDialog` показывается через глобальный `navigatorKey` (из `main.dart`), дедуп по `Set<int> _activeDialogIds`.
- `notifications_provider.dart` — отдельный REST-поллинг `/emergencyacks/pending` (не через SignalR), для экрана уведомлений/бейджа unread.

## 11. Статистика

- `statistics_service.dart` (702 строки) — REST-запросы статистики зданий/залов/мониторов.
- `statistics_event_bus.dart` — singleton broadcast-стрим `onStatisticsUpdate`: подписчики — экраны статистики, издатель — `SyncService` после успешного синка и провайдеры после локальной регистрации.
- Экраны: `statistics_screen.dart`, `buildings_statistics_screen.dart`, `rooms_statistics_screen.dart`, `building_details_screen.dart`, `room_monitors_screen.dart`.

## 12. Настройки/тема/шрифт

- `theme_provider.dart` — `ThemeMode`, persisted в `shared_preferences`.
- `font_provider.dart` — размер шрифта UI, тоже `shared_preferences`.
- `settings_screen.dart` (394 строки) — экран настроек (оба провайдера + вероятно logout/о приложении).

## 13. Карта API-вызовов (`http_service.dart`)

Base URL — **захардкоженная константа**: `HttpService.baseUrl = 'https://eservices.dim.gov.az/buraxilishScan/api/api'` (`lib/services/http_service.dart:15-16`). Нет dev/staging конфигурации, флейворов сборки под окружения нет. Та же строка задублирована в мёртвом `core/service_factory.dart:25` и как отдельные hardcoded URL в `emergency_message_service.dart`, `push_notification_service.dart`, `notifications_provider.dart`.

| Метод в `HttpService` | HTTP | Route (относительно `baseUrl`) | Прим. |
|---|---|---|---|
| `login()` | POST | `/auth/login` | + deviceId/deviceName |
| `_performRefresh()` | POST | `/auth/refresh` | отдельный `_plainDio` без auth-интерцептора |
| — | GET | `/buraxilishes/getallexamdate` | список дат экзаменов |
| — | GET | `/tparols/getall` | |
| — | GET | `/tparols/getbybina?bina=$bina` | |
| — | GET | `/supervisorbuildings/getall` | |
| — | GET | `/supervisorbuildings/...` (с параметром, строка ~310) | |
| — | POST | `/supervisorbuildings/add` | |
| — | POST | `/supervisorbuildings/update` | |
| — | POST | `/supervisorbuildings/delete` | |
| ещё ~15 GET/POST (эндпоинты участников/супервайзеров/мониторов/статистики/синка, строки 344–1348) | GET/POST | см. `docs/API.md` бэкенда — контроллеры `BuraxilishesController`, `SupervisorsController`, `MonitorsController`, `StatisticsController` | не расписаны построчно — полный проход по каждому вызову не делался |
| `checkAppVersion()` (примерно) | GET | `/admin/appversion` | проверка обновлений |

Другие HTTP-клиенты помимо `HttpService`:
- `emergency_message_service.dart` — SignalR hub `https://eservices.dim.gov.az/buraxilishScan/api/hubs/emergency` + REST через `package:http` на `/emergencyacks/acknowledge` и `/emergencyacks/pending`.
- `push_notification_service.dart` — REST через `package:http` на `/devicetokens` (POST — загрузка токена, DELETE — удаление).
- `notifications_provider.dart` — REST через `package:http` на `/emergencyacks/pending` и `/emergencyacks/acknowledge` — дублирует URL-константы из `emergency_message_service.dart`.

### Формат дат
Два формата по замыслу (определяются типом колонки на сервере):
- Участники (`/buraxilishes/*`): `examDate` передаётся как есть — азербайджанская словесная дата `"29 sentyabr 2025-ci il"` (легаси-колонка `Imt_Tarix: string`).
- Супервайзеры и мониторы (`/supervisors/*`, `/monitors/*`): `DateFormatter.dateToAzToDate()` → `MM/dd/yyyy` (колонка `ExamDate: DateTime`).

Подробнее — `SYSTEM_OVERVIEW.md` §7.2 в бэкенд-репо.

## 14. Мёртвый код

Кандидаты на удаление (подтверждено grep — 0 импортов вне собственного файла/группы), подробности и приоритет — в отчёте ревью:

| Файл | Статус |
|---|---|
| `lib/patterns.dart` | Не импортируется нигде в `lib/` — весь файл мёртв |
| `lib/providers/enhanced_participant_provider.dart` | Не зарегистрирован в `main.dart` `MultiProvider`, импортируется только из `patterns.dart` — эффективно мёртв |
| `lib/core/auth_strategy.dart` | Импортируется только сам собой, `authenticate()` бросает `UnimplementedError` — заготовка, не подключена |
| `lib/core/commands.dart` | Используется только мёртвыми `patterns.dart`/`enhanced_participant_provider.dart` |
| `lib/core/service_factory.dart` | Используется только мёртвым кодом; содержит собственную копию `baseUrl` |
| `lib/repositories/auth_repository.dart`, `participant_repository.dart` | Используются только мёртвым DI-слоем/enhanced-провайдером |
| `lib/services/http_service_cleaned.dart` (1008 строк) | Не импортируется нигде — недоведённый рефакторинг `http_service.dart` |
| `lib/screens/dashboard_screen.dart` (738 строк) | Прямых конструкторов `DashboardScreen(` за пределами своего файла не найдено (используется `RealDashboardScreen`), содержит 2 TODO «добавить реальную статистику» — вероятно предыдущая версия экрана; полная проверка всех ссылок не проводилась |
| `lib/providers/participant_provider.dart:42` | `_isOnlineMode = false` — захардкожено, геттер есть, значение никогда не меняется (мёртвая ветка логики), унаследовано из старого отчёта |

Весь `core/` (`auth_strategy.dart`, `commands.dart`, `service_factory.dart`) — заготовка паттернов проектирования (Strategy/Command/Factory-DI), не подключённая к реальному приложению; реальный код использует провайдеры + `HttpService` напрямую.

Не проверено так же тщательно (не хватило времени пройтись по каждому из 114 файлов): `lib/services/storage_service.dart` (использование за пределами DI-слоя отдельно не подтверждалось), `lib/screens/database_people_screen.dart` vs `registered_people_screen.dart` (не сравнивались функционально).

Кандидат на удаление, см. отчёт ревью.
