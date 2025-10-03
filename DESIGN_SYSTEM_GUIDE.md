# Дизайн Система - Руководство по использованию

## Обзор

Эта система дизайна предоставляет централизованное управление цветами, типографикой, отступами и темами для Flutter приложения "DİM Buraxılış Sistemi".

## Структура системы

### 📁 Файлы дизайн-системы

- `app_colors.dart` - Цветовая палитра приложения
- `app_text_styles.dart` - Типографическая система  
- `app_spacing.dart` - Отступы, размеры и константы
- `app_theme.dart` - Основной файл темы + все экспорты

## 🎨 Цвета (AppColors)

### Основная палитра
```dart
AppColors.primary           // Главный синий цвет
AppColors.primaryLight      // Светлый вариант
AppColors.primaryDark       // Темный вариант
AppColors.secondary         // Вторичный цвет
```

### Семантические цвета
```dart
AppColors.success           // Зеленый для успеха
AppColors.error             // Красный для ошибок
AppColors.warning           // Оранжевый для предупреждений
AppColors.info              // Синий для информации
```

### Текстовые цвета
```dart
AppColors.textPrimary       // Основной текст (87% черного)
AppColors.textSecondary     // Вторичный текст (60% черного) 
AppColors.textOnPrimary     // Белый текст на цветном фоне
AppColors.textOnDark        // Белый текст на темном фоне
```

### Градиенты
```dart
AppColors.participantGradient   // Градиент для участников
AppColors.supervisorGradient    // Градиент для супервайзеров
AppColors.orangeGradient        // Оранжевый градиент
AppColors.greenGradient         // Зеленый градиент
AppColors.blueGradient          // Синий градиент
```

## ✍️ Типографика (AppTextStyles)

### Заголовки
```dart
AppTextStyles.h1            // 32px, bold - главные заголовки
AppTextStyles.h2            // 28px, bold - заголовки разделов
AppTextStyles.h3            // 24px, bold - подзаголовки
AppTextStyles.h4            // 20px, semibold - мелкие заголовки
AppTextStyles.h5            // 18px, semibold - заголовки карточек
```

### Основной текст
```dart
AppTextStyles.bodyLarge     // 16px - основной текст
AppTextStyles.bodyMedium    // 14px - вторичный текст
AppTextStyles.bodySmall     // 12px - мелкий текст
```

### Специальные стили
```dart
AppTextStyles.buttonText    // Текст кнопок
AppTextStyles.appBarTitle   // Заголовки AppBar
AppTextStyles.cardTitle     // Заголовки карточек
AppTextStyles.caption       // Подписи
AppTextStyles.errorText     // Текст ошибок
AppTextStyles.successText   // Текст успеха
```

### Стили для темных фонов
```dart
AppTextStyles.whiteHeading  // Белые заголовки
AppTextStyles.whiteBody     // Белый основной текст
AppTextStyles.whiteCaption  // Белые подписи (80% прозрачности)
```

## 📏 Отступы и размеры (AppSpacing)

### Базовые отступы
```dart
AppSpacing.xs      // 4px
AppSpacing.sm      // 8px 
AppSpacing.md      // 16px
AppSpacing.lg      // 24px
AppSpacing.xl      // 32px
AppSpacing.xxl     // 48px
```

### Готовые EdgeInsets
```dart
AppSpacing.paddingMD                    // EdgeInsets.all(16)
AppSpacing.paddingHorizontalLG          // EdgeInsets.symmetric(horizontal: 24)
AppSpacing.screenPaddingAll             // EdgeInsets.all(24)
```

### Готовые SizedBox виджеты
```dart
AppSpacing.gapMD            // SizedBox(height: 16, width: 16)
AppSpacing.verticalGapLG    // SizedBox(height: 24)
AppSpacing.horizontalGapSM  // SizedBox(width: 8)
```

### Размеры компонентов
```dart
AppSpacing.buttonHeight         // 48px
AppSpacing.borderRadiusMD       // 12px
AppSpacing.iconMD               // 24px
AppSpacing.cardElevation        // 2.0
```

## 🎭 Темы (AppTheme)

### Основное использование
```dart
import '../design/app_theme.dart';

// В MaterialApp
MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  // ...
)
```

### Утилиты тем
```dart
// Получить подходящий цвет текста для фона
Color textColor = AppTheme.getTextColorForBackground(backgroundColor);

// Получить стиль с подходящим цветом
TextStyle style = AppTheme.getTextStyleForBackground(
  AppTextStyles.bodyLarge, 
  backgroundColor
);
```

### Дополнительные утилиты (AppThemeUtils)
```dart
// Тени
AppThemeUtils.cardShadow        // Тень для карточек
AppThemeUtils.modalShadow       // Тень для модалов

// Границы и скругления
AppThemeUtils.defaultBorder     // Стандартная граница
AppThemeUtils.smallRadius       // BorderRadius(8)
AppThemeUtils.mediumRadius      // BorderRadius(12) 
AppThemeUtils.largeRadius       // BorderRadius(16)
```

## 📝 Примеры использования

### 1. Создание кнопки с системными стилями
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    padding: AppSpacing.paddingMD,
    shape: RoundedRectangleBorder(
      borderRadius: AppThemeUtils.mediumRadius,
    ),
  ),
  child: Text('Кнопка', style: AppTextStyles.buttonText),
  onPressed: () {},
)
```

### 2. Карточка с системными отступами
```dart
Container(
  margin: AppSpacing.paddingSM,
  padding: AppSpacing.paddingMD,
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppThemeUtils.mediumRadius,
    boxShadow: AppThemeUtils.cardShadow,
  ),
  child: Column(
    children: [
      Text('Заголовок', style: AppTextStyles.cardTitle),
      AppSpacing.verticalGapSM,
      Text('Описание', style: AppTextStyles.bodyMedium),
    ],
  ),
)
```

### 3. Использование в виджетах
```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.screenPaddingAll,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.participantGradient,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Заголовок',
            style: AppTextStyles.whiteHeading,
          ),
          AppSpacing.verticalGapLG,
          Text(
            'Описание', 
            style: AppTextStyles.whiteBody,
          ),
        ],
      ),
    );
  }
}
```

## 🔄 Миграция существующего кода

### Замена старых цветов
```dart
// Старый код ❌
color: Colors.blue

// Новый код ✅  
color: AppColors.primary
```

### Замена отступов
```dart
// Старый код ❌
padding: EdgeInsets.all(16)

// Новый код ✅
padding: AppSpacing.paddingMD
```

### Замена текстовых стилей
```dart
// Старый код ❌
style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)

// Новый код ✅
style: AppTextStyles.h5
```

## 🎯 Совместимость

Система включает псевдонимы для обратной совместимости:
- `AppColors.primaryBlue` → `AppColors.primary`
- `AppTextStyles.heading1` → `AppTextStyles.h1`
- `AppTextStyles.body1` → `AppTextStyles.bodyLarge`

## 📦 Импорт

Для удобства используйте единый импорт:
```dart
import '../design/app_theme.dart';
```

Это автоматически подключает все компоненты дизайн-системы:
- AppColors
- AppTextStyles  
- AppSpacing
- AppTheme
- AppThemeUtils