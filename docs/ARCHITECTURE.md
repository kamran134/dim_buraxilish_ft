# Mobile (dim_buraxilish_ft) — архитектура

Общесистемный контекст: см. `D:/Others Programs/BuraxilishBackend/docs/SYSTEM_OVERVIEW.md`. Полная карта API бэкенда — `D:/Others Programs/BuraxilishBackend/docs/API.md`.

## 1. Стек

Версия приложения: `9.2.0+32` (`pubspec.yaml`), SDK `>=3.1.3 <4.0.0`.

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

`MultiProvider` регистрирует: `ThemeProvider`, `FontProvider`, `AuthProvider`, `ParticipantProvider`, `SupervisorProvider`, `MonitorProvider`, `OfflineDatabaseProvider`, `UnsentDataProvider`, `SyncService.instance` (как `ChangeNotifier.value`), `NotificationsProvider.instance` (аналогично).

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

## 5. Сервисы (`lib/services/`)

| Файл | Назначение |
|---|---|
| `http_service.dart` | Основной и реально используемый REST-клиент на `Dio`: логин, refresh (single-flight через `_refreshInFlight`), CRUD участников/супервайзеров/мониторов/протоколов/статистики/версии приложения (~30 эндпоинтов, см. раздел 13). Full-switch (9.2): каждый эндпоинт кроме sync/cancel/downloadcomplete потерял параметр `examDate` — контекст экзамена только из заголовка `X-Exam-Slot` |
| `database_service.dart` | Вся офлайн-SQLite логика: 8 таблиц (версия БД 9), CRUD, get/clear unsynced (см. раздел 8) |
| `sync_service.dart` | Фоновая синхронизация очереди — 30 сек таймер, 10 мин idle-таймаут (см. раздел 7) |
| `device_identity_service.dart` | Генерация/хранение стабильного `device_id` (16 случайных байт, `Random.secure()`) в secure_storage + человекочитаемое имя устройства |
| `emergency_message_service.dart` | SignalR-подключение к hub `/hubs/emergency`, health-таймер (10 сек), показ `EmergencyMessageDialog`, дедуп через `Set<int> _activeDialogIds` |
| `push_notification_service.dart` | FCM: разрешение, получение/загрузка/удаление токена (`/devicetokens`), обработка открытия по тапу (foreground/background/terminated через `getInitialMessage`) |
| `statistics_service.dart` | REST-запросы статистики по зданиям/залам/мониторам для дашборда. Full-switch (9.2): методы больше не принимают `examDate` — `getActiveSlotExamDate()` заменён на `hasActiveSlot()` (bool) |
| `statistics_event_bus.dart` | Broadcast `StreamController<String>` — событие «статистика обновилась» |
| `storage_service.dart` | Обёртка над `shared_preferences` |
| `protocol_service.dart` | Работа с протоколами (заметки/отчёты) |
| `admin_service.dart` | Админские эндпоинты вне `StatisticsService`: статус и отзыв устройств (`admin/*`), срочные сообщения (`emergencymessages/*`), профиль (`auth/me`). Идёт через dio `HttpService` (JWT, refresh, `X-Exam-Slot` — из интерцептора), возвращает `Result`/`DataResult` вместо исключений |

Провайдеры обращаются к `HttpService` напрямую (нет отдельного repository-слоя).

## 6. Роуты и экраны (`lib/screens/`)

Навигация — `Navigator.push(MaterialPageRoute(...))`, без централизованного guard-слоя (см. раздел 3).

