# create-flutter-monorepo

Flutter Melos v7 monorepo scaffolder with **DDD architecture** — GetIt + Injectable, Riverpod 3.0, Retrofit, Dio, Freezed.

## Prerequisites

- Flutter SDK (stable)
- Dart SDK >= 3.x
- `git`, `curl`

## Quick Start

**Option 1**: Download and run locally (recommended)

```bash
curl -sLO https://raw.githubusercontent.com/hongmono/create-flutter-monorepo/main/create_flutter_monorepo.sh
bash create_flutter_monorepo.sh
```

**Option 2**: Pipe directly

```bash
curl -sL https://raw.githubusercontent.com/hongmono/create-flutter-monorepo/main/create_flutter_monorepo.sh | bash
```

The script will ask for:

- **Project name** — lowercase + underscores (default: `my_app`)
- **App names** — comma-separated (default: `app`, e.g. `client, admin`)
- **Organization** — reverse domain (default: `com.example`)
- **Platforms** — ios, android, web, macos, linux, windows (default: `ios,android,web`)
- **API base URL** — (default: `https://api.example.com`)

After scaffolding:

```bash
cd my_project
dart pub get
dart pub global activate melos
melos bootstrap
melos run gen          # Generate freezed + retrofit + injectable + riverpod
```

---

## Architecture

DDD (Domain-Driven Design) 3-layer architecture with clear dependency direction:

```
presentation → domain ← data
```

- **domain** is pure Dart with zero external dependencies
- **data** depends on domain only
- **presentation** (app) depends on domain only — data is accessed via DI

### Project Structure

```
my_project/
├── apps/
│   ├── client/
│   │   ├── build.yaml                         # Code gen config (generated/ subdir)
│   │   └── lib/
│   │       ├── main.dart                       # Entry point (GetIt init → ProviderScope)
│   │       ├── di/
│   │       │   ├── injection.dart              # GetIt + Injectable setup
│   │       │   ├── generated/injection.config.dart
│   │       │   ├── providers.dart              # GetIt → Riverpod bridge
│   │       │   └── generated/providers.g.dart
│   │       └── presentation/
│   │           ├── router/
│   │           │   ├── app_router.dart          # GoRouter (@riverpod)
│   │           │   └── generated/app_router.g.dart
│   │           └── example/                     # Feature directory
│   │               ├── example_screen.dart       # UI (ConsumerWidget)
│   │               ├── example_notifier.dart     # State (@riverpod AsyncNotifier)
│   │               └── generated/example_notifier.g.dart
│   └── admin/                                   # Additional app (same structure)
│
├── packages/
│   ├── domain/                      # DDD Domain Layer (pure Dart)
│   │   ├── build.yaml
│   │   └── lib/
│   │       ├── domain.dart           # Barrel export
│   │       └── src/
│   │           ├── entity/           # Freezed value objects
│   │           │   ├── example.dart
│   │           │   └── generated/example.freezed.dart
│   │           ├── repository/       # Abstract repository contracts
│   │           │   └── example_repository.dart
│   │           └── failure/          # Domain error types
│   │               ├── app_failure.dart
│   │               └── generated/app_failure.freezed.dart
│   │
│   ├── data/                        # DDD Data Layer (Injectable)
│   │   ├── build.yaml               # auto_register: true
│   │   └── lib/
│   │       ├── data.dart             # Barrel export
│   │       └── src/
│   │           ├── di/
│   │           │   ├── data_injection.dart       # @InjectableInit.microPackage()
│   │           │   ├── generated/data_injection.config.dart
│   │           │   └── data_module.dart          # @module (Dio, DataSource)
│   │           ├── repository/
│   │           │   └── example_repository_impl.dart  # Auto-registered!
│   │           ├── datasource/
│   │           │   └── remote/
│   │           │       ├── example_remote_datasource.dart  # Retrofit
│   │           │       ├── generated/example_remote_datasource.g.dart
│   │           │       └── dto/
│   │           │           ├── example_dto.dart            # Freezed + fromJson + toDomain()
│   │           │           └── generated/
│   │           └── network/
│   │               ├── dio_client.dart           # createDio() factory
│   │               └── interceptor/
│   │                   ├── auth_interceptor.dart
│   │                   └── error_interceptor.dart
│   │
│   ├── design_system/               # Shared UI components
│   │   └── lib/src/
│   │       ├── tokens/               # Colors, Typography, Spacing
│   │       ├── theme/                # AppTheme (light/dark)
│   │       └── widgets/              # AppButton, etc.
│   │
│   └── lint_rules/                  # Shared analysis_options.yaml
│
└── pubspec.yaml                     # Workspace root + Melos config
```

