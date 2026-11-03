# ТЗ: админская часть мобильного приложения — перенос веб-админки и единый дизайн

Ветка: `admin-redesign` (от `ios-build`). Работа идёт этапами, каждый этап — отдельная сессия,
строго по очереди. Этап закрывается коммитом в эту ветку. **Не пушить**, не поднимать версию,
не собирать релиз.

## 0. Контекст

- Приложение: Flutter, `D:/Work/DIMBuraxilishFlutter/dim_buraxilish_ft`. Архитектура — `docs/ARCHITECTURE.md`.
- Веб-админка (Angular, источник того, ЧТО переносить): `D:/Others Programs/Buraxilish_Front`,
  маршруты `src/app/modules/admin/admin/admin-routing.module.ts`, компоненты
  `src/app/modules/admin/components/**`, сервисы `src/app/services/*.service.ts`.
  Из веба переносится состав данных, колонки, фильтры, поведение. Вёрстку веба НЕ копировать.
- API бэкенда: `D:/Others Programs/BuraxilishBackend/docs/API.md`. Бэкенд не меняем.
- Роли: `admin`/`superadmin` → админка (этот ТЗ). `monitor` (учётка здания) → экраны зданий — **не трогать**.
- Язык UI — азербайджанский, как сейчас. Слово «monitor» в UI запрещено: роль monitor =
  «Ümumi imtahan rəhbəri», люди в залах — «imtahan rəhbəri / imtahan rəhbərləri».
- Комментарии и идентификаторы в коде — только на английском.

## 1. Что делаем (решение владельца)

1. Админская часть приложения пересобирается: из старого остаётся только сканер imtahan rəhbərləri
   (`monitor_screen.dart`, `monitor_search_screen.dart`, `MonitorProvider`) и его статистика
   (по залам/зданиям) — **логику не трогаем, только переодеваем в общий дизайн**.
2. Переносятся из веб-админки:
   - Əsas (главная админа, веб `admin-home`);
   - Statistika: iştirakçılar по зданиям (`binalar-statistic` → `bina-buraxilish` → `participant-details`),
     nəzarətçilər по зданиям (`supervisor/building-supervisors-statistic` → `bina-supervisors` → `supervisor-details`),
     imtahan rəhbərləri (`monitor/building-monitors-statistic` → `room-monitors` / `bina-monitors` → `monitor-details`);
   - Bütün iştirakçılar (`all-participants`, серверный поиск + пагинация);
   - Protokol hesabatları (`protocol-reports`);
   - Cihazların statusu (`device-download-status`, включая отзыв устройства `admin/devices/revoke`);
   - Təcili elan (`emergency-message`: отправка + история);
   - Profil + Şifrəni dəyiş (`user-profile`, `change-password`).
3. **НЕ переносим**: всё, что связано с импортом/загрузкой (exams, buraxilish-transfer, add-supervisor,
   add-monitor, photos, login-parametrs), barcode, building-management, user-management,
   Excel-выгрузки.
4. Не трогаем общие с ролью monitor экраны: `login_screen`, `exam_select_screen` (кроме одной строки
   роутинга админа), `settings_screen`, `notifications_screen`, `home_screen`, `main_screen`,
   `participant_screen`, `supervisor_screen`, `statistics_screen` (кроме удаления админской ветки, этап 2),
   офлайн-база, unsent, протокольные заметки.

## 2. Дизайн — эталон = экраны зданий (роль monitor)

Владелец: «то, что было для мониторов, этот дизайн оставляем, админский подстраиваем под него».
Эталонные файлы — открыть и повторить визуальный язык:
`lib/screens/home_screen.dart`, `lib/screens/participant_screen.dart`, `lib/screens/unsent_data_screen.dart`,
`lib/screens/protocol_notes_screen.dart`, `lib/widgets/common/{gradient_background,screen_header,action_button,message_display}.dart`,
`lib/widgets/common/base_drawer.dart`.

Визуальный язык эталона:
- Фон всего экрана — `GradientBackground` (светлая тема: `primaryLight → primaryDark → primary`;
  тёмная: `darkGradient1..3`). Никаких белых/серых Scaffold-фонов и Material `AppBar` с цветной заливкой.
- Шапка — белый текст и белые иконки на градиенте (как `ScreenHeader`); главная — крупная шапка
  как `SliverAppBar` в `home_screen` (название + строка экзамена с `swap_horiz` и «Dəyiş»).
