# create-flutter-monorepo

Flutter Melos v7 monorepo scaffolder with Riverpod + Retrofit + Dio + Widgetbook.

## Usage

```bash
curl -sL https://raw.githubusercontent.com/hongmono/create-flutter-monorepo/main/create_flutter_monorepo.sh | bash
```

## What it asks

| Prompt | Default | Example |
|--------|---------|---------|
| Project name | `my_app` | `my_project` |
| App names | `app` | `client, admin` |
| Organization | `com.example` | `com.hongmono` |
| Platforms | `ios,android,web` | `ios,android` |
| API base URL | `https://api.example.com` | `https://api.myservice.com` |

## What you get

```
my_project/
├── apps/
│   ├── client/              → Flutter app (flutter create)
│   │   ├── android/
│   │   ├── ios/
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── router/
│   │   │   ├── provider/
│   │   │   ├── data/
│   │   │   └── ui/example/
│   │   └── pubspec.yaml
│   ├── admin/               → Flutter app (flutter create)
│   └── widgetbook/          → Widgetbook catalog
│       └── lib/
│           ├── main.dart
│           └── src/         → Use cases per widget
├── packages/
│   ├── core/                → Domain models + abstract repositories (freezed)
│   ├── network/             → Dio + Retrofit services + DTOs
│   ├── design_system/       → Design tokens + theme + shared widgets
│   └── lint_rules/          → Shared analysis_options
├── pubspec.yaml             → Pub Workspaces root
└── README.md
```

## Setup (after scaffolding)

```bash
cd my_project
dart pub get
dart pub global activate melos
melos bootstrap
melos run gen
```

### Run Widgetbook

```bash
cd apps/widgetbook
flutter run -d chrome
```

## Melos scripts

| Command | Description |
|---------|-------------|
| `melos run gen` | Run build_runner (freezed + retrofit + riverpod + widgetbook) |
| `melos run gen:watch` | Watch mode for build_runner |
| `melos run test` | Run tests in all packages |
| `melos run analyze` | Analyze all packages |
| `melos run format` | Format all packages |
| `melos run clean` | Clean all packages |

## Stack

- **State Management**: Riverpod (with code generation)
- **Routing**: GoRouter
- **HTTP**: Dio + Retrofit
- **Code Generation**: Freezed, json_serializable, riverpod_generator
- **Design System**: Widgetbook (widget catalog with knobs)
- **Monorepo**: Melos v7 + Pub Workspaces
