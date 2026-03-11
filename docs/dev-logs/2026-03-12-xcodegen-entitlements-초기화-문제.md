---
title: "XcodeGen이 entitlements 파일을 매번 초기화하는 문제"
date: 2026-03-12
tags: [til, swift, xcodegen, config]
severity: error
---

# XcodeGen이 entitlements 파일을 매번 초기화하는 문제

## 증상

```
$ xcodegen generate
⚙️  Generating plists...
⚙️  Writing project...

$ cat Writ/Writ.entitlements
<dict/>   # App Group이 사라짐!
```

`xcodegen generate` 실행 후 수동으로 작성한 entitlements 내용이 빈 `<dict/>`로 리셋됨.

## 원인

project.yml에서 `entitlements: path:` 만 지정하면, XcodeGen이 해당 파일을 빈 plist 템플릿으로 **덮어쓴다**.

## 해결

`properties:` 블록에 entitlements 값을 명시하면 XcodeGen이 해당 내용을 포함한 파일을 생성한다.

```yaml
# Before (매번 초기화됨)
entitlements:
  path: Writ/Writ.entitlements

# After (내용 유지됨)
entitlements:
  path: Writ/Writ.entitlements
  properties:
    com.apple.security.application-groups:
      - group.com.solstice.writ
```
