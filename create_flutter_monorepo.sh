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

UPDATE_MODE=false
if [[ -d "$PROJECT_NAME" ]]; then
  UPDATE_MODE=true
  warn "Directory '$PROJECT_NAME' already exists — running in ${BOLD}update mode${NC} (only missing components will be added)"
fi

APP_NAMES_INPUT=$(ask "App names, comma-separated" "app")
ORG=$(ask "Organization (reverse domain)" "com.example")
PLATFORMS_INPUT=$(ask "Platforms, comma-separated (ios,android,web,macos,linux,windows)" "ios,android,web")
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

# ── Helper: write file only if it doesn't exist (update mode) ──
write_if_missing() {
  local filepath="$1"
  if [[ "$UPDATE_MODE" == true && -f "$filepath" ]]; then
    info "Skipping (exists): ${DIM}$filepath${NC}"
    return 1
  fi
  return 0
}

echo ""

# ── Check prerequisites ──
command -v dart    >/dev/null 2>&1 || err "dart SDK not found. Install Flutter/Dart first."
command -v flutter >/dev/null 2>&1 || err "flutter SDK not found."
command -v curl    >/dev/null 2>&1 || err "curl not found."
command -v git     >/dev/null 2>&1 || err "git not found."

DART_VERSION=$(dart --version 2>&1 | sed -n 's/.*Dart SDK version: \([0-9][0-9.]*\).*/\1/p')
DART_MAJOR_MINOR=$(echo "$DART_VERSION" | sed 's/\([0-9]*\.[0-9]*\).*/\1/')
info "Dart $DART_VERSION detected (SDK constraint: ^$DART_MAJOR_MINOR.0)"

FLUTTER_VERSION=$(flutter --version 2>&1 | sed -n 's/.*Flutter \([0-9][0-9.]*\).*/\1/p' | head -1)
FLUTTER_MAJOR_MINOR=$(echo "$FLUTTER_VERSION" | sed 's/\([0-9]*\.[0-9]*\).*/\1/')
info "Flutter $FLUTTER_VERSION detected (constraint: >=$FLUTTER_MAJOR_MINOR.0)"

# ── Validate inputs ──
IFS=',' read -ra PLATFORMS_ARR <<< "$PLATFORMS_INPUT"
VALID_PLATFORMS="ios android web macos linux windows"
for p in "${PLATFORMS_ARR[@]}"; do
  p=$(echo "$p" | tr -d ' ')
  if ! echo "$VALID_PLATFORMS" | grep -qw "$p"; then
    err "Invalid platform '$p'. Valid: $VALID_PLATFORMS"
  fi
done

if [[ ! "$ORG" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$ ]]; then
  warn "Organization '$ORG' may not be a valid reverse domain (e.g. com.example)"
fi

