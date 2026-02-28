# create-flutter-monorepo

Flutter Melos v7 모노레포 스캐폴더. **DDD 아키텍처** + GetIt/Injectable + Riverpod 3.0 + Retrofit + Freezed + slang.

## 사전 준비

- Flutter SDK (stable)
- Dart SDK >= 3.x
- `git`, `curl`

## 시작하기

**방법 1**: 다운로드 후 실행 (권장)

```bash
curl -sLO https://raw.githubusercontent.com/hongmono/create-flutter-monorepo/main/create_flutter_monorepo.sh
bash create_flutter_monorepo.sh
```

**방법 2**: 파이프로 바로 실행

```bash
curl -sL https://raw.githubusercontent.com/hongmono/create-flutter-monorepo/main/create_flutter_monorepo.sh | bash
```

스크립트가 물어보는 것들:

- **프로젝트 이름** — 소문자 + 언더스코어 (기본: `my_app`)
- **앱 이름** — 쉼표 구분 (기본: `app`, 예: `client, admin`)
- **조직명** — 역도메인 (기본: `com.example`)
- **플랫폼** — ios, android, web, macos, linux, windows (기본: `ios,android,web`)
- **API 기본 URL** — (기본: `https://api.example.com`)

스캐폴딩 후:

```bash
cd my_project
dart pub get
dart pub global activate melos
melos bootstrap
melos run gen          # freezed + retrofit + injectable + riverpod + slang 코드 생성
```

---

## 아키텍처

DDD (Domain-Driven Design) 3계층. 의존성 방향:

```
presentation → domain ← data
```

- **domain** — 순수 Dart. 외부 의존성 없음
- **data** — domain에만 의존
- **presentation** (앱) — domain에만 의존. data는 DI로 접근

### 프로젝트 구조

```
my_project/
├── apps/
│   ├── client/
│   │   ├── build.yaml                         # 코드젠 설정 (generated/ 하위 디렉토리)
│   │   └── lib/
│   │       ├── main.dart                       # 진입점 (GetIt 초기화 → ProviderScope)
│   │       ├── di/
│   │       │   ├── injection.dart              # GetIt + Injectable 설정
│   │       │   ├── generated/injection.config.dart
│   │       │   ├── providers.dart              # GetIt → Riverpod 브릿지
│   │       │   └── generated/providers.g.dart
│   │       ├── i18n/
│   │       │   ├── strings_ko.i18n.yaml         # 한국어 (base)
│   │       │   ├── strings_en.i18n.yaml         # 영어
│   │       │   └── generated/strings.g.dart
│   │       └── presentation/
│   │           ├── router/
│   │           │   ├── app_router.dart          # GoRouter (@riverpod)
│   │           │   └── generated/app_router.g.dart
│   │           └── example/                     # 기능 디렉토리
│   │               ├── example_screen.dart       # UI (ConsumerWidget)
│   │               ├── example_notifier.dart     # 상태 (@riverpod AsyncNotifier)
│   │               └── generated/example_notifier.g.dart
│   └── admin/                                   # 추가 앱 (같은 구조)
│
├── packages/
│   ├── domain/                      # DDD Domain 계층 (순수 Dart)
│   │   ├── build.yaml
│   │   └── lib/
│   │       ├── domain.dart           # Barrel export
│   │       └── src/
│   │           ├── entity/           # Freezed 값 객체
│   │           │   ├── example.dart
│   │           │   └── generated/example.freezed.dart
│   │           ├── repository/       # 추상 Repository 계약
│   │           │   └── example_repository.dart
│   │           └── failure/          # 도메인 에러 타입
│   │               ├── app_failure.dart
│   │               └── generated/app_failure.freezed.dart
│   │
│   ├── data/                        # DDD Data 계층 (Injectable)
│   │   ├── build.yaml               # auto_register: true
│   │   └── lib/
│   │       ├── data.dart             # Barrel export
│   │       └── src/
│   │           ├── di/
│   │           │   ├── data_injection.dart       # @InjectableInit.microPackage()
│   │           │   ├── generated/data_injection.config.dart
│   │           │   └── data_module.dart          # @module (Dio @singleton)
│   │           ├── repository/
│   │           │   └── example_repository_impl.dart  # 자동 등록!
│   │           ├── datasource/
│   │           │   └── remote/
│   │           │       ├── example_remote_datasource.dart  # Retrofit
│   │           │       ├── generated/example_remote_datasource.g.dart
│   │           │       └── dto/
│   │           │           ├── example_dto.dart            # Freezed + fromJson + toDomain()
│   │           │           └── generated/
│   │           └── network/
│   │               ├── dio_client.dart           # createDio() 팩토리
│   │               └── interceptor/
│   │                   ├── auth_interceptor.dart
│   │                   └── error_interceptor.dart
│   │
│   ├── design_system/               # 공유 UI 컴포넌트
│   │   └── lib/src/
│   │       ├── tokens/               # Colors, Typography, Spacing
│   │       ├── theme/                # AppTheme (light/dark)
│   │       └── widgets/              # AppButton 등
│   │
│   └── lint_rules/                  # 공유 analysis_options.yaml
│
└── pubspec.yaml                     # Workspace 루트 + Melos 설정
```

