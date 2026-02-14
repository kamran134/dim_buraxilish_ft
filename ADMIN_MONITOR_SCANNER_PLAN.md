# План добавления сканера мониторов в Flutter приложение (Админ-панель)

## 📋 Задача
Добавить функционал сканирования QR-кодов мониторов (İmtahan rəhbərləri) для администратора в Flutter приложении.

## ✅ Требования (от пользователя)
1. ❌ **Здания НЕ нужны** - админ сканирует всех без привязки к зданию
2. ✅ **Сканер доступен из меню** - добавить пункт в AdminDrawer
3. ✅ **Кнопка отмены регистрации** - на странице деталей монитора
4. ✅ **Цвет - зеленый** - для мониторов используем зеленую цветовую схему

## 🎯 Что уже есть
- ✅ SupervisorScreen - можно взять как пример
- ✅ Backend API готов (`/api/monitors/checkmonitor`)
- ✅ QRScanner widget - переиспользуем
- ✅ AdminDrawer - добавим туда пункт меню
- ✅ Роли реализованы (admin может сканировать)

## 📝 Что нужно создать

### 1. Модели для мониторов
**Файлы:**
- `lib/models/monitor_models.dart` - модели Monitor, MonitorResponse
- `lib/models/monitor_detail_dto.dart` - DTO для деталей монитора

**Структуры:**
```dart
class Monitor {
  final int workNumber;
  final String firstName;
  final String lastName;
  final String middleName;
  final String idCardPin;
  final int buildingCode;
  final String? buildingName;
  final int? roomId;
  final String? roomName;
  final DateTime examDate;
  final DateTime? registerDate;
  final String? image;
}

class MonitorResponse {
  final bool success;
  final String message;
  final Monitor? data;
}
```

### 2. HTTP методы для мониторов
**Файл:** `lib/services/http_service.dart`

**Методы для добавления:**
```dart
/// Сканировать монитора (проверить по workNumber и examDate)
Future<MonitorResponse> scanMonitor({
  required String workNumber,
  required String examDate,
}) async {
  try {
    final formattedDate = DateFormatter.dateToAzToDate(examDate);
    
    final response = await _dio.get(
      '/monitors/checkmonitor',
      queryParameters: {
        'workNumber': workNumber,
        'examDate': formattedDate,
      },
    );
    
    if (response.statusCode == 200) {
      return MonitorResponse.fromJson(response.data);
    } else {
      return MonitorResponse(
        success: false,
        message: 'İmtahan rəhbəri tapılmadı',
      );
    }
  } on DioException catch (e) {
    // обработка ошибок
  }
}

/// Отменить регистрацию монитора
Future<ApiResponse> cancelMonitorRegistration({
  required int workNumber,
  required int buildingCode,
  required String examDate,
}) async {
  // реализация
}
```

### 3. Provider для мониторов
**Файл:** `lib/providers/monitor_provider.dart`

**Состояния:**
```dart
enum MonitorScreenState {
  initial,    // начальный экран с кнопками
  scanning,   // открыт QR сканер
  scanned,    // монитор отсканирован
  error,      // ошибка
}
```

**Основные методы:**
- `scanMonitor(String qrCode)` - сканирование QR кода
- `loadMonitorDetails()` - загрузка деталей (если нужно)
- `cancelRegistration()` - отмена регистрации
- `resetToInitial()` - сброс к начальному состоянию
- `setScreenState()` - управление состоянием

### 4. Экран сканирования мониторов
**Файл:** `lib/screens/monitor_screen.dart`

**Структура (по аналогии с SupervisorScreen):**
```
MonitorScreen
├── Initial View (начальный экран)
│   ├── Welcome Card (приветствие + иконка)
│   ├── Scan Button (зеленая кнопка "QR kod skan et")
│   ├── Manual Input Button (кнопка "Əl ilə daxil et")
│   └── Loading/Error Display
├── Scanning View (сканер)
│   └── QRScannerWidget (scannerType: 'monitor')
├── Scanned View (результат)
│   ├── Success Card
│   ├── Monitor Info
│   │   ├── Фото (если есть)
│   │   ├── ФИО
│   │   ├── İş nömrəsi
│   │   ├── Bina
│   │   └── Otaq
│   ├── Действия
│   │   ├── "Növbəti" (следующий)
│   │   └── "Ləğv et" (отменить регистрацию)
│   └── Repeat Indicator (если повторное сканирование)
└── Error View
    ├── Error Message
    └── "Yenidən cəhd et" Button
```

**Цветовая схема:** ЗЕЛЕНАЯ (AppColors.buttonGreen, green-accent)

### 5. Обновление AdminDrawer
**Файл:** `lib/widgets/admin_drawer.dart`

**Добавить пункт:**
```dart
DrawerMenuItem(
  icon: Icons.people_alt,  // или другая подходящая иконка
  title: 'İmtahan rəhbərləri',
  onTap: () {
    Navigator.pop(context);
    _navigateToMonitorScreen(context);
  },
),
```

### 6. Обновление QRScanner widget (если нужно)
**Файл:** `lib/widgets/qr_scanner.dart`

Добавить поддержку типа 'monitor' в `scannerType` (возможно уже есть)

### 7. Обновление ManualInputDialog (если нужно)
**Файл:** `lib/widgets/manual_input_dialog.dart`

