# RouteX — полный handoff для разработчика

Дата состояния: 27 июля 2026  
Рабочая директория: `C:\Users\FSOS\Desktop\FlClashX-dev`

## 1. Что это за проект

RouteX — собственный современный Windows-клиент для Clash, построенный на базе
FlClashX.

Исходная база:

- https://github.com/pluralplay/FlClashX/tree/main
- https://github.com/pluralplay/FlClashX/tree/dev

FlClashX используется как техническая основа:

- управление Clash Core;
- профили и подписки;
- DNS;
- TUN;
- Proxy Groups;
- Rules;
- Providers;
- подключения и логи;
- platform-specific интеграция.

Задача — не перекрасить FlClashX и не оставить его стандартный интерфейс.
Над существующим ядром должен быть построен самостоятельный продукт RouteX со
своей дизайн-системой, навигацией и основными пользовательскими сценариями.

## 2. Главная идея продукта

Главная функция RouteX — визуальное управление маршрутизацией трафика отдельных
приложений и браузерных вкладок.

Пользователь должен видеть:

- все открытые приложения;
- название и настоящую иконку;
- PID;
- путь к исполняемому файлу;
- заголовок окна;
- текущую сетевую активность;
- upload/download;
- активные подключения;
- домены и IP-адреса;
- браузерные вкладки, если их можно получить безопасным способом.

Для каждого приложения или домена пользователь выбирает маршрут:

- Proxy;
- Direct;
- Rules;
- Bypass.

Клиент самостоятельно создаёт правила Clash. Пользователь не должен вручную
редактировать YAML.

Планируемые продуктовые возможности:

- drag-and-drop приложений между Proxy и Direct;
- поиск по приложениям, exe и заголовку окна;
- избранные приложения;
- история изменений;
- автоматический выбор лучшего proxy;
- мониторинг latency, upload и download;
- объяснение, почему соединение пошло через конкретный маршрут;
- undo после изменения маршрута;
- обнаружение конфликтующих правил;
- экспорт и импорт пользовательских маршрутов.

## 3. Целевая архитектура

```text
Modern RouteX UI
        ↓
Application Manager
        ↓
Browser Tabs Manager
        ↓
Routing Manager
        ↓
FlClashX services and state
        ↓
Clash Core
```

UI не должен напрямую формировать случайные YAML-фрагменты. Пользовательское
действие сначала преобразуется в модель маршрута, затем Routing Manager
генерирует корректное правило и передаёт его существующему ядру.

## 4. Цель дизайна

Основное направление:

- тёмный desktop-интерфейс;
- iOS 26 Liquid Glass;
- Telegram для iPhone как референс навигации;
- отдельные стеклянные капсулы вместо одной цельной панели;
- мягкое физическое преломление;
- спокойные mint/blue акценты;
- системные шрифты;
- единый набор векторных иконок;
- плавные spring/jelly-анимации;
- нормальный compact и fullscreen layout;
- отсутствие визуального наследия стандартного FlClashX.

Необходимо избегать:

- типичного AI-generated glassmorphism;
- жирных белых обводок;
- случайных свечений;
- множества градиентов друг поверх друга;
- серых пластиковых карточек;
- слишком больших радиусов;
- постоянных декоративных анимаций;
- смешивания ручного `BackdropFilter` и shader-driven Liquid Glass;
- жирных шрифтов в каждом элементе;
- разных стилей иконок на одном уровне.

## 5. Технологический стек

- Flutter / Dart;
- Riverpod;
- Windows desktop;
- FlClashX и Clash Core;
- `liquid_glass_easy`;
- локальный пакет `app_discovery` для списка Windows-приложений.

Основная зависимость Liquid Glass:

```yaml
liquid_glass_easy: 3.4.0
```

Источники:

- https://github.com/AhmeedGamil/liquid_glass_easy
- https://github.com/AhmeedGamil/liquid_glass_easy#readme
- https://pub.dev/packages/liquid_glass_easy
- https://pub.dev/documentation/liquid_glass_easy/latest/
- локальная копия: `D:\liquid_glass_easy-main`

Локальная копия библиотеки имеет версию `3.4.0`.

## 6. Особенность Liquid Glass на Windows

На Windows Flutter использует Skia. В отличие от Impeller на iOS/Android, Skia
не может автоматически читать весь live backdrop.

Правильная структура:

```dart
LiquidGlassView(
  backgroundWidget: capturedBackground,
  child: interfaceContainingLiquidGlassLens,
)
```