---

## 의존성 주입 (DI)

하이브리드 DI: **GetIt + Injectable** (서비스 객체) + **Riverpod** (UI 상태만).

### 왜 하이브리드?

- **GetIt + Injectable**: 서비스 계층 (Dio, DataSource, Repository) — 싱글톤/팩토리 라이프사이클, 파일명으로 자동 등록
- **Riverpod**: UI 상태 (Notifier, Router) — 반응형, 위젯 인식, 자동 해제

### 동작 흐름

```
main()
  → configureDependencies()         # GetIt이 모든 서비스 등록
  → ProviderScope(child: MyApp())   # Riverpod이 위젯 트리 감싸기

Widget
  → ref.watch(exampleNotifierProvider)   # Riverpod (UI 상태)
    → ref.watch(exampleRepositoryProvider)  # Riverpod (GetIt 브릿지)
      → getIt<ExampleRepository>()           # GetIt (서비스 객체)
        → ExampleRepositoryImpl              # Injectable 자동 등록
          → ExampleRemoteDataSource          # Injectable 자동 등록
            → Dio                            # Injectable @singleton
```

### 파일명 기반 자동 등록

data 패키지의 `build.yaml`에서 파일명 패턴으로 자동 등록 설정:

```yaml
injectable_generator:injectable_builder:
  options:
    auto_register: true
    file_name_pattern: "_repository_impl$|_usecase$|_datasource$"
```

**어노테이션 필요 없음!** 파일명만 맞추면 됨:

```
user_repository_impl.dart     → _repository_impl$ 매칭 → UserRepository로 자동 등록
get_examples_usecase.dart     → _usecase$ 매칭        → 자동 등록
user_remote_datasource.dart   → _datasource$ 매칭     → 자동 등록 (Retrofit factory)
```

- `*_repository_impl` — 추상 클래스를 `implement` → 그 인터페이스로 등록
- `*_datasource` — Retrofit 추상 클래스 (factory constructor) → Injectable이 factory 호출

### @module이 필요한 경우

직접 소유하지 않는 서드파티 객체만:

```dart
@module
abstract class DataModule {
  @singleton
  Dio get dio => createDio();    // 서드파티라 수동 등록 필요
}
```

나머지는 전부 파일명으로 자동 등록.

### GetIt → Riverpod 브릿지

`di/providers.dart`에서 GetIt 서비스를 Riverpod으로 브릿지:

```dart
@riverpod
ExampleRepository exampleRepository(Ref ref) => getIt<ExampleRepository>();
```

---

## 코드 생성

모든 생성 파일은 `generated/` 하위 디렉토리로 출력. 소스 파일이 깔끔하게 유지됨.

### build.yaml

각 패키지의 `build.yaml`에서 생성 파일 경로 리다이렉트:

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

### part 지시자

모든 `part` 지시자는 `generated/` 하위 디렉토리를 가리킴:

```dart
// 기본 (일반적)
part 'example.freezed.dart';

// 이 스캐폴더
part 'generated/example.freezed.dart';
```

### .gitignore

생성 파일은 버전 관리에서 제외:

```
**/generated/
```

### 코드 생성 실행

```bash
melos run gen          # 일회성 빌드
melos run gen:watch    # 감시 모드 (변경 시 자동 재빌드)
```

---

## 새 기능 추가하기

예시: "유저 프로필" 기능 추가.

### 1단계: Domain (순수 Dart 계약)

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

배럴 파일 업데이트: `packages/domain/lib/domain.dart`