| Экран | Назначение |
|---|---|
| `splash_screen.dart` | Стартовый экран, решает, показывать логин или дашборд (админ → `AdminShell`, остальные → `MainScreen`) |
| `login_screen.dart` | Форма логина (юзернейм/пароль — без даты экзамена, экзамен/слот выбирается после входа на `exam_select_screen.dart`) |
| `main_screen.dart` | Обёртка с нижней навигацией |
| `home_screen.dart` | Домашний экран после входа |
| `exam_select_screen.dart` | Выбор слота (дата+время) после логина или для переключения — список из `GET /slots`/`GET /slots/all` |
| `participant_screen.dart` | Сканирование/регистрация участников |
| `supervisor_screen.dart` | Сканирование/регистрация супервайзеров |
| `monitor_screen.dart` | Сканирование/регистрация imtahan rəhbərləri (роль `monitor`); для админа — вкладка «Skan» (`inShell`, `ScanActivityGuard`) |
| `monitor_search_screen.dart` | Поиск imtahan rəhbəri (debounce 400мс); общий для обеих ролей |
| `statistics_screen.dart` | Статистика роли `monitor` (по залам/зданию); админская статистика — в `screens/admin/statistics/` |
| `registered_people_screen.dart` | Список уже зарегистрированных |
| `database_people_screen.dart` | Просмотр локальной офлайн-базы людей |
| `offline_database_screen.dart` | Управление скачиванием офлайн-базы |
| `unsent_data_screen.dart` | Несинхронизированная очередь, ручной sync |
| `protocol_notes_screen.dart` | Заметки протокола экзамена (вкладка «Protokollar» экранов участников/супервайзеров) |
| `notifications_screen.dart` | Список emergency/push уведомлений |
| `settings_screen.dart` | Тема/шрифт/настройки |

### Админская область (`lib/screens/admin/`)

Роли `admin`/`superadmin` после логина и выбора слота (`exam_select_screen.dart`, `splash_screen.dart`) попадают в `AdminShell`; экраны роли `monitor` (`MainScreen` → `HomeScreen`) админ не видит и наоборот. Каждый экран разделён на **загрузчик** (`…Screen`, State с сервисами, таймерами, навигацией) и **чистый `…View`** (данные и колбэки на входе, без сервисов) — View тестируется виджет-тестами из `test/admin/` без сети.

- `admin_shell.dart` — оболочка: 4 вкладки в `IndexedStack` (состояние сохраняется): **Əsas** (`AdminHomeScreen`), **Statistika** (`AdminStatisticsScreen`), **Skan** (`MonitorScreen(inShell: true)`), **Protokollar** (`AdminProtocolReportsScreen`). Нижняя `NavigationBar` на compact, `NavigationRail` на medium+. Системная «назад» на любой вкладке кроме Əsas возвращает на Əsas.
- `admin_sections.dart` — единый список `adminSections` (`AdminSection`): из него строятся пункты drawer (`widgets/admin_drawer.dart` на `BaseDrawer`) и плитки быстрых переходов на Əsas. Секция с `tab` переключает вкладку, без неё — `Navigator.push(pageBuilder)`. Три пункта Statistika различаются `statsSegment`. Новый экран админа = одна запись здесь.
- `admin_home_screen.dart` / `admin_home_view.dart` — Əsas: сводка (участники, nəzarətçilər, imtahan rəhbərləri), 5 зданий с минимальной регистрацией, плитки переходов; опрос 30 с, pull-to-refresh, перезагрузка при смене слота.
- `statistics/` — Statistika: `AdminStatisticsScreen`/`View` (сегменты İştirakçılar / Nəzarətçilər / İmtahan rəhbərləri, поиск, сортировка), `AdminBuildingScreen` (участники/nəzarətçilər/imtahan rəhbərləri здания, фильтры, нарушители), `AdminRoomMonitorsScreen` (imtahan rəhbərləri зала), `AdminPersonDetailScreen`/`View` (карточка человека + отмена регистрации с подтверждением, протокол участника), `admin_*_rows.dart`/`admin_person_tile.dart` — строки списков.
- `participants/` — Bütün iştirakçılar: серверный поиск + бесконечная прокрутка (`searchparticipants` / `getallparticipantswithpagination`), тап → карточка участника.
- `protocols/` — Protokol hesabatları: фильтры, группировка, просмотр записи (`ProtocolService.getProtocols`).
- `scan/` — Skan: `admin_scan_views.dart` / `admin_monitor_search_view.dart` — оформление `MonitorScreen`/`MonitorSearchScreen` (логика `MonitorProvider` не менялась); `ScanActivityGuard` останавливает камеру, когда вкладка скрыта, поверх открыт маршрут или приложение ушло в фон (сам не перезапускает).
- `devices/` — Cihazların statusu (`admin/downloadstatus`, `admin/devicelogins`, отзыв `admin/devices/revoke` с подтверждением, фильтры, чистая логика в `admin_devices_logic.dart`).
- `emergency/` — Təcili elan: выбор зданий, текст, отправка с подтверждением, история; `emergency_draft.dart` — модель черновика.
- `account/` — Profil (`auth/me`) и Şifrəni dəyiş (`password/changepassword`).
- `admin_auto_refresh.dart` — mixin `AdminAutoRefresh`: опрос каждые 30 с для экранов, открытых поверх оболочки; таймер работает только пока экран реально виден (стоп при opaque-маршруте сверху и при уходе приложения в фон, при возвращении — немедленное обновление).