- Hero/акцентные блоки — «стекло»: `Colors.white` 15 %, радиус 20, мягкая тень.
- Контентные карточки/списки — белая карточка 95 % (тёмная тема: `AppColors.surfaceDark`), радиус 20,
  тень `black 10 %, blur 10, offset (0,5)`, внутренний отступ 16.
- Плитки меню — как `MenuCard` в `home_screen` (иконка, подпись, бейдж).
- Индикаторы загрузки, пустые состояния и ошибки на фоне — белые (`CircularProgressIndicator` белый,
  иконка 80 white70, текст white90); ошибки — `MessageDisplay`.
- Цвета только из `lib/design/app_colors.dart`, отступы из `app_spacing.dart`, шрифты из `app_text_styles.dart`.
  Сырые `Color(0x…)` в новых/переделанных файлах запрещены. Статусы: success/warning/error из AppColors.
- Новые `withOpacity` не добавлять — использовать `withValues(alpha: …)`.

### 2.1. Общий UI-кит админки — `lib/widgets/admin/`

Все админские экраны собираются ТОЛЬКО из этого кита (этап 1 его создаёт, следующие этапы — дополняют
при необходимости, не дублируя):

| Виджет | Назначение |
|---|---|
| `AdminPage` | Каркас экрана: `GradientBackground` + шапка (заголовок, подзаголовок, кнопка «назад» ИЛИ «меню», `actions`) + тело; `RefreshIndicator` опционально; тело центрируется с `maxWidth` из `AdminLayout`. Флаг `inShell` — внутри вкладки нижней панели показывает «меню» вместо «назад». |
| `AdminLayout` | Брейкпоинты по ширине: `compact < 600`, `medium 600–1024`, `expanded ≥ 1024`; `columns` для сеток (плитки 2/3/4, карточки 1/2/3), `maxContentWidth` (compact — вся ширина, medium 840, expanded 1200), горизонтальный отступ 16/24/32. |
| `AdminCard` | Белая контентная карточка (см. выше), опциональные `title`, `trailing`, `onTap`. |
| `AdminGlassCard` | «Стеклянный» hero-блок. |
| `AdminStatTile` | Число + подпись + иконка + опциональный цвет-акцент и процент; используется в сетках сводки. |
| `AdminProgressRow` | Строка «подпись — X / Y — %» + линейный прогресс (регистрация по зданию/залу). |
| `AdminListTile` | Строка списка: leading (фото/иконка/код здания), title, subtitle, trailing (бейдж/шеврон). |
| `AdminStatusBadge` | Пилюля статуса (registered / not registered / online / offline / warning). |
| `AdminSearchField` | Поле поиска на градиенте (белое, радиус 16, иконка, кнопка очистки, debounce 400 мс). |
| `AdminSegmented` | Переключатель сегментов (например İştirakçılar / Nəzarətçilər / İmtahan rəhbərləri). |
| `AdminSortMenu` | Сортировка списка (по коду, названию, % регистрации — по возрастанию/убыванию). |
| `AdminEmptyState` / `AdminErrorState` / `AdminLoading` | Состояния в стиле эталона; `AdminErrorState` с кнопкой «Yenidən cəhd et». |
| `AdminExamBar` | Строка активного экзамена (из `AuthProvider.activeExamHeaderLabel`) + «Dəyiş» → переключатель сеанса (переиспользовать `session_switcher_sheet` / `SlotSwitcher` как в `home_screen`). |
| `AdminPersonHeader` | Шапка карточки человека: фото (`photo_widget`), ФИО, ключевой идентификатор, статус. |
| `AdminKeyValueList` | Список «метка — значение» для экранов деталей. |

### 2.2. Адаптивность (обязательно)

- Нулевой `RenderFlex overflow` на ширинах 320, 360, 412 (портрет), 740×360 (ландшафт телефона),
  800×1280, 1280×800 (планшет), при `textScaler` 1.0 и 1.5 и при максимальном размере из `FontProvider`.
- Длинные названия зданий/ФИО — `maxLines` + `ellipsis`, никогда не обрезка по ширине без многоточия.
- Таблицы веба на телефоне превращаются в карточки/строки списка; на `expanded` допускается 2–3 колонки карточек.
- Нижняя панель + drawer: в ландшафте/планшете (`medium+`) вместо нижней панели — `NavigationRail` слева
  (те же 4 пункта), drawer остаётся.
- Все тап-цели ≥ 48×48. Списки — `ListView.builder`/`SliverList` (без построения всех элементов сразу).

### 2.3. Тестируемость