### 2단계: Data (구현)

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
// 파일명이 _repository_impl$에 매칭 → UserRepository로 자동 등록!
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._remote);
  final UserRemoteDataSource _remote;

  @override
  Future<User> getProfile() async => (await _remote.getProfile()).toDomain();
}
```

배럴 파일 업데이트: `packages/data/lib/data.dart`

> DataSource는 파일명(`_datasource$`)으로 자동 등록. data_module.dart 수정 불필요!

### 3단계: 앱 DI 브릿지

```dart
// apps/app/lib/di/providers.dart — 한 줄 추가
@riverpod
UserRepository userRepository(Ref ref) => getIt<UserRepository>();
```

### 4단계: Presentation

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

### 5단계: 생성 & 실행

```bash
melos run gen
```

---

## 다국어 (i18n) — slang

[slang](https://pub.dev/packages/slang) 기반 타입세이프 다국어 지원. YAML로 관리하고 build_runner로 생성.

### 파일 구조

```
apps/app/
└── lib/i18n/
    ├── strings_ko.i18n.yaml          # 한국어 (base locale)
    ├── strings_en.i18n.yaml          # 영어
    └── generated/                    # 자동 생성 (gitignore)
        └── strings.g.dart
```

### YAML 파일 형식

```yaml
# strings_ko.i18n.yaml
appTitle: 앱
greeting: 안녕하세요, {name}님
items(param=count):
  one: ${count}개 아이템
  other: ${count}개 아이템들
common:
  button:
    save: 저장
    cancel: 취소
```

### 사용법

```dart
// 어디서든 글로벌 `t` 사용
Text(t.appTitle);
Text(t.greeting(name: '정욱'));
Text(t.common.button.save);

// 복수형 자동 처리
Text(t.items(count: 3));
```

### 새 언어 추가

1. `lib/i18n/strings_ja.i18n.yaml` 파일 생성
2. `melos run gen` 실행 (build_runner가 자동 생성)
3. 끝!

### 설정 (build.yaml)

```yaml
slang_build_runner:
  options:
    base_locale: ko
    input_directory: lib/i18n
    output_directory: lib/i18n/generated
```

`melos run gen`으로 다른 코드젠과 함께 한번에 생성.

---

## 파일 네이밍 규칙

- **`*_repository_impl.dart`** — Injectable 자동 등록 (추상 Repository를 implement)
- **`*_usecase.dart`** — Injectable 자동 등록
- **`*_remote_datasource.dart`** — Retrofit 클라이언트, 자동 등록 (`_datasource$` 패턴)
- **`*_dto.dart`** — Freezed DTO (`fromJson()` + `toDomain()`)
- **`*_notifier.dart`** — Riverpod AsyncNotifier (`@riverpod class`)
- **`*_screen.dart`** — Flutter ConsumerWidget

---

## Melos 스크립트

- `melos run gen` — 전체 패키지 build_runner 실행 (freezed + retrofit + injectable + riverpod + slang)
- `melos run gen:watch` — 감시 모드
- `melos run test` — 전체 패키지 테스트
- `melos run analyze` — 전체 패키지 분석
- `melos run format` — 전체 패키지 포맷
- `melos run clean` — 전체 패키지 클린

---

## 기술 스택

- **아키텍처**: DDD (Domain-Driven Design)
- **DI**: GetIt + Injectable (서비스 계층, 파일명 자동 등록)
- **상태 관리**: Riverpod 3.0 (UI 상태만)
- **라우팅**: GoRouter
- **HTTP**: Dio + Retrofit
- **다국어**: slang (YAML, 타입세이프, build_runner 통합)
- **코드 생성**: Freezed, json_serializable, injectable_generator, riverpod_generator, slang_build_runner
- **디자인 시스템**: 공유 디자인 토큰 + 테마 + 위젯
- **모노레포**: Melos v7 + Pub Workspaces

## 특징

- SDK 버전을 로컬 Flutter/Dart 설치에서 자동 감지
- 패키지 버전을 pub.dev에서 실시간 조회
- 업데이트 모드: 기존 프로젝트에 다시 실행하면 누락된 구성요소만 추가
- 프로젝트 이름, 플랫폼, 조직명 입력 검증
- 생성 파일이 `generated/` 하위 디렉토리로 출력 (깔끔한 소스 트리)
- Injectable 파일명 패턴 자동 등록 (DI 보일러플레이트 제로)
