# Writ 프로젝트

## PRD
PRD 파일: `writ-prd.md` — 기능 구현/제거 판단 시 반드시 참조할 것
처음부터 iPhone/iPad/Mac/Apple Watch 멀티플랫폼으로 설계된 앱
iCloud 동기화는 유료 개발자 계정 전환 후 구현 예정 → 설정 UI 유지, 제거 금지

## XcodeGen
- `xcodegen generate` 후 반드시 entitlements 파일 확인 (초기화될 수 있음)
- entitlements는 `properties:` 블록으로 값을 명시해야 보존됨
- `platforms: [iOS]` dependency 필터가 pbxproj에 반영 안 됨 → python3으로 `platformFilter` 수동 패치 필요

## 멀티플랫폼 코드 가드
- ActivityKit, WatchConnectivity → `#if os(iOS)` 사용 (`#if canImport` 아님 — macOS SDK에 존재하나 unavailable)
- `navigationBarTitleDisplayMode`, `.insetGrouped`, `toolbarColorScheme(_:for:.navigationBar)` → `#if os(iOS)`
- iOS 전용 extension (WritKeyboard, WritWidgetExtension)은 pbxproj `platformFilter = ios`로 macOS 빌드에서 제외