Слово «monitor» в UI запрещено: роль `monitor` = «Ümumi imtahan rəhbəri», люди в залах — «imtahan rəhbəri / imtahan rəhbərləri». Идентификаторы в коде остаются `monitor*` (контракт API).

## 7. Auth

- Логин: `HttpService.login()` → `POST /auth/login` с `LoginModel` (userName/password/deviceId/deviceName — без даты/слота экзамена, он выбирается после входа на `exam_select_screen.dart`). Ответ `LoginResponse` с `AccessTokenModel` (token/expiration/refreshToken).
- Хранение: `flutter_secure_storage`, ключи `jwt_token` (весь `AccessTokenModel` как JSON) и `auth` (bool-флаг).
- Refresh: `getToken()` проверяет `token.isExpired`, при истечении — `_refreshAccessToken()` → `_performRefresh()` → `POST /auth/refresh` (deviceId + refreshToken) через отдельный `_plainDio` (без auth-интерцептора, чтобы не зациклиться). Конкурентные refresh-запросы схлопываются через статический `_refreshInFlight` (single-flight).
- Logout: `removeToken()` удаляет оба ключа из secure_storage; `AuthProvider` дополнительно останавливает `SyncService.instance.stopTimer()`.
- Device identity: `DeviceIdentityService` — 16 случайных байт (`Random.secure()`), хранится в secure_storage под ключом `device_id`, генерируется один раз на инсталляцию; используется в login/refresh.
- FCM-токен: `PushNotificationService.activate(buildingCode)` после логина — запрашивает permission, получает FCM token, `POST /devicetokens`; `deactivate()` на логауте — `DELETE /devicetokens`.
- Lock-out: `AuthProvider` — посекундный `Timer.periodic` обратного отсчёта после N неудачных попыток; таймер не отменяется в `dispose()` (метод не переопределён — известный пункт из старого отчёта, не исправлен).

## 8. Офлайн-режим

### Схема SQLite (`database_service.dart`, версия БД = 9, файл `dim_buraxilish.db`)

| Таблица | PK | Назначение |
|---|---|---|
| `participants` | `id` (server `Participants.Id`, unique `is_N`) | Скачанная офлайн-база участников (ФИО, зал/место, фото, `exam_session_id`) |
| `registered_participants` | `is_N` | Очередь зарегистрированных участников; `id` (server id, `NULL` только для v8-строки, мигрированной в v9 без своего id) + `slot_key` (fallback для синка такой строки) + `online INTEGER DEFAULT 0` |
| `registered_monitors` | `workNumber` | Локальный кэш зарегистрированных мониторов (мониторы не имеют офлайн-очереди — сканирование всегда онлайн), `id`/`exam_session_id`, `examDate` — только отображение |
| `supervisors` | `cardNumber` | Офлайн-база супервайзеров, `id`/`exam_session_id`, `examDate` — только отображение |
| `all_monitors` | `workNumber` | Справочник всех мониторов (офлайн-поиск, admin), `id`/`exam_session_id` |
| `registered_supervisors` | `cardNumber` | Очередь зарегистрированных супервайзеров; `id`/`slot_key` как у `registered_participants` |
| `participant_violations` | — | Нарушения участников |
| `emergency_notifications` | — | Локальный кэш emergency-уведомлений |

Шифрования БД нет (обычный `sqflite`, не `sqflite_sqlcipher`) — ФИО, PIN (`idCardPin`), фото хранятся на устройстве в открытом виде.

Миграции: `_databaseVersion = 9`; `_onUpgrade` — пошаговая схема `if (oldVersion < 2) … if (oldVersion < 9)`. v9 (full-switch, contract §1.2/§1.3) заменяет строковую дату экзамена (`imt_Tarix`/`examDate`-как-ключ) на серверные `id`/`exam_session_id`: скачиваемые таблицы (`participants`, `supervisors`, `all_monitors`, `registered_monitors`) дропаются и создаются заново (они всегда полностью перезаписываются при следующей загрузке), а таблицы очереди синка (`registered_participants`, `registered_supervisors`) пересоздаются с новыми колонками `id`/`slot_key`, и их v8-строки переносятся внутри той же транзакции с `id = NULL` и `slot_key`, взятым из `exam_details.slotKey` (secure storage, читается до `openDatabase()`) — такие строки синкаются через fallback-ветку контракта §1.3 (`is_N`/`cardNumber` + `bina`/`buildingCode` + `slotKey`). При добавлении таблицы/колонки: поднять `_databaseVersion` и добавить новый `if (oldVersion < N)` блок.

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
- Экраны: роль `monitor` — `statistics_screen.dart`; админ — `screens/admin/statistics/` (см. разделы 6 и 15). `StatisticsService` обслуживает обе стороны (в т.ч. поиск/пагинацию участников, карточки людей, протокол участника).

