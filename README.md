# create-flutter-monorepo

Flutter Melos v7 monorepo scaffolder with Riverpod + Retrofit + Dio.

## Usage

```bash
curl -sL https://raw.githubusercontent.com/hongmono/create-flutter-monorepo/main/create_flutter_monorepo.sh | bash
```

## What it asks

| Prompt | Default | Example |
|--------|---------|---------|
| Project name | `my_app` | `my_project` |
| App names (comma-separated) | `app` | `client, admin` |
| API base URL | `https://api.example.com` | `https://api.myservice.com` |

## What you get

```
my_project/
├── apps/
│   ├── client/          → Flutter app
│   └── admin/           → Flutter app
├── packages/
│   ├── core/            → Domain models + abstract repositories (freezed)
│   ├── network/         → Dio + Retrofit services + DTOs
│   ├── design_system/   → Design tokens + theme + shared widgets
│   └── lint_rules/      → Shared analysis_options
├── pubspec.yaml         → Pub Workspaces root
└── README.md
```

## Stack

- **State Management**: Riverpod (with code generation)
- **Routing**: GoRouter
- **HTTP**: Dio + Retrofit
- **Code Generation**: Freezed, json_serializable, riverpod_generator
- **Monorepo**: Melos v7 + Pub Workspaces
