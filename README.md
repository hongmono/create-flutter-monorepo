# create-flutter-monorepo

Flutter Melos v7 monorepo scaffolder with **DDD architecture** — Riverpod 3.0 + Retrofit + Dio + Freezed.

## Prerequisites

- Flutter SDK (stable)
- Dart SDK >= 3.x
- `git`, `curl`

## Usage

**Option 1**: Download and run locally (recommended)

```bash
curl -sLO https://raw.githubusercontent.com/hongmono/create-flutter-monorepo/main/create_flutter_monorepo.sh
bash create_flutter_monorepo.sh
```

**Option 2**: Pipe directly (review the script first!)

```bash
curl -sL https://raw.githubusercontent.com/hongmono/create-flutter-monorepo/main/create_flutter_monorepo.sh | bash
```

## What it asks

- **Project name** — lowercase + underscores (default: `my_app`)
- **App names** — comma-separated (default: `app`, e.g. `client, admin`)
- **Organization** — reverse domain (default: `com.example`)
- **Platforms** — comma-separated: ios, android, web, macos, linux, windows (default: `ios,android,web`)
- **API base URL** — (default: `https://api.example.com`)

## What you get

```
my_project/
├── apps/
│   ├── client/                        → Flutter app
│   │   └── lib/
│   │       ├── main.dart
│   │       ├── di/                    → Dependency injection (Riverpod providers)
│   │       └── presentation/          → UI layer
│   │           ├── router/            → GoRouter
│   │           └── example/           → Feature: screen + notifier
│   └── admin/                         → Flutter app
├── packages/
│   ├── domain/                        → DDD Domain: entities, abstract repos, failures
│   ├── data/                          → DDD Data: repo impl, remote datasources, DTOs, Dio
│   ├── design_system/                 → Theme, tokens, shared widgets
│   └── lint_rules/                    → Shared analysis_options
├── pubspec.yaml                       → Workspace root + Melos config
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

## Melos scripts

- `melos run gen` — Run build_runner (freezed + retrofit + riverpod)
- `melos run gen:watch` — Watch mode for build_runner
- `melos run test` — Run tests in all packages
- `melos run analyze` — Analyze all packages
- `melos run format` — Format all packages
- `melos run clean` — Clean all packages

## Stack

- **State Management**: Riverpod 3.0 (with code generation)
- **Routing**: GoRouter
- **Architecture**: DDD (Domain-Driven Design)
- **HTTP**: Dio (Riverpod-managed) + Retrofit
- **Code Generation**: Freezed, json_serializable, riverpod_generator
- **Design System**: Shared design tokens + theme + widgets
- **Monorepo**: Melos v7 + Pub Workspaces

## Features

- SDK versions are automatically detected from your local Flutter/Dart installation
- Package versions are fetched live from pub.dev
- Update mode: re-run on an existing project to add missing components
- Input validation for project names, platforms, and organization