Каждый новый/переделанный экран делится на «загрузчик» (State с сервисами) и чистый `…View`
(принимает данные и колбэки). Для каждого `…View` — widget-тест в `test/admin/`, который
пампит его с фикстурными данными на размерах из 2.2 и `textScaler` 1.0/1.5, светлая и тёмная тема,
и проверяет отсутствие исключений (`tester.takeException() == null`) и ключевые тексты.
Старый `test/widget_test.dart` (шаблонный счётчик, не относится к приложению) — удалить на этапе 1.

## 3. Навигация админа

- После логина и выбора экзамена админ попадает в `AdminShell` (новый, `lib/screens/admin/admin_shell.dart`)
  вместо `RealDashboardScreen`. Места роутинга: `exam_select_screen.dart:227`, `splash_screen.dart:157`
  (и любые другие ссылки на `RealDashboardScreen`).
- Нижняя панель (`NavigationBar`, стиль эталона — тёмно-синяя/«стеклянная» на градиенте, белые иконки,
  выделение белым) — 4 вкладки, `IndexedStack` (состояние вкладок сохраняется):
  1. **Əsas** — главная админа;
  2. **Statistika** — статистика по зданиям (сегменты İştirakçılar / Nəzarətçilər / İmtahan rəhbərləri);
  3. **Skan** — сканер imtahan rəhbərləri (`MonitorScreen`);
  4. **Protokollar** — протокол hesabatları.
- Drawer (переписанный `admin_drawer.dart` на `BaseDrawer`) — ВСЕ пункты: Əsas, İmtahan rəhbəri skanı,
  Statistika (İştirakçılar / Nəzarətçilər / İmtahan rəhbərləri), Bütün iştirakçılar, Protokol hesabatları,
  Cihazların statusu, Təcili elan, Profil, Şifrəni dəyiş, Ayarlar (существующий `SettingsScreen`),
  Sistemdən çıxış (существующий logout-поток). Пункт, совпадающий с вкладкой, переключает вкладку,
  остальные — `Navigator.push`.
- Системная «назад» на корне вкладки ≠ Əsas → переход на Əsas; на Əsas — стандартное поведение.
- `MonitorScreen` внутри вкладки: без кнопки «назад» в начальном состоянии (параметр `inShell`),
  все внутренние состояния (скан, результат, ошибка) работают как сейчас.

## 4. Этапы