На Skia `LiquidGlassLens` преломляет изображение из `backgroundWidget`.
Элементы, находящиеся только внутри `LiquidGlassView.child`, не обязательно
становятся частью захваченного фона.

Это текущая главная архитектурная проблема:

- sidebar находится в `child`;
- active selection lens также находится в `child`;
- локальный цветной underlay sidebar находится в `child`;
- на Windows вложенная линза может получать глобальный background capture, но
  не видеть локальный underlay непосредственно под собой;
- из-за этого эффект отличается от официального iOS/Impeller-примера.

Для заметного преломления captured background должен содержать детали. На
практически однотонном чёрном фоне видны в основном tint и optical rim, поэтому
стекло начинает выглядеть как обычная полупрозрачная панель.

## 7. Официальный визуальный эталон

Перед дальнейшей настройкой необходимо запустить официальный example:

```powershell
Set-Location D:\liquid_glass_easy-main\example
flutter pub get
flutter run -d windows
```

Или собрать его:

```powershell
flutter build windows --release
```

Сравнивать RouteX следует с официальным примером на том же компьютере и том же
Windows backend, а не только со скриншотами iOS.

Особенно важные примеры:

- `D:\liquid_glass_easy-main\example\lib\main.dart`
- `D:\liquid_glass_easy-main\example\lib\lens_image_page.dart`
- `D:\liquid_glass_easy-main\example\lib\control_center_page.dart`
- `D:\liquid_glass_easy-main\example\lib\nav_bar_tuning.dart`
- `D:\liquid_glass_easy-main\example\lib\tuning_store.dart`

Референсные изображения:

- `D:\liquid_glass_easy-main\showcases\liquid_glass_control_center.jpg`
- `D:\liquid_glass_easy-main\showcases\liquid_glass_bottom_nav_bar.gif`
- `D:\liquid_glass_easy-main\showcases\liquid_glass_blending.gif`
- `D:\liquid_glass_easy-main\showcases\liquid_glass_thumbnail.jpg`

## 8. Референсные параметры библиотеки

Пример прозрачного материала из официального проекта:

```dart
const LiquidGlassStyle(
  shape: LiquidGlassShape.continuousRoundedRectangle(
    cornerRadius: 36,
    borderWidth: 1.5,
  ),
  appearance: LiquidGlassAppearance(
    color: Color(0x14FFFFFF),
    saturation: 1.05,
    blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
  ),
  refraction: LiquidGlassRefraction(
    refractionType: OpticalRefraction(
      refraction: 1.5,
      refractionWidth: 24,
      depth: 0.7,
    ),
  ),
)
```

Для navigation selection pill официальный пример использует более слабое
преломление:

```dart
const LiquidGlassStyle(
  appearance: LiquidGlassAppearance(
    color: Colors.transparent,
  ),
  refraction: LiquidGlassRefraction(
    distortion: 0.05,
    distortionWidth: 10,
  ),
)
```

Высокий `borderSolidity` на тёмном однотонном фоне создаёт резкую пластиковую
обводку. Не использовать его глобально.

## 9. Что уже реализовано

### 9.1 Общая дизайн-система

Файл:

`C:\Users\FSOS\Desktop\FlClashX-dev\lib\common\premium_theme.dart`

Содержит:

- цвета RouteX;
- токены радиусов;
- токены анимации;
- иконки основной навигации;
- `RouteXGlassSurface`;
- `RouteXSelectionGlass`;
- общую тёмную и светлую тему.

`RouteXGlassSurface` сейчас использует:

- `LiquidGlassLens`;
- `LiquidGlassShape.continuousRoundedRectangle`;
- `LiquidGlassAppearance`;
- `LiquidGlassBlur`;
- `LiquidGlassRefraction`;
- `OpticalRefraction`;
- `OpticalBorder`.

Старые tint-градиенты, radial highlight и дополнительный `BackdropFilter`
внутри основного компонента удалены.

### 9.2 Общий `LiquidGlassView`

Файл:

`C:\Users\FSOS\Desktop\FlClashX-dev\lib\widgets\scaffold.dart`

Весь viewport обёрнут в `LiquidGlassView`.

Текущие параметры:

```dart
LiquidGlassView(
  backgroundWidget: scene,
  pixelRatio: 1,
  realTimeCapture: isDashboard && !reduceMotion,
  refreshRate: LiquidGlassRefreshRate.high,
  useSync: true,
  child: content,
)
```