---

## Dependency Injection

Hybrid DI: **GetIt + Injectable** for service objects, **Riverpod** for UI state only.

### Why hybrid?

- **GetIt + Injectable**: Service layer objects (Dio, DataSource, Repository) — singleton/factory lifecycle, auto-registration by file name
- **Riverpod**: UI state (Notifier, Router) — reactive, widget-aware, auto-dispose

### How it works

```
main()
  → configureDependencies()         # GetIt registers all services
  → ProviderScope(child: MyApp())   # Riverpod wraps the widget tree

Widget
  → ref.watch(exampleNotifierProvider)   # Riverpod (UI state)
    → ref.watch(exampleRepositoryProvider)  # Riverpod (GetIt bridge)
      → getIt<ExampleRepository>()           # GetIt (service object)
        → ExampleRepositoryImpl              # Injectable auto-registered
          → ExampleRemoteDataSource          # Injectable @module
            → Dio                            # Injectable @singleton
```

### Auto-registration by file name

`build.yaml` in the data package configures Injectable to auto-register classes based on file name patterns:

```yaml
injectable_generator:injectable_builder:
  options:
    auto_register: true
    file_name_pattern: "_repository_impl$|_usecase$"
```

**No annotation needed!** Just name your file correctly:

```
user_repository_impl.dart     → matches _repository_impl$ → auto-registered as UserRepository
get_examples_usecase.dart     → matches _usecase$          → auto-registered as GetExamplesUsecase
```

The class must `implement` an abstract class — Injectable registers it as that interface automatically.

### What still needs @module

Third-party objects and factory-constructed objects can't be auto-registered. Use `@module` in `data_module.dart`:

```dart
@module
abstract class DataModule {
  @singleton
  Dio get dio => createDio();               // Third-party object

  @injectable
  UserRemoteDataSource userDs(Dio dio) =>
      UserRemoteDataSource(dio);            // Retrofit factory constructor
}
```

### GetIt → Riverpod bridge

In `di/providers.dart`, bridge GetIt services into Riverpod for use in widgets:

```dart
@riverpod
ExampleRepository exampleRepository(Ref ref) => getIt<ExampleRepository>();
```

---

## Code Generation

All generated files output to a `generated/` subdirectory, keeping source files clean.

### build.yaml

Each package has a `build.yaml` that redirects generated output:

```yaml
targets:
  $default:
    builders:
      source_gen|combining_builder:
        options:
          build_extensions:
            "^lib/{{dir}}/{{file}}.dart": "lib/{{dir}}/generated/{{file}}.g.dart"
      freezed:
        options:
          build_extensions:
            "^lib/{{dir}}/{{file}}.dart": "lib/{{dir}}/generated/{{file}}.freezed.dart"
```

### Part directives

All `part` directives point to the `generated/` subdirectory:

```dart
// Before (default)
part 'example.freezed.dart';

// After (this scaffolder)
part 'generated/example.freezed.dart';
```

### .gitignore

Generated files are excluded from version control:

```
**/generated/
```

### Run code generation

```bash
melos run gen          # One-time build
melos run gen:watch    # Watch mode (auto-rebuild on changes)
```

---

## Adding a New Feature

Example: adding a "User Profile" feature.

### Step 1: Domain (pure Dart contracts)

