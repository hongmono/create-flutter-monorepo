# create-flutter-monorepo

Flutter Melos v7 monorepo scaffolder with Riverpod + Retrofit + Dio + FastAPI.

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
| Server names | `none` | `api, admin_api` |
| API base URL | `https://api.example.com` | `https://api.myservice.com` |

## What you get

```
my_project/
├── apps/
│   ├── client/                → Flutter app (flutter create)
│   │   ├── android/
│   │   ├── ios/
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── router/
│   │   │   ├── provider/
│   │   │   ├── data/
│   │   │   └── ui/example/
│   │   └── pubspec.yaml
│   └── admin/                 → Flutter app (flutter create)
├── packages/
│   ├── core/                  → Domain models + abstract repositories (freezed)
│   ├── network/               → Dio + Retrofit services + DTOs
│   ├── design_system/         → Design tokens + theme + shared widgets
│   └── lint_rules/            → Shared analysis_options
├── servers/                   → (optional) FastAPI servers
│   ├── api/
│   │   ├── app/
│   │   │   ├── main.py
│   │   │   ├── core/          → Config, DB connection
│   │   │   ├── api/v1/        → API router + endpoints
│   │   │   ├── models/        → SQLAlchemy ORM models
│   │   │   ├── schemas/       → Pydantic request/response DTOs
│   │   │   ├── repositories/  → DB access layer
│   │   │   └── services/      → Business logic
│   │   ├── tests/
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   ├── admin_api/             → Another FastAPI server
│   └── shared/                → Shared code (created when 2+ servers)
├── pubspec.yaml
└── README.md
```

## Setup (after scaffolding)

### Flutter

```bash
cd my_project
dart pub get
dart pub global activate melos
melos bootstrap
melos run gen
```

### Servers

```bash
cd servers/api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Melos scripts

| Command | Description |
|---------|-------------|
| `melos run gen` | Run build_runner (freezed + retrofit + riverpod) |
| `melos run gen:watch` | Watch mode for build_runner |
| `melos run test` | Run tests in all packages |
| `melos run analyze` | Analyze all packages |
| `melos run format` | Format all packages |
| `melos run clean` | Clean all packages |

## Stack

### Flutter
- **State Management**: Riverpod (with code generation)
- **Routing**: GoRouter
- **HTTP**: Dio + Retrofit
- **Code Generation**: Freezed, json_serializable, riverpod_generator
- **Monorepo**: Melos v7 + Pub Workspaces

### Server
- **Framework**: FastAPI
- **ORM**: SQLAlchemy (async)
- **Validation**: Pydantic
- **Migration**: Alembic