На Dashboard capture realtime, потому что фон анимирован. На остальных экранах
используется первый snapshot.

### 9.3 Desktop sidebar

Файл:

`C:\Users\FSOS\Desktop\FlClashX-dev\lib\pages\home.dart`

Реализовано:

- раскрытая ширина 244;
- компактная ширина 88;
- шаг пунктов 56;
- active lens высотой около 52;
- единый moving selection lens;
- компактный selection остаётся центрированной squircle;
- animated expand/collapse;
- нижний routing status;
- отдельная кнопка сворачивания.

Ручной `BackdropFilter` active-tab удалён. Active-tab использует
`RouteXSelectionGlass`.

Остался `_SidebarUnderlay` — это не стеклянная поверхность, а цветной объект,
который создавался как детализация для преломления. На Skia он находится не в
captured background, поэтому его архитектуру необходимо пересмотреть.

### 9.4 Compact bottom navigation

Файл:

`C:\Users\FSOS\Desktop\FlClashX-dev\lib\views\dashboard\widgets\hero_nav_bar.dart`

Реализовано:

- основная стеклянная капсула;
- отдельная круглая кнопка Tools/Settings;
- moving selection lens;
- подписи и иконки;
- compact safe-area layout.

Selection lens переведён на `RouteXSelectionGlass`.

Текущая анимация сделана через `TweenAnimationBuilder`. Это ещё не настоящая
jelly/spring-анимация библиотеки.

Рекомендуется перейти на:

- `LiquidGlassBottomNavBar`;
- `LiquidGlassScaffold`;
- `LiquidGlassNavPillStyle`;
- `LiquidGlassJelly`;
- настройки из `nav_bar_tuning.dart`.

### 9.5 Dashboard

Основные файлы:

- `lib\views\dashboard\dashboard.dart`
- `lib\views\dashboard\widgets\hero_connect.dart`
- `lib\views\dashboard\widgets\hero_nav_bar.dart`

Реализовано:

- новая композиция главного экрана;
- карточка профиля и подключения;
- остаток трафика;
- быстрые кнопки Applications и Locations;
- основной Connect CTA;
- дополнительные status/action cards в fullscreen;
- анимированные mint/blue ambient-orbs;
- top-aligned desktop layout вместо узкой центрированной колонки.

### 9.6 Applications

Основной файл:

`C:\Users\FSOS\Desktop\FlClashX-dev\lib\views\applications\applications_scene.dart`

Связанные файлы:

- `lib\common\application_routing.dart`
- `lib\common\process_icon.dart`
- локальный plugin `plugins\app_discovery`

Реализовано:

- обнаружение открытых приложений Windows;
- название;
- exe;
- PID;
- заголовок окна;
- настоящая иконка;
- поиск;
- счётчики открытых и сетевых приложений;
- Proxy / Direct / Rules;
- сведения о сетевой активности;
- expandable details;
- диалог приложения;
- список live destinations;
- маршрут соединения;
- download/upload.

Основные ручные стеклянные панели этой страницы переведены на
`RouteXGlassSurface`.

Не превращать каждую строку процесса в `LiquidGlassLens`: документация пакета
не рекомендует помещать множество линз внутрь scrolling list. Стекло должно
оставаться shell/overlay-примитивом.

### 9.7 App bar

Файл:

`lib\widgets\scaffold.dart`

Ручной `BackdropFilter` и старый gradient material удалены. Верхняя панель
использует `RouteXGlassSurface`.

### 9.8 Empty states

Файл:

`lib\widgets\null_status.dart`

Empty-state карточки используют общий стеклянный материал.

## 10. На чём остановились

Последнее выполненное состояние:

1. `liquid_glass_easy` обновлён до `3.4.0`.
2. Общий `LiquidGlassView` подключён.
3. Основные старые ручные glass-слои удалены.
4. Desktop sidebar и bottom navigation используют библиотечные линзы.
5. App bar использует библиотечную линзу.
6. Основные glass panels Applications используют библиотечную линзу.
7. Предварительный blur captured background уменьшен с 12 до 4.
8. Затемняющий overlay captured background уменьшен.
9. Pixel ratio Skia capture поднят до 1.
10. Release-сборка проходит.
11. Приложение запускается без чёрного экрана.

Текущий результат всё ещё не считается финальным.

Главные нерешённые проблемы:

- материал не выглядит идентично официальному showcase;
- captured background слишком тёмный и мало детализирован;
- nested lenses на Skia не получают локальный backdrop так же, как Impeller;
- нижняя навигация не использует официальный jelly nav component;
- fullscreen и compact требуют ещё одного целостного визуального прохода;
- часть старых FlClashX-экранов всё ещё визуально отличается от RouteX;
- light theme сейчас существует, но основной приоритет продукта — качественная
  тёмная тема;
- некоторые обычные контентные карточки всё ещё используют старые цвета и
  радиусы, хотя они не являются glass surfaces.

## 11. Что требуется сделать следующим разработчику

### Этап 1. Запустить официальный showcase

Проверить реальное поведение пакета 3.4.0 на Windows.

Снять скриншоты:

- большая линза поверх фотографии;
- Control Center;
- bottom nav;
- squircle;
- continuous rounded rectangle;
- optical и classic border.

### Этап 2. Сделать RouteX Glass Playground

Создать временный внутренний экран, где можно на лету регулировать:

- tint;
- blur;
- saturation;
- distortion;
- distortionWidth;
- refraction index;
- refractionWidth;
- depth;
- borderWidth;
- borderSaturation;
- ambientIntensity;
- borderSolidity;
- lightSpread;
- pixelRatio;
- capture refresh rate.

Показывать рядом:

- официальный reference material;
- navigation material;
- panel material;
- selection material;
- dialog material.

После выбора значений сохранить их в семантические токены.

### Этап 3. Переделать captured background

В `LiquidGlassView.backgroundWidget` должен находиться реальный RouteX backdrop:

- чёрная основа;
- медленный тёмный animated mesh;
- несколько очень мягких mint/blue областей;
- тонкая текстура/noise;
- умеренная детализация около navigation surfaces;
- Reduce Motion support.

Не использовать яркую фотографию в продукте. Фотография нужна только для
диагностики шейдера.

### Этап 4. Разделить стили материала

Вместо одного глобального glass style создать:

```dart
enum RouteXGlassVariant {
  navigation,
  selection,
  panel,
  dialog,
  control,
}
```

И фабрику:

```dart
LiquidGlassStyle routeXGlassStyle(
  BuildContext context,
  RouteXGlassVariant variant,
)
```

Каждый вариант должен иметь свои параметры, но использовать одну систему
радиусов, tint и optical border.

### Этап 5. Перевести compact nav на официальный компонент

Нужно адаптировать `LiquidGlassBottomNavBar` под `NavigationItem` и Riverpod.

Требования:

- не больше пяти top-level destinations;
- отдельная круглая кнопка Tools;
- spring travel;
- squash/stretch;
- interruption при повторном клике;
- Reduce Motion;
- корректное поведение Skia;
- SVG/custom icon support из версии 3.4.0.

### Этап 6. Полный визуальный аудит

Проверить:

- Dashboard;
- Applications;
- Locations/Proxies;
- Profiles;
- Connections;
- Settings;
- compact window;
- fullscreen;
- dark theme;
- light theme;
- 100%, 125%, 150% Windows scaling;
- keyboard navigation;
- focus states;
- loading/empty/error states;
- длинные русские строки;
- отсутствие обрезанного текста.

## 12. Дизайн-система

Файлы:

- `C:\Users\FSOS\Desktop\FlClashX-dev\design-system\routex\MASTER.md`
- `C:\Users\FSOS\Desktop\FlClashX-dev\design-system\routex\pages\navigation.md`

Основные правила:

- spacing scale: 4, 8, 12, 16, 24, 32;
- card radius: 14–16;
- floating radius: 18–22;
- navigation radius: до 26;
- minimum target: 44×44;
- normal font weights: 400/500;
- selected labels: максимум 600;
- motion: 120/160/220/300 ms;
- Reduce Motion обязателен;
- стекло применяется только на shell/elevation planes;
- строки длинных списков не превращаются в отдельные shader lenses.

## 13. Используемые Codex skills

### UI UX Pro Max

GitHub:

- https://github.com/nextlevelbuilder/ui-ux-pro-max-skill

Локальная установка:

`C:\Users\FSOS\.codex\skills\ui-ux-pro-max`

Основной файл инструкций:

`C:\Users\FSOS\.codex\skills\ui-ux-pro-max\SKILL.md`

Дополнительные правила:

- `C:\Users\FSOS\.codex\skills\ui-ux-pro-max\references\pro-rules.md`
- `C:\Users\FSOS\.codex\skills\ui-ux-pro-max\references\quick-reference.md`