## 12. Настройки/тема/шрифт

- `theme_provider.dart` — `ThemeMode`, persisted в `shared_preferences`.
- `font_provider.dart` — размер шрифта UI, тоже `shared_preferences`.
- `settings_screen.dart` (394 строки) — экран настроек (оба провайдера + вероятно logout/о приложении).

## 13. Карта API-вызовов (`http_service.dart`)

Base URL — **захардкоженная константа**: `HttpService.baseUrl = 'https://eservices.dim.gov.az/buraxilishScan/api/api'` (`lib/services/http_service.dart:15-16`). Нет dev/staging конфигурации, флейворов сборки под окружения нет. Та же строка задублирована как отдельные hardcoded URL в `emergency_message_service.dart`, `push_notification_service.dart`, `notifications_provider.dart`.

Full-switch (9.2, contract §1): `X-Exam-Slot` (интерцептор `HttpService`, из `ExamDetails.slotKey`) — единственный источник контекста экзамена. `GET /buraxilishes/getallexamdate` удалён из контракта; синк (`syncburaxilish`/`syncsupervisors`) шлёт `{id?, is_N?/cardNumber?, bina?/buildingCode?, slotKey?, ...}`, отмена регистрации (`cancelregistration` — участники/супервайзеры/мониторы) — только `{id}`, `admin/downloadcomplete` — `{buildingCode, slotKey, ...}`. Все прочие эндпоинты (детали/списки/скан/поиск) потеряли параметр `examDate`.

| Метод в `HttpService` | HTTP | Route (относительно `baseUrl`) | Прим. |
|---|---|---|---|
| `login()` | POST | `/auth/login` | + deviceId/deviceName |
| `_performRefresh()` | POST | `/auth/refresh` | отдельный `_plainDio` без auth-интерцептора |
| `getSlots()` / `getAllSlots()` | GET | `/slots`, `/slots/all` | выбор слота после логина/при переключении |
| — | GET | `/tparols/getall` | |
| — | GET | `/tparols/getbybina?bina=$bina` | |
| — | GET | `/supervisorbuildings/getall` | |
| — | GET | `/supervisorbuildings/...` (с параметром, строка ~310) | |
| — | POST | `/supervisorbuildings/add` | |
| — | POST | `/supervisorbuildings/update` | |
| — | POST | `/supervisorbuildings/delete` | |
| ещё ~15 GET/POST (эндпоинты участников/супервайзеров/мониторов/статистики/синка, строки 344–1348) | GET/POST | см. `docs/API.md` бэкенда — контроллеры `BuraxilishesController`, `SupervisorsController`, `MonitorsController`, `StatisticsController` | не расписаны построчно — полный проход по каждому вызову не делался |
| `checkAppVersion()` (примерно) | GET | `/admin/appversion` | проверка обновлений |
| `AdminService.getDownloadStatus()` | GET | `/admin/downloadstatus` | Cihazların statusu: скачивание офлайн-базы по зданиям |
| `AdminService.getDeviceLogins()` | GET | `/admin/devicelogins` | устройства/входы за дату |
| `AdminService.revokeDevices()` | POST | `/admin/devices/revoke` | отзыв устройств (с подтверждением в UI) |
| `AdminService.getCurrentUser()` | GET | `/auth/me` | Profil |
| `AdminService.sendEmergencyMessage()` | POST | `/emergencymessages/send` | Təcili elan |
| `AdminService.getEmergencyHistory()` | GET | `/emergencymessages/history?take=` | история срочных сообщений |
| `HttpService` (смена пароля) | POST | `/password/changepassword` | Şifrəni dəyiş (вызов существовал, переиспользован) |
| `StatisticsService` (админские экраны) | GET | `/buraxilishes/searchparticipants`, `/buraxilishes/getallparticipantswithpagination`, `/buraxilishes/getburaxilish`, `/buraxilishes/getparticipantprotocol`, `/buraxilishes/getallviolatorsinexamdate`, `/supervisors/GetSupervisorDetailDto`, `/monitors/GetMonitorDetailDto`, `/monitors/GetAllMonitorDetailDtoInExamDateAndBuilding` | Bütün iştirakçılar, карточки людей, нарушители |
| `ProtocolService.getProtocols()` | GET | `/protocols` | Protokol hesabatları (админ); `/protocols/my-notes`, `/protocols/my-note` — заметки роли `monitor` |

