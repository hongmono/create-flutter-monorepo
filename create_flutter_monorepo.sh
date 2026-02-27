#!/usr/bin/env bash
set -euo pipefail

# ╔═══════════════════════════════════════════════════════════════╗
# ║  Flutter Melos v7 Monorepo Scaffolder                        ║
# ║  Usage:                                                       ║
# ║    bash create_flutter_monorepo.sh                            ║
# ║    curl -sL <raw-url> | bash                                  ║
# ╚═══════════════════════════════════════════════════════════════╝

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${CYAN}→${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1" >&2; exit 1; }

# ── Interactive prompt (works with curl | bash via /dev/tty) ──
ask() {
  local prompt="$1" default="$2" value
  if [[ -n "$default" ]]; then
    echo -en "${CYAN}→${NC} ${prompt} ${DIM}(${default})${NC}: " >/dev/tty
  else
    echo -en "${CYAN}→${NC} ${prompt}: " >/dev/tty
  fi
  read -r value </dev/tty
  echo "${value:-$default}"
}

echo -e "\n${BOLD}${MAGENTA}🚀 Flutter Melos v7 Monorepo Scaffolder${NC}"
echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# ── Collect project info ──
PROJECT_NAME=$(ask "Project name (lowercase, underscores)" "my_app")

if [[ ! "$PROJECT_NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
  err "Invalid project name '$PROJECT_NAME'. Use lowercase + underscores (e.g. my_app)"
fi

if [[ -d "$PROJECT_NAME" ]]; then
  err "Directory '$PROJECT_NAME' already exists."
fi

APP_NAMES_INPUT=$(ask "App names, comma-separated" "app")
ORG=$(ask "Organization (reverse domain)" "com.example")
PLATFORMS_INPUT=$(ask "Platforms, comma-separated (ios,android,web,macos,linux,windows)" "ios,android,web")
SERVER_NAMES_INPUT=$(ask "Server names, comma-separated (enter 'none' to skip)" "none")
BASE_URL=$(ask "API base URL" "https://api.example.com")

# Parse app names into array
IFS=',' read -ra APP_NAMES_RAW <<< "$APP_NAMES_INPUT"
APP_NAMES=()
for name in "${APP_NAMES_RAW[@]}"; do
  name=$(echo "$name" | tr -d ' ')
  if [[ ! "$name" =~ ^[a-z][a-z0-9_]*$ ]]; then
    err "Invalid app name '$name'. Use lowercase + underscores."
  fi
  APP_NAMES+=("$name")
done

# Parse server names into array
SERVER_NAMES=()
if [[ "$SERVER_NAMES_INPUT" != "none" ]]; then
  IFS=',' read -ra SERVER_NAMES_RAW <<< "$SERVER_NAMES_INPUT"
  for name in "${SERVER_NAMES_RAW[@]}"; do
    name=$(echo "$name" | tr -d ' ')
    if [[ ! "$name" =~ ^[a-z][a-z0-9_]*$ ]]; then
      err "Invalid server name '$name'. Use lowercase + underscores."
    fi
    SERVER_NAMES+=("$name")
  done
fi

echo ""

# ── Check prerequisites ──
command -v dart    >/dev/null 2>&1 || err "dart SDK not found. Install Flutter/Dart first."
command -v flutter >/dev/null 2>&1 || err "flutter SDK not found."
command -v curl    >/dev/null 2>&1 || err "curl not found."
command -v git     >/dev/null 2>&1 || err "git not found."

if [[ ${#SERVER_NAMES[@]} -gt 0 ]]; then
  command -v python3 >/dev/null 2>&1 || err "python3 not found. Install Python 3.11+ first."
fi

DART_VERSION=$(dart --version 2>&1 | sed -n 's/.*Dart SDK version: \([0-9][0-9.]*\).*/\1/p')
info "Dart $DART_VERSION detected"

if [[ ${#SERVER_NAMES[@]} -gt 0 ]]; then
  PYTHON_VERSION=$(python3 --version 2>&1 | sed -n 's/.*Python \([0-9][0-9.]*\).*/\1/p')
  info "Python $PYTHON_VERSION detected"
fi

# ── Fetch latest version from pub.dev (macOS + Linux compatible) ──
get_version() {
  local pkg="$1"
  local version
  version=$(curl -sf "https://pub.dev/api/packages/$pkg" \
    | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -1) || true

  if [[ -z "$version" ]]; then
    warn "Failed to fetch version for '$pkg', using 'any'"
    echo "any"
  else
    echo "^$version"
  fi
}

get_pypi_version() {
  local pkg="$1"
  local version
  version=$(curl -sf "https://pypi.org/pypi/$pkg/json" \
    | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -1) || true

  if [[ -z "$version" ]]; then
    warn "Failed to fetch version for '$pkg', using latest"
    echo ""
  else
    echo "==$version"
  fi
}

echo -e "${BOLD}📦 Fetching latest package versions from pub.dev...${NC}\n"

# ── Flutter Dependencies ──
V_MELOS=$(get_version melos)
log "melos: ${CYAN}$V_MELOS${NC}"

V_FLUTTER_RIVERPOD=$(get_version flutter_riverpod)
V_RIVERPOD_ANNOTATION=$(get_version riverpod_annotation)
V_RIVERPOD_GENERATOR=$(get_version riverpod_generator)
V_GO_ROUTER=$(get_version go_router)
log "flutter_riverpod: ${CYAN}$V_FLUTTER_RIVERPOD${NC}"
log "riverpod_annotation: ${CYAN}$V_RIVERPOD_ANNOTATION${NC}"
log "riverpod_generator: ${CYAN}$V_RIVERPOD_GENERATOR${NC}"
log "go_router: ${CYAN}$V_GO_ROUTER${NC}"

V_DIO=$(get_version dio)
V_RETROFIT=$(get_version retrofit)
V_RETROFIT_GENERATOR=$(get_version retrofit_generator)
V_JSON_ANNOTATION=$(get_version json_annotation)
V_JSON_SERIALIZABLE=$(get_version json_serializable)
log "dio: ${CYAN}$V_DIO${NC}"
log "retrofit: ${CYAN}$V_RETROFIT${NC}"
log "retrofit_generator: ${CYAN}$V_RETROFIT_GENERATOR${NC}"

V_FREEZED_ANNOTATION=$(get_version freezed_annotation)
V_FREEZED=$(get_version freezed)
V_BUILD_RUNNER=$(get_version build_runner)
log "freezed_annotation: ${CYAN}$V_FREEZED_ANNOTATION${NC}"
log "freezed: ${CYAN}$V_FREEZED${NC}"
log "build_runner: ${CYAN}$V_BUILD_RUNNER${NC}"

V_FLUTTER_LINTS=$(get_version flutter_lints)
log "flutter_lints: ${CYAN}$V_FLUTTER_LINTS${NC}"

# ── Python Dependencies ──
if [[ ${#SERVER_NAMES[@]} -gt 0 ]]; then
  echo ""
  echo -e "${BOLD}📦 Fetching latest package versions from PyPI...${NC}\n"

  V_FASTAPI=$(get_pypi_version fastapi)
  V_UVICORN=$(get_pypi_version uvicorn)
  V_PYDANTIC=$(get_pypi_version pydantic)
  V_SQLALCHEMY=$(get_pypi_version sqlalchemy)
  V_ALEMBIC=$(get_pypi_version alembic)
  V_HTTPX=$(get_pypi_version httpx)
  V_PYTEST=$(get_pypi_version pytest)
  V_RUFF=$(get_pypi_version ruff)
  log "fastapi: ${CYAN}${V_FASTAPI:-latest}${NC}"
  log "uvicorn: ${CYAN}${V_UVICORN:-latest}${NC}"
  log "pydantic: ${CYAN}${V_PYDANTIC:-latest}${NC}"
  log "sqlalchemy: ${CYAN}${V_SQLALCHEMY:-latest}${NC}"
fi

echo ""

# ── Create root directory ──
info "Creating project: ${BOLD}$PROJECT_NAME${NC}"

mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# ══════════════════════════════════════
# flutter create (apps)
# ══════════════════════════════════════
mkdir -p apps

for APP_NAME in "${APP_NAMES[@]}"; do
  info "Running flutter create for ${BOLD}$APP_NAME${NC}..."
  flutter create --org "$ORG" --project-name "$APP_NAME" --platforms "$PLATFORMS_INPUT" "apps/$APP_NAME" --empty >/dev/null 2>&1
  log "flutter create apps/$APP_NAME"
done

# ── Build workspace entries ──
WORKSPACE_APPS=""
for app_name in "${APP_NAMES[@]}"; do
  WORKSPACE_APPS+="  - apps/$app_name
"
done

# ── Root pubspec.yaml ──
cat > pubspec.yaml << YAML
name: $PROJECT_NAME
publish_to: none

environment:
  sdk: ^3.9.0

workspace:
${WORKSPACE_APPS}  - packages/design_system
  - packages/core
  - packages/network
  - packages/lint_rules

dev_dependencies:
  melos: $V_MELOS

melos:
  scripts:
    gen:
      run: melos exec -c 1 --depends-on build_runner -- dart run build_runner build -d
      description: Run build_runner (freezed + retrofit + riverpod)
    gen:watch:
      run: melos exec -c 1 --depends-on build_runner -- dart run build_runner watch -d
      description: Watch mode for build_runner
    test:
      run: melos exec -- flutter test
      packageFilters:
        dirExists: test
      description: Run tests in all packages
    analyze:
      run: melos exec -- dart analyze .
      description: Analyze all packages
    format:
      run: melos exec -- dart format .
      description: Format all packages
    clean:
      run: melos exec -- flutter clean
      description: Clean all packages
YAML
log "Root pubspec.yaml"

# ── .gitignore ──
cat > .gitignore << 'GITIGNORE'
# Dart/Flutter
.dart_tool/
.packages
build/
*.iml
*.ipr
*.iws
.idea/

# Generated
*.g.dart
*.freezed.dart

# Python
__pycache__/
*.py[cod]
*.egg-info/
.venv/
dist/

# Environment
.env
.env.*
!.env.example

# OS
.DS_Store
Thumbs.db
GITIGNORE
log ".gitignore"

# ── README ──
cat > README.md << MD
# $PROJECT_NAME

Flutter Melos v7 monorepo with Riverpod + Retrofit + Dio.

## Setup

\`\`\`bash
dart pub get
melos bootstrap
melos run gen
\`\`\`

## Scripts

| Command | Description |
|---------|-------------|
| \`melos run gen\` | Run build_runner (freezed + retrofit + riverpod) |
| \`melos run gen:watch\` | Watch mode for build_runner |
| \`melos run test\` | Run tests in all packages |
| \`melos run analyze\` | Analyze all packages |
| \`melos run format\` | Format all packages |
MD
log "README.md"

# ══════════════════════════════════════
# packages/lint_rules
# ══════════════════════════════════════
mkdir -p packages/lint_rules/lib

cat > packages/lint_rules/pubspec.yaml << YAML
name: lint_rules
description: Shared lint rules for $PROJECT_NAME
publish_to: none
resolution: workspace

environment:
  sdk: ^3.9.0

dependencies:
  flutter_lints: $V_FLUTTER_LINTS
YAML

cat > packages/lint_rules/analysis_options.yaml << 'YAML'
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: true
    prefer_single_quotes: true
    sort_child_properties_last: true
    unawaited_futures: true
    prefer_final_locals: true
YAML

cat > packages/lint_rules/lib/lint_rules.dart << 'DART'
// This package provides shared analysis_options only.
DART
log "packages/lint_rules"

# ══════════════════════════════════════
# packages/core
# ══════════════════════════════════════
mkdir -p packages/core/lib/src/{model,repository}

cat > packages/core/pubspec.yaml << YAML
name: core
description: Domain models and abstract repositories
publish_to: none
resolution: workspace

environment:
  sdk: ^3.9.0

dependencies:
  freezed_annotation: $V_FREEZED_ANNOTATION

dev_dependencies:
  build_runner: $V_BUILD_RUNNER
  freezed: $V_FREEZED
YAML

cat > packages/core/analysis_options.yaml << 'YAML'
include: package:lint_rules/analysis_options.yaml
YAML

cat > packages/core/lib/core.dart << 'DART'
library core;

export 'src/model/example.dart';
export 'src/repository/example_repository.dart';
DART

cat > packages/core/lib/src/model/example.dart << 'DART'
import 'package:freezed_annotation/freezed_annotation.dart';

part 'example.freezed.dart';

@freezed
class Example with _$Example {
  const factory Example({
    required String id,
    required String name,
  }) = _Example;
}
DART

cat > packages/core/lib/src/repository/example_repository.dart << 'DART'
import '../model/example.dart';

abstract class ExampleRepository {
  Future<Example> getById(String id);
  Future<List<Example>> getAll();
}
DART

log "packages/core"

# ══════════════════════════════════════
# packages/network
# ══════════════════════════════════════
mkdir -p packages/network/lib/src/{service,dto,interceptor}

cat > packages/network/pubspec.yaml << YAML
name: network
description: Dio client, Retrofit services, and DTOs
publish_to: none
resolution: workspace

environment:
  sdk: ^3.9.0

dependencies:
  core:
  dio: $V_DIO
  retrofit: $V_RETROFIT
  freezed_annotation: $V_FREEZED_ANNOTATION
  json_annotation: $V_JSON_ANNOTATION

dev_dependencies:
  build_runner: $V_BUILD_RUNNER
  retrofit_generator: $V_RETROFIT_GENERATOR
  freezed: $V_FREEZED
  json_serializable: $V_JSON_SERIALIZABLE
YAML

cat > packages/network/analysis_options.yaml << 'YAML'
include: package:lint_rules/analysis_options.yaml
YAML

cat > packages/network/lib/network.dart << 'DART'
library network;

export 'src/dio_client.dart';
export 'src/service/example_service.dart';
export 'src/dto/example_dto.dart';
DART

cat > packages/network/lib/src/dio_client.dart << DART
import 'package:dio/dio.dart';

import 'interceptor/auth_interceptor.dart';
import 'interceptor/error_interceptor.dart';

final dio = Dio(
  BaseOptions(
    baseUrl: '$BASE_URL',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ),
)..interceptors.addAll([
    AuthInterceptor(),
    ErrorInterceptor(),
    LogInterceptor(requestBody: true, responseBody: true),
  ]);
DART

cat > packages/network/lib/src/interceptor/auth_interceptor.dart << 'DART'
import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // TODO: Add auth token
    // options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}
DART

cat > packages/network/lib/src/interceptor/error_interceptor.dart << 'DART'
import 'package:dio/dio.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // TODO: Handle errors (token refresh, logging, etc.)
    handler.next(err);
  }
}
DART

cat > packages/network/lib/src/service/example_service.dart << 'DART'
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../dto/example_dto.dart';

part 'example_service.g.dart';

@RestApi()
abstract class ExampleService {
  factory ExampleService(Dio dio, {String? baseUrl}) = _ExampleService;

  @GET('/examples/{id}')
  Future<ExampleDto> getById(@Path() String id);

  @GET('/examples')
  Future<List<ExampleDto>> getAll();
}
DART

cat > packages/network/lib/src/dto/example_dto.dart << 'DART'
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:core/core.dart';

part 'example_dto.freezed.dart';
part 'example_dto.g.dart';

@freezed
class ExampleDto with _$ExampleDto {
  const ExampleDto._();

  const factory ExampleDto({
    required String id,
    required String name,
  }) = _ExampleDto;

  factory ExampleDto.fromJson(Map<String, dynamic> json) =>
      _$ExampleDtoFromJson(json);

  Example toDomain() => Example(id: id, name: name);
}
DART

log "packages/network"

# ══════════════════════════════════════
# packages/design_system
# ══════════════════════════════════════
mkdir -p packages/design_system/lib/src/{tokens,theme,widgets}

cat > packages/design_system/pubspec.yaml << YAML
name: design_system
description: Design tokens, theme, and shared UI components
publish_to: none
resolution: workspace

environment:
  sdk: ^3.9.0
  flutter: ">=3.29.0"

dependencies:
  flutter:
    sdk: flutter
YAML

cat > packages/design_system/analysis_options.yaml << 'YAML'
include: package:lint_rules/analysis_options.yaml
YAML

cat > packages/design_system/lib/design_system.dart << 'DART'
library design_system;

export 'src/tokens/colors.dart';
export 'src/tokens/typography.dart';
export 'src/tokens/spacing.dart';
export 'src/theme/app_theme.dart';
export 'src/widgets/app_button.dart';
DART

cat > packages/design_system/lib/src/tokens/colors.dart << 'DART'
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF007AFF);
  static const primaryLight = Color(0xFF4DA3FF);
  static const primaryDark = Color(0xFF0055CC);

  static const surface = Color(0xFFF8F9FA);
  static const surfaceDark = Color(0xFF1A1A2E);
  static const background = Color(0xFFFFFFFF);
  static const backgroundDark = Color(0xFF0D0D1A);

  static const error = Color(0xFFFF3B30);
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFFCC00);

  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
}
DART

cat > packages/design_system/lib/src/tokens/typography.dart << 'DART'
import 'package:flutter/material.dart';

abstract final class AppTypo {
  static const h1 = TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2);
  static const h2 = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3);
  static const h3 = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3);
  static const body = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);
  static const bodySmall = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4);
  static const label = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4);
}
DART

cat > packages/design_system/lib/src/tokens/spacing.dart << 'DART'
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}
DART

cat > packages/design_system/lib/src/theme/app_theme.dart << 'DART'
import 'package:flutter/material.dart';

import '../tokens/colors.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.primary,
        scaffoldBackgroundColor: AppColors.backgroundDark,
      );
}
DART

cat > packages/design_system/lib/src/widgets/app_button.dart << 'DART'
import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildChild(),
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildChild(),
        ),
      AppButtonVariant.text => TextButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildChild(),
        ),
    };
  }

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Text(label);
  }
}
DART

log "packages/design_system"

# ══════════════════════════════════════
# Overwrite apps with monorepo structure
# ══════════════════════════════════════
for APP_NAME in "${APP_NAMES[@]}"; do

info "Setting up monorepo structure for ${BOLD}$APP_NAME${NC}..."

mkdir -p "apps/$APP_NAME/lib/ui/example" \
         "apps/$APP_NAME/lib/data" \
         "apps/$APP_NAME/lib/provider" \
         "apps/$APP_NAME/lib/router"

cat > "apps/$APP_NAME/pubspec.yaml" << YAML
name: $APP_NAME
description: Flutter application
publish_to: none
resolution: workspace
version: 1.0.0+1

environment:
  sdk: ^3.9.0
  flutter: ">=3.29.0"

dependencies:
  flutter:
    sdk: flutter
  design_system:
  core:
  network:
  flutter_riverpod: $V_FLUTTER_RIVERPOD
  riverpod_annotation: $V_RIVERPOD_ANNOTATION
  go_router: $V_GO_ROUTER

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: $V_BUILD_RUNNER
  riverpod_generator: $V_RIVERPOD_GENERATOR
YAML

cat > "apps/$APP_NAME/analysis_options.yaml" << 'YAML'
include: package:lint_rules/analysis_options.yaml
YAML

cat > "apps/$APP_NAME/lib/main.dart" << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';

import 'router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
DART

cat > "apps/$APP_NAME/lib/router/app_router.dart" << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/example/example_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ExampleScreen(),
      ),
    ],
  );
});
DART

cat > "apps/$APP_NAME/lib/provider/providers.dart" << 'DART'
import 'package:core/core.dart';
import 'package:network/network.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/example_repository_impl.dart';

part 'providers.g.dart';

@riverpod
ExampleService exampleService(ref) => ExampleService(dio);

@riverpod
ExampleRepository exampleRepository(ref) =>
    ExampleRepositoryImpl(ref.watch(exampleServiceProvider));
DART

cat > "apps/$APP_NAME/lib/data/example_repository_impl.dart" << 'DART'
import 'package:core/core.dart';
import 'package:network/network.dart';

class ExampleRepositoryImpl implements ExampleRepository {
  ExampleRepositoryImpl(this._service);

  final ExampleService _service;

  @override
  Future<Example> getById(String id) async {
    final dto = await _service.getById(id);
    return dto.toDomain();
  }

  @override
  Future<List<Example>> getAll() async {
    final dtos = await _service.getAll();
    return dtos.map((e) => e.toDomain()).toList();
  }
}
DART

cat > "apps/$APP_NAME/lib/ui/example/example_notifier.dart" << 'DART'
import 'package:core/core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../provider/providers.dart';

part 'example_notifier.g.dart';

@riverpod
class ExampleNotifier extends _$ExampleNotifier {
  @override
  Future<List<Example>> build() async {
    final repo = ref.watch(exampleRepositoryProvider);
    return repo.getAll();
  }
}
DART

cat > "apps/$APP_NAME/lib/ui/example/example_screen.dart" << 'DART'
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExampleScreen extends ConsumerWidget {
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Example')),
      body: Center(
        child: AppButton(
          label: 'Hello from Design System',
          onPressed: () {
            // TODO: implement
          },
        ),
      ),
    );
  }
}
DART

log "apps/$APP_NAME (monorepo setup)"

done

# ══════════════════════════════════════
# servers (FastAPI)
# ══════════════════════════════════════
if [[ ${#SERVER_NAMES[@]} -gt 0 ]]; then

  mkdir -p servers

  # ── shared (only when 2+ servers) ──
  if [[ ${#SERVER_NAMES[@]} -gt 1 ]]; then
    mkdir -p servers/shared/models servers/shared/utils

    cat > servers/shared/__init__.py << 'PY'
PY

    cat > servers/shared/models/__init__.py << 'PY'
PY

    cat > servers/shared/models/example.py << 'PY'
from pydantic import BaseModel


class ExampleBase(BaseModel):
    name: str


class ExampleCreate(ExampleBase):
    pass


class ExampleResponse(ExampleBase):
    id: str

    model_config = {"from_attributes": True}
PY

    cat > servers/shared/utils/__init__.py << 'PY'
PY

    cat > servers/shared/utils/config.py << 'PY'
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "sqlite+aiosqlite:///./dev.db"
    debug: bool = True

    model_config = {"env_file": ".env"}


settings = Settings()
PY

    log "servers/shared"
  fi

  # ── Each server ──
  for SERVER_NAME in "${SERVER_NAMES[@]}"; do

    info "Creating FastAPI server ${BOLD}$SERVER_NAME${NC}..."

    mkdir -p "servers/$SERVER_NAME/app/api/v1/endpoints" \
             "servers/$SERVER_NAME/app/core" \
             "servers/$SERVER_NAME/app/models" \
             "servers/$SERVER_NAME/app/schemas" \
             "servers/$SERVER_NAME/app/repositories" \
             "servers/$SERVER_NAME/app/services" \
             "servers/$SERVER_NAME/tests"

    # requirements.txt
    cat > "servers/$SERVER_NAME/requirements.txt" << REQS
fastapi${V_FASTAPI}
uvicorn[standard]${V_UVICORN}
pydantic${V_PYDANTIC}
pydantic-settings
sqlalchemy${V_SQLALCHEMY}
alembic${V_ALEMBIC}
httpx${V_HTTPX}
pytest${V_PYTEST}
ruff${V_RUFF}
REQS

    # Dockerfile
    cat > "servers/$SERVER_NAME/Dockerfile" << 'DOCKER'
FROM python:3.13-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
DOCKER

    # .env.example
    cat > "servers/$SERVER_NAME/.env.example" << 'ENV'
DATABASE_URL=sqlite+aiosqlite:///./dev.db
DEBUG=true
ENV

    # app/__init__.py
    cat > "servers/$SERVER_NAME/app/__init__.py" << 'PY'
PY

    # app/main.py
    cat > "servers/$SERVER_NAME/app/main.py" << PY
from fastapi import FastAPI

from app.api.v1.router import api_router

app = FastAPI(title="$SERVER_NAME")

app.include_router(api_router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok"}
PY

    # app/core/__init__.py
    cat > "servers/$SERVER_NAME/app/core/__init__.py" << 'PY'
PY

    # app/core/config.py
    cat > "servers/$SERVER_NAME/app/core/config.py" << 'PY'
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "sqlite+aiosqlite:///./dev.db"
    debug: bool = True

    model_config = {"env_file": ".env"}


settings = Settings()
PY

    # app/core/database.py
    cat > "servers/$SERVER_NAME/app/core/database.py" << 'PY'
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

engine = create_async_engine(settings.database_url, echo=settings.debug)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db():
    async with async_session() as session:
        yield session
PY

    # app/models/__init__.py
    cat > "servers/$SERVER_NAME/app/models/__init__.py" << 'PY'
PY

    # app/models/example.py
    cat > "servers/$SERVER_NAME/app/models/example.py" << 'PY'
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ExampleModel(Base):
    __tablename__ = "examples"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    name: Mapped[str] = mapped_column(String(255))
PY

    # app/schemas/__init__.py
    cat > "servers/$SERVER_NAME/app/schemas/__init__.py" << 'PY'
PY

    # app/schemas/example.py
    cat > "servers/$SERVER_NAME/app/schemas/example.py" << 'PY'
from pydantic import BaseModel


class ExampleBase(BaseModel):
    name: str


class ExampleCreate(ExampleBase):
    pass


class ExampleResponse(ExampleBase):
    id: str

    model_config = {"from_attributes": True}
PY

    # app/repositories/__init__.py
    cat > "servers/$SERVER_NAME/app/repositories/__init__.py" << 'PY'
PY

    # app/repositories/example_repository.py
    cat > "servers/$SERVER_NAME/app/repositories/example_repository.py" << 'PY'
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.example import ExampleModel


class ExampleRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, id: str) -> ExampleModel | None:
        return await self.db.get(ExampleModel, id)

    async def get_all(self) -> list[ExampleModel]:
        result = await self.db.execute(select(ExampleModel))
        return list(result.scalars().all())

    async def create(self, model: ExampleModel) -> ExampleModel:
        self.db.add(model)
        await self.db.commit()
        await self.db.refresh(model)
        return model
PY

    # app/services/__init__.py
    cat > "servers/$SERVER_NAME/app/services/__init__.py" << 'PY'
PY

    # app/services/example_service.py
    cat > "servers/$SERVER_NAME/app/services/example_service.py" << 'PY'
import uuid

from app.models.example import ExampleModel
from app.repositories.example_repository import ExampleRepository
from app.schemas.example import ExampleCreate


class ExampleService:
    def __init__(self, repository: ExampleRepository):
        self.repository = repository

    async def get_by_id(self, id: str) -> ExampleModel | None:
        return await self.repository.get_by_id(id)

    async def get_all(self) -> list[ExampleModel]:
        return await self.repository.get_all()

    async def create(self, data: ExampleCreate) -> ExampleModel:
        model = ExampleModel(id=str(uuid.uuid4()), name=data.name)
        return await self.repository.create(model)
PY

    # app/api/__init__.py
    cat > "servers/$SERVER_NAME/app/api/__init__.py" << 'PY'
PY

    # app/api/v1/__init__.py
    cat > "servers/$SERVER_NAME/app/api/v1/__init__.py" << 'PY'
PY

    # app/api/v1/router.py
    cat > "servers/$SERVER_NAME/app/api/v1/router.py" << 'PY'
from fastapi import APIRouter

from app.api.v1.endpoints import example

api_router = APIRouter()
api_router.include_router(example.router, prefix="/examples", tags=["examples"])
PY

    # app/api/v1/endpoints/__init__.py
    cat > "servers/$SERVER_NAME/app/api/v1/endpoints/__init__.py" << 'PY'
PY

    # app/api/v1/endpoints/example.py
    cat > "servers/$SERVER_NAME/app/api/v1/endpoints/example.py" << 'PY'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.repositories.example_repository import ExampleRepository
from app.schemas.example import ExampleCreate, ExampleResponse
from app.services.example_service import ExampleService

router = APIRouter()


def get_service(db: AsyncSession = Depends(get_db)) -> ExampleService:
    return ExampleService(ExampleRepository(db))


@router.get("/", response_model=list[ExampleResponse])
async def get_all(service: ExampleService = Depends(get_service)):
    return await service.get_all()


@router.get("/{id}", response_model=ExampleResponse)
async def get_by_id(id: str, service: ExampleService = Depends(get_service)):
    result = await service.get_by_id(id)
    if result is None:
        raise HTTPException(status_code=404, detail="Not found")
    return result


@router.post("/", response_model=ExampleResponse, status_code=201)
async def create(data: ExampleCreate, service: ExampleService = Depends(get_service)):
    return await service.create(data)
PY

    # tests/__init__.py
    cat > "servers/$SERVER_NAME/tests/__init__.py" << 'PY'
PY

    log "servers/$SERVER_NAME"

  done
fi

# ══════════════════════════════════════
# Git init
# ══════════════════════════════════════
git init -q
git add .
git commit -q -m "chore: scaffold monorepo"
log "git initialized with initial commit"

# ══════════════════════════════════════
# Done
# ══════════════════════════════════════
APPS_LIST=$(printf ", %s" "${APP_NAMES[@]}")
APPS_LIST=${APPS_LIST:2}

echo -e "\n${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}✅ Monorepo created: ${CYAN}$PROJECT_NAME${NC}"
echo -e "   Apps: ${CYAN}$APPS_LIST${NC}"

if [[ ${#SERVER_NAMES[@]} -gt 0 ]]; then
  SERVERS_LIST=$(printf ", %s" "${SERVER_NAMES[@]}")
  SERVERS_LIST=${SERVERS_LIST:2}
  echo -e "   Servers: ${CYAN}$SERVERS_LIST${NC}"
fi

echo -e "\nNext steps:\n"
echo -e "  ${CYAN}cd $PROJECT_NAME${NC}"
echo -e "  ${CYAN}dart pub get${NC}                 ${DIM}# Install root deps${NC}"
echo -e "  ${CYAN}dart pub global activate melos${NC} ${DIM}# Install melos CLI${NC}"
echo -e "  ${CYAN}melos bootstrap${NC}              ${DIM}# Link all packages${NC}"
echo -e "  ${CYAN}melos run gen${NC}                ${DIM}# Generate freezed + retrofit + riverpod${NC}"

if [[ ${#SERVER_NAMES[@]} -gt 0 ]]; then
  echo -e ""
  for SERVER_NAME in "${SERVER_NAMES[@]}"; do
    echo -e "  ${CYAN}cd servers/$SERVER_NAME && pip install -r requirements.txt${NC}"
    echo -e "  ${CYAN}uvicorn app.main:app --reload${NC}  ${DIM}# Run $SERVER_NAME${NC}"
  done
fi

echo -e ""
