---
title: "mlx-swift fmt consteval 에러 — Xcode 26 Apple Clang 21 호환성"
date: 2026-03-27
tags: [swift, c++, dependency, compiler]
severity: error
---

# mlx-swift fmt consteval 에러 — Xcode 26 Apple Clang 21 호환성

## 상황

Writ 프로젝트를 Xcode 26.3에서 빌드하던 중, 직접 작성한 코드가 아닌 전이 의존성(WhisperKit → mlx-swift → fmt)에서 컴파일 에러가 발생했다. 프로젝트 코드는 전혀 변경하지 않았는데 갑자기 빌드가 깨진 상황.

## 에러 내용

```
mlx-swift/Source/Cmlx/fmt/include/fmt/format-inl.h:61:24
Call to consteval function 'fmt::basic_format_string<char, ...>::basic_format_string<FMT_COMPILE_STRING, 0>'
is not a constant expression

mlx-swift/Source/Cmlx/fmt/include/fmt/format-inl.h:62:22
Call to consteval function 'fmt::basic_format_string<char, const char (&)[7], int &>::basic_format_string<FMT_COMPILE_STRING, 0>'
is not a constant expression
```

총 5개의 유사한 에러가 `format-inl.h`에서 발생.

## 원인 분석

의존성 체인: `Writ → WhisperKit v0.17.0 → mlx-swift v0.31.1 → Cmlx → fmt 10.2.1`

mlx-swift의 `Package.swift`에서 C++ 언어 표준을 `gnucxx20`(C++20)으로 설정:

```swift
// mlx-swift/Package.swift:337
cxxLanguageStandard: .gnucxx20
```

C++20 모드에서 fmt 10.2.1의 `core.h`가 `FMT_CONSTEVAL`을 `consteval`로 활성화:

```cpp
// fmt/include/fmt/core.h:224-233
#ifndef FMT_CONSTEVAL
#  if ((FMT_GCC_VERSION >= 1000 || FMT_CLANG_VERSION >= 1101) && \
       (!defined(__apple_build_version__) ||                     \
        __apple_build_version__ >= 14000029L) &&                 \
       FMT_CPLUSPLUS >= 202002L)
#    define FMT_CONSTEVAL consteval   // ← C++20 + Apple Clang 21이면 활성화
#  else
#    define FMT_CONSTEVAL
#  endif
#endif
```

Apple Clang 21(Xcode 26)이 `consteval` 평가를 이전 버전보다 더 엄격하게 검증하면서, fmt 10.2.1의 `FMT_COMPILE_STRING` 패턴이 "상수 표현식이 아니다"라고 거부당함.

## 해결 과정

### 시도 1: 의존성 업데이트

mlx-swift(0.31.1), WhisperKit(0.17.0) 모두 이미 최신 릴리스. 업스트림에 아직 수정이 없음.

### 시도 2: 프로젝트 레벨 C++ 플래그

`project.yml`에 `OTHER_CPLUSPLUSFLAGS: ["-DFMT_CONSTEVAL="]` 추가 → **실패**. SPM 패키지 타겟은 프로젝트 레벨 빌드 설정을 상속하지 않음.

### 시도 3: 로컬 패키지 오버라이드 (성공)

1. mlx-swift를 서브모듈 포함하여 로컬 클론:
```bash
git clone --branch 0.31.1 --recursive https://github.com/ml-explore/mlx-swift.git ../mlx-swift
```

2. `Package.swift`의 Cmlx 타겟 cxxSettings에 define 추가:
```diff
 // mlx-swift/Package.swift:207-213
 cxxSettings: cxxSettings + [
     .headerSearchPath("mlx"),
     .headerSearchPath("mlx-c"),
     .headerSearchPath("json/single_include/nlohmann"),
     .headerSearchPath("fmt/include"),
     .define("MLX_VERSION", to: "\"0.31.1\""),
+    .define("FMT_CONSTEVAL", to: ""),
 ],
```

3. `project.yml`에 로컬 패키지 참조 추가:
```yaml
packages:
  WhisperKit:
    url: https://github.com/argmaxinc/WhisperKit.git
    from: "0.16.0"
  Qwen3Speech:
    url: https://github.com/ivan-digital/qwen3-asr-swift.git
    from: "0.0.7"
  mlx-swift:
    path: ../mlx-swift   # 로컬 오버라이드
```

SPM이 패키지 identity(`mlx-swift`)가 동일하면 로컬 버전을 우선 사용하므로, WhisperKit과 Qwen3Speech가 원격 mlx-swift 대신 패치된 로컬 버전을 참조하게 된다.

**주의**: 디렉토리 이름이 패키지 identity와 일치해야 한다. `mlx-swift-local` 같은 이름을 쓰면 `identity doesn't match override's identity` 에러 발생.

## 배운 점

SPM 패키지 타겟은 프로젝트 레벨 빌드 설정을 상속하지 않으므로, 전이 의존성의 C++ 빌드 플래그를 바꾸려면 로컬 패키지 오버라이드가 유일한 방법이다. `#ifndef` 가드가 있는 매크로는 `-D` define으로 선제 정의하여 우회할 수 있다.