Все админские вызовы несут `X-Exam-Slot` через интерцептор; новых эндпоинтов вне списка веб-сервисов нет.

Другие HTTP-клиенты помимо `HttpService`:
- `emergency_message_service.dart` — SignalR hub `https://eservices.dim.gov.az/buraxilishScan/api/hubs/emergency` + REST через `package:http` на `/emergencyacks/acknowledge` и `/emergencyacks/pending`.
- `push_notification_service.dart` — REST через `package:http` на `/devicetokens` (POST — загрузка токена, DELETE — удаление).
- `notifications_provider.dart` — REST через `package:http` на `/emergencyacks/pending` и `/emergencyacks/acknowledge` — дублирует URL-константы из `emergency_message_service.dart`.

### Формат дат
Full-switch (9.2): запросы больше не несут строковую дату экзамена вообще — только `X-Exam-Slot`. `DateFormatter` теперь содержит только display-форматтеры (`formatDateTimeToAz`/`formatDateToAz`/`formatISOToAz`) для показа реальных `DateTime`/ISO-значений (время регистрации, протоколы) — API-ориентированные конвертеры азербайджанской словесной даты (`dateToAzToDate*`, `dateFromAzToDate`, `parseAzerbaijaniDate`, `azerbaijaniDateToISO*`) удалены вместе с тремя их дублирующими копиями (`HttpService._formatExamDateForApi*`, `StatisticsService._convertToMMDDYYYY*`) и с `DatabaseService._normalizeDateKey`.

Подробнее — `SYSTEM_OVERVIEW.md` §7.2 в бэкенд-репо.

## 14. Мёртвый код

Full-switch (9.2) удалил весь ранее выявленный мёртвый код (0 импортов вне собственного файла/группы, ссылался на удалённые из контракта поля/сигнатуры и не собрался бы после миграции): `lib/patterns.dart`, `lib/core/` (`auth_strategy.dart`, `commands.dart`, `service_factory.dart`), `lib/repositories/` (`auth_repository.dart`, `participant_repository.dart`), `lib/providers/enhanced_participant_provider.dart`, `lib/services/http_service_cleaned.dart`, `lib/screens/dashboard_screen.dart`, `lib/widgets/exam_date_dropdown.dart`.

Остаётся: `lib/providers/participant_provider.dart` — `_isOnlineMode = false` захардкожено, геттер есть, значение никогда не меняется (мёртвая ветка логики, унаследовано из старого отчёта, не в рамках full-switch). `lib/models/registered_participant.dart`/`registered_supervisor.dart` — те же 0-импортов-вовне модели, всё ещё несут легаси-поле `imt_Tarix`/`examDate`; вне зоны `mobile_inventory.md`, не тронуты.

Не проверено так же тщательно (не хватило времени пройтись по каждому из файлов): `lib/services/storage_service.dart`, `lib/screens/database_people_screen.dart` vs `registered_people_screen.dart` (не сравнивались функционально).

Admin redesign (этап 5) удалил `lib/screens/protocol_reports_screen.dart` (заменён `AdminProtocolReportsScreen`; в `participant_screen.dart`/`supervisor_screen.dart` вкладка «Protokollar» всегда ведёт на `ProtocolNotesScreen`) и старые админские экраны статистики/дашборда (`real_dashboard_screen`, `buildings_statistics_screen`, `rooms_statistics_screen`, `building_details_screen`, `room_monitors_screen`).