Добавить метод:
```dart
static void showMonitorDialog(
  BuildContext context,
  Function(String) onSubmit,
) {
  // Диалог для ручного ввода workNumber монитора
}
```

## 📐 Детальный план реализации

### ЭТАП 1: Создать модели
**Файлы:**
- `lib/models/monitor_models.dart`
- `lib/models/monitor_detail_dto.dart` (если нужно отдельно)

**Действия:**
1. Создать класс `Monitor` с полями
2. Создать класс `MonitorResponse`
3. Реализовать `fromJson` и `toJson`
4. Добавить необходимые геттеры

---

### ЭТАП 2: Добавить HTTP методы
**Файл:** `lib/services/http_service.dart`

**Действия:**
1. Добавить `scanMonitor()` метод
2. Добавить `cancelMonitorRegistration()` метод  
3. Добавить обработку ошибок
4. Протестировать вызовы

---

### ЭТАП 3: Создать Provider
**Файл:** `lib/providers/monitor_provider.dart`

**Действия:**
1. Создать enum состояний `MonitorScreenState`
2. Реализовать все необходимые методы
3. Добавить обработку ошибок и сообщений
4. Добавить loading состояния

---

### ЭТАП 4: Создать MonitorScreen
**Файл:** `lib/screens/monitor_screen.dart`

**Действия:**
1. Создать `_buildInitialView()` - начальный экран
2. Создать `_buildScanningView()` - экран сканирования
3. Создать `_buildScannedView()` - результат сканирования
4. Создать `_buildErrorView()` - экран ошибки
5. Добавить навигационный бар снизу (если нужно)
6. **Использовать ЗЕЛЕНУЮ цветовую схему!**

**Цвета:**
```dart
// Primary color для мониторов
backgroundColor: Color(0xFF059669),  // Зеленый
accentColor: Color(0xFF10B981),     // Светло-зеленый
```

---

### ЭТАП 5: Обновить AdminDrawer
**Файл:** `lib/widgets/admin_drawer.dart`

**Действия:**
1. Добавить новый пункт меню "İmtahan rəhbərləri"
2. Добавить метод навигации `_navigateToMonitorScreen()`
3. Выбрать подходящую иконку (Icons.people_alt или Icons.supervised_user_circle)

---

### ЭТАП 6: Обновить вспомогательные виджеты
**Файлы:**
- `lib/widgets/qr_scanner.dart` (если нужно)
- `lib/widgets/manual_input_dialog.dart`

**Действия:**
1. Проверить поддержку `scannerType: 'monitor'` в QRScanner
2. Добавить `showMonitorDialog()` в ManualInputDialog
3. Настроить заголовки и placeholders для мониторов

---

### ЭТАП 7: Регистрация Provider в main.dart
**Файл:** `lib/main.dart`

**Действия:**
1. Добавить `MonitorProvider` в MultiProvider
2. Проверить порядок провайдеров

---

### ЭТАП 8: Тестирование
**Действия:**
1. ✅ Вход как админ
2. ✅ Открытие меню → "İmtahan rəhbərləri"
3. ✅ Сканирование QR кода монитора
4. ✅ Ручной ввод workNumber
5. ✅ Отображение информации о мониторе
6. ✅ Кнопка "Ləğv et" (отмена регистрации)
7. ✅ Повторное сканирование
8. ✅ Обработка ошибок

---

## 🎨 Цветовая схема (ЗЕЛЕНАЯ)

```dart
// Для мониторов используем зеленые цвета
class MonitorColors {
  static const primary = Color(0xFF059669);      // Green-600
  static const secondary = Color(0xFF10B981);    // Green-500
  static const light = Color(0xFF34D399);        // Green-400
  static const dark = Color(0xFF047857);         // Green-700
  static const surface = Color(0xFFD1FAE5);      // Green-100
}
```

---

## 🔗 API Endpoints (Backend)

```
GET  /api/monitors/checkmonitor?workNumber={workNumber}&examDate={examDate}
POST /api/monitors/cancelregistration?workNumber={workNumber}&buildingCode={buildingCode}&examDate={examDate}
```

**Примечание:** buildingCode получаем из ответа checkmonitor

---

## ✅ Чек-лист

- [ ] ЭТАП 1: Модели созданы
- [ ] ЭТАП 2: HTTP методы добавлены
- [ ] ЭТАП 3: Provider создан
- [ ] ЭТАП 4: MonitorScreen реализован
- [ ] ЭТАП 5: AdminDrawer обновлен
- [ ] ЭТАП 6: Виджеты обновлены
- [ ] ЭТАП 7: Provider зарегистрирован
- [ ] ЭТАП 8: Тестирование пройдено

---

## 📌 Важные моменты

1. **НЕ нужна привязка к зданию** - админ сканирует всех
2. **Зеленая цветовая схема** - отличается от синих участников и фиолетовых супервайзеров
3. **Кнопка отмены регистрации** - обязательно на экране результата
4. **Переиспользуем компоненты** - QRScanner, ManualInputDialog, GradientBackground
5. **Обработка повторных сканирований** - показать индикатор "Təkrar"

---

## 🚀 Начало работы

После подтверждения плана начинаем с ЭТАПА 1 - создание моделей для мониторов.