Каждый этап: `flutter analyze --no-pub` → **0 errors**, warnings ≤ базовой линии (4, все в чужих файлах;
в новых/изменённых файлах — 0 warnings), `flutter test` зелёный, `flutter build apk --debug` успешен.
Коммит в `admin-redesign` с осмысленным сообщением (англ.), строка
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` в конце. В конце этапа — короткий отчёт:
что сделано, файлы, результат analyze/test/build, что не удалось.

### Этап 1 — кит, оболочка, Əsas — ✅ выполнен
1. Кит `lib/widgets/admin/` целиком (2.1) + `AdminLayout` (2.2) + тесты кита.
2. `AdminShell` + новая нижняя панель/rail + переписанный `admin_drawer.dart` (3). Пункты drawer для
   экранов следующих этапов пока ведут на существующие старые экраны, если они есть
   (статистика зданий → `buildings_statistics_screen`, протоколы → `protocol_reports_screen`), иначе
   скрыты. Вкладки Statistika/Protokollar на этом этапе — старые экраны внутри вкладки (временно).
3. **Əsas** (`lib/screens/admin/admin_home_screen.dart`): шапка как в `home_screen` (DİM / «Admin panel»,
   имя пользователя, `AdminExamBar`), сетка сводки `AdminStatTile` (всего участников / зарегистрировано /
   не зарегистрировано / % — плюс nəzarətçilər и imtahan rəhbərləri: всего / зарегистрировано), блок
   «Ən aşağı qeydiyyat» — 5 зданий с минимальным % (`AdminProgressRow`, тап → детали здания), сетка
   быстрых переходов (`MenuCard`-стиль) на разделы drawer. Данные — те же вызовы, что использует
   `real_dashboard_screen.dart` (`StatisticsService`), плюс то, что показывает веб `admin-home`. Опрос
   каждые 30 с, pull-to-refresh. Реакция на смену сеанса — как в `real_dashboard_screen` (`_loadForActiveSlot`).
4. Роутинг админа на `AdminShell`. Удалить `real_dashboard_screen.dart` и всё, что после этого стало
   неиспользуемым (проверить grep'ом; общие с monitor виджеты не удалять).

### Этап 2 — Statistika — ✅ выполнен
1. Вкладка Statistika: `AdminSegmented` İştirakçılar / Nəzarətçilər / İmtahan rəhbərləri, у каждого
   сегмента — сводка сверху + список зданий (`AdminProgressRow`/`AdminListTile`), `AdminSearchField`
   (код/название здания), `AdminSortMenu`. Состав/колонки — из веб-компонентов `binalar-statistic`,
   `building-supervisors-statistic`, `building-monitors-statistic`.
2. Drill-down:
   - здание → участники здания (веб `bina-buraxilish`: фильтр зарегистрирован/нет, поиск, нарушители
     `getviolatorsinbuildingandexamdate`) → детали участника (`participant-details`: фото, данные, протокол
     `buraxilishes/getparticipantprotocol`, отмена регистрации `buraxilishes/cancelregistration` с подтверждением);
   - здание → nəzarətçilər здания (`bina-supervisors`) → детали (`supervisor-details`, отмена регистрации);
   - imtahan rəhbərləri: по залам (существующие `rooms_statistics_screen`/`room_monitors_screen` —
     переодеть, логику сохранить) и по зданию (`bina-monitors`) → детали (`monitor-details`, отмена регистрации).
3. Существующие `buildings_statistics_screen.dart`, `building_details_screen.dart`, `rooms_statistics_screen.dart`,
   `room_monitors_screen.dart` — переписать в `lib/screens/admin/statistics/` на кит, старые удалить.
   Сервисы (`StatisticsService`, `HttpService`) дополнять недостающими методами, существующие сигнатуры
   не ломать. Новые эндпоинты — только из списка веб-сервисов, с `X-Exam-Slot` (интерцептор уже есть).
4. Удалить админскую ветку из `statistics_screen.dart` (`_loadAdminStatistics`, `_buildAdminStatisticsView`,
   `isAdmin` в `StatisticsTabBar` и т. п.) — поведение для роли monitor не должно измениться ни на пиксель.

### Этап 3 — Skan, Protokollar, Bütün iştirakçılar — ✅ выполнен
1. `monitor_screen.dart`, `monitor_search_screen.dart` — переодеть на кит/эталон (убрать сырые цвета),
   добавить `inShell`. Логика провайдера, сканера, ручного ввода, подтверждений — без изменений.
2. Protokol hesabatları — новый экран на ките по вебу `protocol-reports` (фильтры, группировка, просмотр
   записи); старый `protocol_reports_screen.dart` удалить, если больше не используется (проверить
   `monitor_drawer.dart` — там тоже есть пункт для админа; убрать его оттуда, раз админ туда не попадает).
3. Bütün iştirakçılar — новый экран: `buraxilishes/searchparticipants` + `getallparticipantswithpagination`,
   бесконечная прокрутка, поиск, тап → детали участника из этапа 2.

### Этап 4 — Cihazların statusu, Təcili elan, Profil, Şifrə — ✅ выполнен
1. Cihazların statusu — по вебу `device-download-status` (`admin/downloadstatus`, `admin/devicelogins`,
   `admin/devices/revoke` с подтверждением), автообновление 30 с, фильтры, бейджи онлайн/офлайн/неотправленные.
2. Təcili elan — по вебу `emergency-message`: выбор зданий (поиск, «выбрать все»), текст, отправка
   `emergencymessages/send` с подтверждением, история `emergencymessages/history`.
3. Profil (`auth/me`) и Şifrəni dəyiş (`password/changepassword`; в `HttpService` вызов уже есть — переиспользовать).

### Этап 5 — зачистка и документация — ✅ выполнен
1. Grep на неиспользуемые файлы/виджеты после этапов 1–4, удалить мёртвое (только то, на что 0 ссылок).
2. Проверить, что в админских экранах нет сырых цветов, `AppBar` с заливкой и слова «monitor» в UI.
3. Обновить `docs/ARCHITECTURE.md` §6 (экраны) и §13 (новые эндпоинты), добавить раздел про админ-кит.

## 5. Не трогать

- Бэкенд, веб-фронт.
- Экраны и провайдеры роли monitor (см. п. 1.4), офлайн-БД и её схему, `SyncService`, push/emergency-сервисы приёма.
- `pubspec.yaml` (версия, зависимости) — новые пакеты не добавлять без согласования.
- Ветки `ios-build`, `main`; push запрещён.

## 6. Базовая линия (03.11.2026, ветка ios-build @ 3608589)

- `flutter analyze --no-pub`: 0 errors, 4 warnings (protocol_service unused import, app_logger `_getEmoji`,
  gradient_background и message_display unreachable default), 429 issues всего.
- Тесты: только шаблонный `test/widget_test.dart` (нерелевантен, удаляется на этапе 1).