if [[ ! "$BASE_URL" =~ ^https?:// ]]; then
  warn "BASE_URL '$BASE_URL' doesn't start with http:// or https://"
fi

# ── Fetch latest version from pub.dev ──
get_version() {
  local pkg="$1"
  local version

  local json
  json=$(curl -sf "https://pub.dev/api/packages/$pkg") || true

  if [[ -n "$json" ]]; then
    # Try python3 first, then jq, then sed fallback
    if command -v python3 >/dev/null 2>&1; then
      version=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['latest']['version'])" 2>/dev/null) || true
    elif command -v jq >/dev/null 2>&1; then
      version=$(echo "$json" | jq -r '.latest.version' 2>/dev/null) || true
    else
      version=$(echo "$json" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1) || true
    fi
  fi

  if [[ -z "$version" ]]; then
    warn "Failed to fetch version for '$pkg', using 'any'"
    echo "any"
  else
    echo "^$version"
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

V_GET_IT=$(get_version get_it)
V_INJECTABLE=$(get_version injectable)
V_INJECTABLE_GENERATOR=$(get_version injectable_generator)
log "get_it: ${CYAN}$V_GET_IT${NC}"
log "injectable: ${CYAN}$V_INJECTABLE${NC}"
log "injectable_generator: ${CYAN}$V_INJECTABLE_GENERATOR${NC}"

V_FLUTTER_LINTS=$(get_version flutter_lints)
log "flutter_lints: ${CYAN}$V_FLUTTER_LINTS${NC}"

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
  if [[ -d "apps/$APP_NAME" && "$UPDATE_MODE" == true ]]; then
    info "Skipping flutter create (exists): ${DIM}apps/$APP_NAME${NC}"
  else
    info "Running flutter create for ${BOLD}$APP_NAME${NC}..."
    if ! flutter create --org "$ORG" --project-name "$APP_NAME" --platforms "$PLATFORMS_INPUT" "apps/$APP_NAME" --empty >/dev/null; then
      err "flutter create failed for '$APP_NAME'. Check the output above."
    fi
    log "flutter create apps/$APP_NAME"
  fi
done

# ── Build workspace entries ──
WORKSPACE_APPS=""
for app_name in "${APP_NAMES[@]}"; do
  WORKSPACE_APPS+="  - apps/$app_name
"
done

# ── Root pubspec.yaml ──
if write_if_missing pubspec.yaml; then
cat > pubspec.yaml << YAML
name: $PROJECT_NAME
publish_to: none

environment:
  sdk: ^$DART_MAJOR_MINOR.0

workspace:
${WORKSPACE_APPS}  - packages/domain
  - packages/data
  - packages/design_system
  - packages/lint_rules

dev_dependencies:
  melos: $V_MELOS

melos:
  scripts:
    gen:
      exec: dart run build_runner build -d
      description: Run build_runner (freezed + retrofit + riverpod)
      packageFilters:
        dependsOn: build_runner
    gen:watch:
      exec: dart run build_runner watch -d
      description: Watch mode for build_runner
      packageFilters:
        dependsOn: build_runner
    test:
      exec: flutter test
      description: Run tests in all packages
      packageFilters:
        dirExists: test
    analyze:
      exec: dart analyze .
      description: Analyze all packages
    format:
      exec: dart format .
      description: Format all packages
    l10n:
      exec: flutter gen-l10n
      description: Generate localization files
      packageFilters:
        fileExists: l10n.yaml
    clean:
      exec: flutter clean
      description: Clean all packages
YAML
log "Root pubspec.yaml"
fi

# ── .gitignore ──
if write_if_missing .gitignore; then
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
**/generated/

# OS
.DS_Store
Thumbs.db
GITIGNORE
log ".gitignore"
fi

# ── README ──
if write_if_missing README.md; then
cat > README.md << MD
# $PROJECT_NAME

Flutter Melos v7 monorepo with Riverpod + Retrofit + Dio + Freezed.

## Prerequisites

- Flutter SDK >= $FLUTTER_MAJOR_MINOR.0
- Dart SDK >= $DART_MAJOR_MINOR.0
- [Melos](https://melos.invertase.dev/) (\`dart pub global activate melos\`)

## Setup

\`\`\`bash
cd $PROJECT_NAME
dart pub get
melos bootstrap
melos run gen
\`\`\`

## Project Structure

\`\`\`
$PROJECT_NAME/
├── apps/                  # Flutter applications
${WORKSPACE_APPS}├── packages/
│   ├── domain/            # Entities, abstract repos, failures (pure Dart)
│   ├── data/              # Repo impl, datasources, DTOs, Dio (Injectable)
│   ├── design_system/     # Theme, tokens, shared widgets
│   └── lint_rules/        # Shared analysis options
└── pubspec.yaml           # Workspace root
\`\`\`

## Scripts

- \`melos run gen\` — Run build_runner (freezed + retrofit + riverpod)
- \`melos run gen:watch\` — Watch mode for build_runner
- \`melos run test\` — Run tests in all packages
- \`melos run analyze\` — Analyze all packages
- \`melos run format\` — Format all packages
- \`melos run clean\` — Clean all packages
MD
log "README.md"
fi

# ══════════════════════════════════════
# packages/lint_rules
# ══════════════════════════════════════
if [[ ! -d "packages/lint_rules" ]]; then
mkdir -p packages/lint_rules/lib

cat > packages/lint_rules/pubspec.yaml << YAML
name: lint_rules
description: Shared lint rules for $PROJECT_NAME
publish_to: none
resolution: workspace

environment:
  sdk: ^$DART_MAJOR_MINOR.0

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
else
  info "Skipping (exists): ${DIM}packages/lint_rules${NC}"
fi

# ══════════════════════════════════════
# packages/domain  (DDD Domain Layer)
#   Pure Dart — entities, abstract repos, failures
# ══════════════════════════════════════
if [[ ! -d "packages/domain" ]]; then
mkdir -p packages/domain/lib/src/{entity,repository,failure}

cat > packages/domain/pubspec.yaml << YAML
name: domain
description: "DDD Domain Layer: entities, abstract repositories, and failures"
publish_to: none
resolution: workspace

environment:
  sdk: ^$DART_MAJOR_MINOR.0

dependencies:
  freezed_annotation: $V_FREEZED_ANNOTATION

dev_dependencies:
  build_runner: $V_BUILD_RUNNER
  freezed: $V_FREEZED
YAML

cat > packages/domain/analysis_options.yaml << 'YAML'
include: package:lint_rules/analysis_options.yaml
YAML

cat > packages/domain/build.yaml << 'YAML'
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
YAML
log "packages/domain/build.yaml"

cat > packages/domain/lib/domain.dart << 'DART'
export 'src/entity/example.dart';
export 'src/repository/example_repository.dart';
export 'src/failure/app_failure.dart';
DART

cat > packages/domain/lib/src/entity/example.dart << 'DART'
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/example.freezed.dart';

@freezed
abstract class Example with _$Example {
  const factory Example({
    required String id,
    required String name,
  }) = _Example;
}
DART

cat > packages/domain/lib/src/repository/example_repository.dart << 'DART'
import '../entity/example.dart';

abstract class ExampleRepository {
  Future<Example> getById(String id);
  Future<List<Example>> getAll();
}
DART

cat > packages/domain/lib/src/failure/app_failure.dart << 'DART'
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/app_failure.freezed.dart';

@freezed
sealed class AppFailure with _$AppFailure {
  const factory AppFailure.server({String? message}) = ServerFailure;
  const factory AppFailure.network({String? message}) = NetworkFailure;
  const factory AppFailure.notFound({String? message}) = NotFoundFailure;
  const factory AppFailure.unauthorized({String? message}) = UnauthorizedFailure;
  const factory AppFailure.unknown({String? message}) = UnknownFailure;
}
DART

log "packages/domain"
else
  info "Skipping (exists): ${DIM}packages/domain${NC}"
fi

# ══════════════════════════════════════
# packages/data  (DDD Data Layer)
#   Repository impl, remote datasources, DTOs, Dio
# ══════════════════════════════════════
if [[ ! -d "packages/data" ]]; then
mkdir -p packages/data/lib/src/{di,repository,datasource/remote/dto,network/interceptor}

cat > packages/data/pubspec.yaml << YAML
name: data
description: "DDD Data Layer: repository implementations, remote datasources, DTOs"
publish_to: none
resolution: workspace

environment:
  sdk: ^$DART_MAJOR_MINOR.0

dependencies:
  domain:
  dio: $V_DIO
  retrofit: $V_RETROFIT
  freezed_annotation: $V_FREEZED_ANNOTATION
  json_annotation: $V_JSON_ANNOTATION
  get_it: $V_GET_IT
  injectable: $V_INJECTABLE

dev_dependencies:
  build_runner: $V_BUILD_RUNNER
  retrofit_generator: $V_RETROFIT_GENERATOR
  freezed: $V_FREEZED
  json_serializable: $V_JSON_SERIALIZABLE
  injectable_generator: $V_INJECTABLE_GENERATOR
YAML

cat > packages/data/analysis_options.yaml << 'YAML'
include: package:lint_rules/analysis_options.yaml
YAML

cat > packages/data/build.yaml << 'YAML'
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
      injectable_generator:injectable_builder:
        options:
          auto_register: true
          file_name_pattern: "_repository_impl$|_usecase$|_datasource$"
YAML
log "packages/data/build.yaml"

cat > packages/data/lib/data.dart << 'DART'
// DI
export 'src/di/data_injection.dart';

// Network
export 'src/network/dio_client.dart';

// DataSources
export 'src/datasource/remote/example_remote_datasource.dart';

// Repositories
export 'src/repository/example_repository_impl.dart';
DART

cat > packages/data/lib/src/di/data_injection.dart << 'DART'
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'generated/data_injection.config.dart';

@InjectableInit.microPackage()
void initDataPackage(GetIt getIt) => getIt.init();
DART

cat > packages/data/lib/src/di/data_module.dart << DART
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../network/dio_client.dart';

@module
abstract class DataModule {
  @singleton
  Dio get dio => createDio();
}
DART

cat > packages/data/lib/src/network/dio_client.dart << DART
import 'package:dio/dio.dart';

import 'interceptor/auth_interceptor.dart';
import 'interceptor/error_interceptor.dart';

Dio createDio({String baseUrl = '$BASE_URL'}) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
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
}
DART

cat > packages/data/lib/src/network/interceptor/auth_interceptor.dart << 'DART'
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

cat > packages/data/lib/src/network/interceptor/error_interceptor.dart << 'DART'
import 'package:dio/dio.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // TODO: Handle errors (token refresh, logging, etc.)
    handler.next(err);
  }
}
DART

cat > packages/data/lib/src/datasource/remote/example_remote_datasource.dart << 'DART'
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dto/example_dto.dart';

part 'generated/example_remote_datasource.g.dart';

@RestApi()
abstract class ExampleRemoteDataSource {
  factory ExampleRemoteDataSource(Dio dio, {String? baseUrl}) =
      _ExampleRemoteDataSource;

  @GET('/examples/{id}')
  Future<ExampleDto> getById(@Path() String id);

  @GET('/examples')
  Future<List<ExampleDto>> getAll();
}
DART

cat > packages/data/lib/src/datasource/remote/dto/example_dto.dart << 'DART'
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:domain/domain.dart';

part 'generated/example_dto.freezed.dart';
part 'generated/example_dto.g.dart';

@freezed
abstract class ExampleDto with _$ExampleDto {
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

cat > packages/data/lib/src/repository/example_repository_impl.dart << 'DART'
import 'package:domain/domain.dart';

import '../datasource/remote/example_remote_datasource.dart';

/// Auto-registered by injectable (file name pattern: _repository_impl$)
class ExampleRepositoryImpl implements ExampleRepository {
  ExampleRepositoryImpl(this._remoteDataSource);

  final ExampleRemoteDataSource _remoteDataSource;

  @override
  Future<Example> getById(String id) async {
    final dto = await _remoteDataSource.getById(id);
    return dto.toDomain();
  }

  @override
  Future<List<Example>> getAll() async {
    final dtos = await _remoteDataSource.getAll();
    return dtos.map((e) => e.toDomain()).toList();
  }
}
DART

log "packages/data"
else
  info "Skipping (exists): ${DIM}packages/data${NC}"
fi

# ══════════════════════════════════════
# packages/design_system
# ══════════════════════════════════════
if [[ ! -d "packages/design_system" ]]; then
mkdir -p packages/design_system/lib/src/{tokens,theme,widgets}

cat > packages/design_system/pubspec.yaml << YAML
name: design_system
description: Design tokens, theme, and shared UI components
publish_to: none
resolution: workspace

environment:
  sdk: ^$DART_MAJOR_MINOR.0
  flutter: ">=$FLUTTER_MAJOR_MINOR.0"

dependencies:
  flutter:
    sdk: flutter
YAML

cat > packages/design_system/analysis_options.yaml << 'YAML'
include: package:lint_rules/analysis_options.yaml
YAML

cat > packages/design_system/lib/design_system.dart << 'DART'
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
else
  info "Skipping (exists): ${DIM}packages/design_system${NC}"
fi

# ══════════════════════════════════════
# Overwrite apps with monorepo structure
# ══════════════════════════════════════
for APP_NAME in "${APP_NAMES[@]}"; do

# Skip monorepo overwrite if app already has DDD structure
if [[ "$UPDATE_MODE" == true && -f "apps/$APP_NAME/lib/presentation/router/app_router.dart" ]]; then
  info "Skipping DDD setup (exists): ${DIM}apps/$APP_NAME${NC}"
  continue
fi

info "Setting up DDD structure for ${BOLD}$APP_NAME${NC}..."

mkdir -p "apps/$APP_NAME/lib/di" \
         "apps/$APP_NAME/lib/presentation/router" \
         "apps/$APP_NAME/lib/presentation/example" \
         "apps/$APP_NAME/lib/l10n"

cat > "apps/$APP_NAME/pubspec.yaml" << YAML
name: $APP_NAME
description: Flutter application
publish_to: none
resolution: workspace
version: 1.0.0+1

environment:
  sdk: ^$DART_MAJOR_MINOR.0
  flutter: ">=$FLUTTER_MAJOR_MINOR.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any
  domain:
  data:
  design_system:
  get_it: $V_GET_IT
  injectable: $V_INJECTABLE
  flutter_riverpod: $V_FLUTTER_RIVERPOD
  riverpod_annotation: $V_RIVERPOD_ANNOTATION
  go_router: $V_GO_ROUTER

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: $V_BUILD_RUNNER
  injectable_generator: $V_INJECTABLE_GENERATOR
  riverpod_generator: $V_RIVERPOD_GENERATOR
YAML

cat > "apps/$APP_NAME/analysis_options.yaml" << 'YAML'
include: package:lint_rules/analysis_options.yaml
YAML

cat > "apps/$APP_NAME/build.yaml" << 'YAML'
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
YAML
log "apps/$APP_NAME/build.yaml"

cat > "apps/$APP_NAME/l10n.yaml" << YAML
arb-dir: lib/l10n
template-arb-file: app_ko.arb
output-localization-file: app_localizations.dart
output-dir: lib/l10n/generated
synthetic-package: false
nullable-getter: false
YAML
log "apps/$APP_NAME/l10n.yaml"

cat > "apps/$APP_NAME/lib/l10n/app_ko.arb" << 'ARB'
{
  "@@locale": "ko",
  "appTitle": "앱",
  "@appTitle": {
    "description": "앱 타이틀"
  },
  "helloMessage": "디자인 시스템에서 인사드립니다",
  "@helloMessage": {
    "description": "예제 화면 버튼 텍스트"
  }
}
ARB

cat > "apps/$APP_NAME/lib/l10n/app_en.arb" << 'ARB'
{
  "@@locale": "en",
  "appTitle": "App",
  "helloMessage": "Hello from Design System"
}
ARB
log "apps/$APP_NAME l10n (ko, en)"

cat > "apps/$APP_NAME/lib/main.dart" << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';

import 'di/injection.dart';
import 'l10n/generated/app_localizations.dart';
import 'presentation/router/app_router.dart';

void main() {
  configureDependencies();
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
      locale: const Locale('ko'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    );
  }
}
DART

cat > "apps/$APP_NAME/lib/presentation/router/app_router.dart" << 'DART'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../example/example_screen.dart';

part 'generated/app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ExampleScreen(),
      ),
    ],
  );
}
DART

cat > "apps/$APP_NAME/lib/di/injection.dart" << 'DART'
import 'package:data/data.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'generated/injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  externalPackageModulesBefore: [ExternalModule(initDataPackage)],
)
void configureDependencies() => getIt.init();
DART

cat > "apps/$APP_NAME/lib/di/providers.dart" << 'DART'
import 'package:domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'injection.dart';

part 'generated/providers.g.dart';

/// GetIt → Riverpod bridge (UI layer에서 사용)
@riverpod
ExampleRepository exampleRepository(Ref ref) => getIt<ExampleRepository>();
DART

cat > "apps/$APP_NAME/lib/presentation/example/example_notifier.dart" << 'DART'
import 'package:domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../di/providers.dart';

part 'generated/example_notifier.g.dart';

@riverpod
class ExampleNotifier extends _$ExampleNotifier {
  @override
  Future<List<Example>> build() async {
    final repo = ref.watch(exampleRepositoryProvider);
    return repo.getAll();
  }
}
DART

cat > "apps/$APP_NAME/lib/presentation/example/example_screen.dart" << 'DART'
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';

class ExampleScreen extends ConsumerWidget {
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: AppButton(
          label: l10n.helloMessage,
          onPressed: () {
            // TODO: implement
          },
        ),
      ),
    );
  }
}
DART

log "apps/$APP_NAME (DDD setup)"

done

# ══════════════════════════════════════
# Git init
# ══════════════════════════════════════
if [[ -d ".git" ]]; then
  info "Git repo already exists — skipping git init"
else
  git init -q
  git add .
  git commit -q -m "chore: scaffold monorepo"
  log "git initialized with initial commit"
fi

# ══════════════════════════════════════
# Done
# ══════════════════════════════════════
APPS_LIST=$(printf ", %s" "${APP_NAMES[@]}")
APPS_LIST=${APPS_LIST:2}

echo -e "\n${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ "$UPDATE_MODE" == true ]]; then
  echo -e "${BOLD}${GREEN}✅ Monorepo updated: ${CYAN}$PROJECT_NAME${NC}"
else
  echo -e "${BOLD}${GREEN}✅ Monorepo created: ${CYAN}$PROJECT_NAME${NC}"
fi
echo -e "   Apps: ${CYAN}$APPS_LIST${NC}"

echo -e "\nNext steps:\n"
echo -e "  ${CYAN}cd $PROJECT_NAME${NC}"
echo -e "  ${CYAN}dart pub get${NC}                 ${DIM}# Install root deps${NC}"
echo -e "  ${CYAN}dart pub global activate melos${NC} ${DIM}# Install melos CLI${NC}"
echo -e "  ${CYAN}melos bootstrap${NC}              ${DIM}# Link all packages${NC}"
echo -e "  ${CYAN}melos run gen${NC}                ${DIM}# Generate freezed + retrofit + riverpod${NC}"

echo -e ""