Недостижимые из `main.dart` файлы на момент этапа 5 (0 импортов, были такими и до редизайна, не тронуты): `lib/core/result.dart`, `lib/models/registered_participant.dart`, `lib/models/registered_supervisor.dart`, `lib/screens/database_people_screen.dart`, `lib/screens/registered_people_screen.dart`, `lib/services/storage_service.dart`, `lib/utils/app_logger.dart`, `lib/utils/device_detector.dart`, `lib/utils/exceptions.dart`, `lib/widgets/app_drawer.dart`, `lib/widgets/default_screen_widget.dart`, `lib/widgets/person_info_widget.dart`.

## 15. Админский UI-кит (`lib/widgets/admin/`)

Все экраны админки собираются только из этого кита (импорт — `admin_widgets.dart`); эталон визуального языка — экраны роли `monitor` (`GradientBackground`, `ScreenHeader`, `BaseDrawer`). Спецификация и этапы — `docs/admin-redesign/SPEC.md` (все 5 этапов выполнены).

| Виджет | Назначение |
|---|---|
| `AdminPage` (`.list`, `.builder`) | Каркас: градиент + шапка (заголовок, подзаголовок, «назад»/«меню», `actions`, закреплённый `headerBottom`) + тело с `maxWidth`; `inShell` — внутри вкладки, без своего Scaffold; `onRefresh` → `RefreshIndicator`; `.builder` — ленивые длинные списки |
| `AdminLayout` | Брейкпоинты по ширине, `columns`/`maxContentWidth`/`horizontalPadding`/`useRail` |
| `AdminGrid` | Непрокручиваемая сетка плиток/карточек (равная высота рядов, без aspect ratio — не переполняется при крупном шрифте) |
| `AdminCard`, `AdminGlassCard` | Белая карточка 95 % (тёмная — `surfaceDark`) / «стеклянный» hero-блок |
| `AdminStatTile`, `AdminProgressRow` (+ `colorForRate`), `AdminMenuTile` | Число+подпись; строка «X / Y — %» с прогрессом; плитка меню |
| `AdminListTile` (+ `codeLeading`), `AdminStatusBadge`, `AdminPersonHeader`, `AdminKeyValueList` | Списки, статусы, шапка и поля карточки человека |
| `AdminSearchField` (debounce 400 мс), `AdminSegmented`, `AdminSortMenu`, `AdminFilterChips`, `AdminPhoneChips`, `AdminActionButton` | Поиск, сегменты, сортировка, фильтры, телефоны, кнопки действий |
| `AdminLoading` / `AdminEmptyState` / `AdminErrorState` | Состояния на градиенте (белые), ошибка с «Yenidən cəhd et» |
| `AdminExamBar` (`.connected`) | Строка активного экзамена + «Dəyiş» (переключатель слота) |
| `AdminStyle` | Цвета, зависящие от темы |

### Правила

- **Цвета и стиль:** только `lib/design/app_colors.dart`, `app_spacing.dart`, `app_text_styles.dart`; никаких `Color(0x…)` и `Colors.<оттенок>` (допустимы `Colors.white*`/`black`/`transparent`), `withValues(alpha:)` вместо `withOpacity`, никаких `AppBar` с заливкой — шапка белым по градиенту. Статусы — success/warning/error из `AppColors`.
- **Адаптивность:** `AdminLayout` — `compact < 600`, `medium 600–1024`, `expanded ≥ 1024`. Плитки меню 2/3/4 колонки, карточки 1/2/3, `maxContentWidth` — вся ширина / 840 / 1200, горизонтальный отступ 16/24/32. На `medium+` вместо нижней панели — `NavigationRail`. Длинные названия — `maxLines` + `ellipsis`; тап-цели ≥ 48×48; списки — `ListView.builder`/`SliverList`.
- **Загрузчик + View:** сервисы, таймеры и навигация — только в `…Screen`; `…View` чистый. Автообновление — `AdminAutoRefresh`, камера — `ScanActivityGuard`.
- **Тексты:** азербайджанский; «monitor» в UI запрещён (см. раздел 6).
- **Новый экран админа:** `AdminSection` в `admin_sections.dart` → он появится в drawer и на Əsas.

### Матрица тестов (`test/admin/`)

Для каждого `…View` — виджет-тест через `testAdminMatrix` (`admin_test_harness.dart`): размеры 320×568, 360×640, 412×915, 740×360 (ландшафт), 800×1280, 1280×800 × `textScaler` 1.0/1.5 × светлая/тёмная тема; проверки — `tester.takeException() == null` и ключевые тексты. Ленивые списки внутри `AdminPage.list` разворачиваются `expandViewport(tester, width)`.