Установка через Codex skill installer либо вручную:

```powershell
git clone https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git
```

После клонирования содержимое skill необходимо поместить в директорию skills,
которую использует конкретная установка Codex.

### Flutter skill

Локальная установка:

`C:\Users\FSOS\.codex\skills\flutter`

Инструкции:

`C:\Users\FSOS\.codex\skills\flutter\SKILL.md`

Используется для:

- Flutter widget architecture;
- state/lifecycle;
- platform behavior;
- производительности;
- desktop layout;
- проверки корректности widget tree.

### Computer Use

Использовался для:

- запуска RouteX;
- визуальной проверки compact/fullscreen;
- проверки sidebar selection;
- проверки bottom navigation;
- поиска чёрного экрана и layout regressions.

Поставляется как Codex plugin/skill. В конкретной установке путь находится
в plugin cache Codex, а управление выполняется через computer-use connector.

### 21st.dev Magic MCP

GitHub:

- https://github.com/21st-dev/magic-mcp
- https://21st.dev/

Использовался как источник UI-компонентов и визуальных референсов.

В проект нельзя коммитить API-ключ 21st. Он должен храниться в переменной
окружения или конфигурации MCP вне репозитория.

Если ранее опубликованный ключ использовался в переписке или логах, его лучше
перевыпустить.

## 14. Команды проекта

Установка зависимостей:

```powershell
Set-Location C:\Users\FSOS\Desktop\FlClashX-dev
flutter pub get
```

Анализ:

```powershell
flutter analyze
```

Форматирование:

```powershell
dart format lib
```

Release build:

```powershell
flutter build windows --release
```

Запуск release:

```powershell
Start-Process `
  -FilePath "C:\Users\FSOS\Desktop\FlClashX-dev\build\windows\x64\runner\Release\FlClashX.exe" `
  -WorkingDirectory "C:\Users\FSOS\Desktop\FlClashX-dev\build\windows\x64\runner\Release"
```

Готовый exe:

`C:\Users\FSOS\Desktop\FlClashX-dev\build\windows\x64\runner\Release\FlClashX.exe`

## 15. Известные предупреждения analyze

В `lib\views\dashboard\widgets\hero_connect.dart` существуют старые
предупреждения:

- неиспользуемый `_LegacyHeroConnect`;
- два discarded Future.

Они не появились из-за Liquid Glass, но их следует исправить отдельным
cleanup-коммитом.

## 16. Git и безопасность изменений

В текущей рабочей директории отсутствует `.git`.

Команда `git status` возвращает:

```text
fatal: not a git repository
```

Перед следующей большой переработкой необходимо:

1. Найти оригинальный Git repository, если `.git` был потерян.
2. Либо инициализировать новый repository.
3. Создать baseline commit.
4. Делать Liquid Glass rewrite отдельными небольшими коммитами.

Пример:

```powershell
git init
git add .
git commit -m "RouteX baseline before liquid glass rewrite"
```

Перед `git add .` проверить, что в проекте нет:

- API-ключей;
- пользовательских конфигов;
- proxy credentials;
- приватных подписок;
- логов;
- содержимого build;
- временных файлов.

## 17. Критерии готовности

Liquid Glass считается готовым, когда:

- официальный example и RouteX проверены на одном Windows backend;
- RouteX использует один shader-driven glass pipeline;
- на glass surfaces нет дополнительных ручных tint/gradient/blur слоёв;
- background capture содержит достаточную детализацию;
- active navigation действительно преломляет фон;
- bottom nav использует естественную jelly/spring-анимацию;
- нет резких белых или cyan-контуров;
- нет серого пластикового материала;
- нет чёрных кадров;
- нет layout shift;
- fullscreen и compact используют одну дизайн-систему;
- интерфейс остаётся читаемым без transparency;
- Reduce Motion отключает непрерывное движение;
- производительность приемлема на Windows.

## 18. Кратко: следующий конкретный шаг

Не продолжать случайно крутить параметры `RouteXGlassSurface`.

Следующая задача:

1. Запустить официальный Windows example.
2. Создать RouteX Glass Playground.
3. Сравнить один и тот же background в example и RouteX.
4. Исправить captured background architecture.
5. Создать пять semantic glass variants.
6. Перевести compact navigation на официальный jelly nav.
7. Только после этого распространять новый материал на остальные экраны.