```dart
// packages/domain/lib/src/entity/user.dart
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String email,
  }) = _User;
}

// packages/domain/lib/src/repository/user_repository.dart
abstract class UserRepository {
  Future<User> getProfile();
  Future<User> updateProfile({required String name});
}
```

Update barrel: `packages/domain/lib/domain.dart`

### Step 2: Data (implementation)

```dart
// packages/data/lib/src/datasource/remote/dto/user_dto.dart
@freezed
abstract class UserDto with _$UserDto {
  const UserDto._();
  const factory UserDto({required String id, required String name, required String email}) = _UserDto;
  factory UserDto.fromJson(Map<String, dynamic> json) => _$UserDtoFromJson(json);
  User toDomain() => User(id: id, name: name, email: email);
}

// packages/data/lib/src/datasource/remote/user_remote_datasource.dart
@RestApi()
abstract class UserRemoteDataSource {
  factory UserRemoteDataSource(Dio dio, {String? baseUrl}) = _UserRemoteDataSource;

  @GET('/users/me')
  Future<UserDto> getProfile();
}

// packages/data/lib/src/repository/user_repository_impl.dart
// File name matches _repository_impl$ → auto-registered as UserRepository!
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._remote);
  final UserRemoteDataSource _remote;

  @override
  Future<User> getProfile() async => (await _remote.getProfile()).toDomain();
}
```

Register DataSource in `data_module.dart`:

```dart
@injectable
UserRemoteDataSource userRemoteDataSource(Dio dio) => UserRemoteDataSource(dio);
```

Update barrel: `packages/data/lib/data.dart`

### Step 3: App DI bridge

```dart
// apps/app/lib/di/providers.dart — add one line
@riverpod
UserRepository userRepository(Ref ref) => getIt<UserRepository>();
```

### Step 4: Presentation

```dart
// apps/app/lib/presentation/profile/profile_notifier.dart
@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  @override
  Future<User> build() => ref.watch(userRepositoryProvider).getProfile();
}

// apps/app/lib/presentation/profile/profile_screen.dart
class ProfileScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileNotifierProvider);
    return state.when(
      data: (user) => Text(user.name),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

### Step 5: Generate & run

```bash
melos run gen
```

---

## File Naming Conventions

- **`*_repository_impl.dart`** — Auto-registered by Injectable (implements abstract Repository)
- **`*_usecase.dart`** — Auto-registered by Injectable
- **`*_remote_datasource.dart`** — Retrofit client, registered manually via `@module`
- **`*_dto.dart`** — Freezed DTO with `fromJson()` and `toDomain()`
- **`*_notifier.dart`** — Riverpod AsyncNotifier (`@riverpod class`)
- **`*_screen.dart`** — Flutter ConsumerWidget

---

## Melos Scripts

- `melos run gen` — Run build_runner in all packages (freezed + retrofit + injectable + riverpod)
- `melos run gen:watch` — Watch mode for build_runner
- `melos run test` — Run tests in all packages
- `melos run analyze` — Analyze all packages
- `melos run format` — Format all packages
- `melos run clean` — Clean all packages

---

## Stack

- **Architecture**: DDD (Domain-Driven Design)
- **DI**: GetIt + Injectable (service layer, auto_register by file name)
- **State Management**: Riverpod 3.0 (UI state only)
- **Routing**: GoRouter
- **HTTP**: Dio + Retrofit
- **Code Generation**: Freezed, json_serializable, injectable_generator, riverpod_generator
- **Design System**: Shared design tokens + theme + widgets
- **Monorepo**: Melos v7 + Pub Workspaces

## Features

- SDK versions are automatically detected from your local Flutter/Dart installation
- Package versions are fetched live from pub.dev
- Update mode: re-run on an existing project to add missing components
- Input validation for project names, platforms, and organization
- Generated files output to `generated/` subdirectory (clean source tree)
- Injectable auto-registration by file name pattern (zero boilerplate DI)
