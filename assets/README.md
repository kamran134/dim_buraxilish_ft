# Assets

Эта папка содержит все статические ресурсы приложения.

## Структура:

### 📁 images/
- `logos/` - логотипы организации, приложения
- `icons/` - иконки и графические элементы
- `backgrounds/` - фоновые изображения

## Как использовать:

### PNG изображения:
```dart
// Простое изображение
Image.asset('assets/images/logos/dim_logo.png')

// С указанием размера
Image.asset(
  'assets/images/logos/dim_logo.png',
  width: 100,
  height: 100,
)

// Для высоких разрешений добавьте @2x, @3x версии:
// dim_logo.png      (1x)
// dim_logo@2x.png   (2x)
// dim_logo@3x.png   (3x)
```

### В Container как фон:
```dart
Container(
  decoration: BoxDecoration(
    image: DecorationImage(
      image: AssetImage('assets/images/backgrounds/bg.png'),
      fit: BoxFit.cover,
    ),
  ),
)
```

### В качестве иконки:
```dart
CircleAvatar(
  backgroundImage: AssetImage('assets/images/logos/dim_logo.png'),
  radius: 30,
)
```

## 📋 Примеры файлов для добавления:

1. **Логотипы:**
   - `assets/images/logos/dim_logo.png`
   - `assets/images/logos/ministry_logo.png`

2. **Иконки:**
   - `assets/images/icons/exam_icon.png`
   - `assets/images/icons/student_icon.png`
   - `assets/images/icons/supervisor_icon.png`

3. **Фоны:**
   - `assets/images/backgrounds/login_bg.png`
   - `assets/images/backgrounds/home_bg.png`

## ⚡ После добавления файлов:
1. Выполните `flutter pub get`
2. Перезапустите приложение (hot restart)