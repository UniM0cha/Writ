# Writ 프로젝트

## PRD
PRD 파일: `writ-prd.md` — 기능 구현/제거 판단 시 반드시 참조할 것
처음부터 iPhone/iPad/Mac/Apple Watch 멀티플랫폼으로 설계된 앱
iCloud 동기화는 유료 개발자 계정 전환 후 구현 예정 → 설정 UI 유지, 제거 금지

## XcodeGen
- `xcodegen generate` 후 반드시 entitlements 파일 확인 (초기화될 수 있음)
- entitlements는 `properties:` 블록으로 값을 명시해야 보존됨
- `platforms: [iOS]` dependency 필터가 pbxproj에 반영 안 됨 → python3으로 `platformFilter` 수동 패치 필요

## 품질 검증 (필수)
- 구현 완료 후 반드시 `feature:test-writing` → `feature:code-review` 순서로 실행
- 구현 계획(plan) 작성 시에도 검증 단계에 test-writer + code-reviewer를 항상 명시

## 멀티플랫폼 코드 가드
- ActivityKit, WatchConnectivity, BackgroundTasks(BGContinuedProcessingTask) → `#if os(iOS)` 사용 (`#if canImport` 아님 — macOS SDK에 존재하나 unavailable)
- `navigationBarTitleDisplayMode`, `.insetGrouped`, `toolbarColorScheme(_:for:.navigationBar)` → `#if os(iOS)`
- iOS 전용 extension (WritKeyboard, WritWidgetExtension)은 pbxproj `platformFilter = ios`로 macOS 빌드에서 제외

## 백그라운드 전사 (iOS)
- `BGContinuedProcessingTask` (iOS 26+) 사용 — 사용자 액션(녹음 중지) 시 register + submit
- Task identifier: `com.solstice.writ.transcribe` (Info.plist BGTaskSchedulerPermittedIdentifiers에 등록됨)
- BGTask 제출 실패 시 fallback으로 fire-and-forget Task 실행
- macOS는 백그라운드 제한 없으므로 직접 Task 실행

## UI 검증 (시뮬레이터 스크린샷)
UI 관련 수정사항은 반드시 시뮬레이터 스크린샷으로 직접 검증할 것:
```bash
# 시뮬레이터 부팅
xcrun simctl boot "iPhone 16 Pro"

# 빌드 & 설치
xcodebuild build -scheme Writ -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO
xcrun simctl install booted <app_path>
xcrun simctl launch booted <bundle_id>

# 스크린샷 캡처 → Read 도구로 확인
xcrun simctl io booted screenshot /tmp/screenshot.png
```
- 수정 전/후 스크린샷을 비교하여 의도대로 변경되었는지 확인
- 레이아웃, 색상, 텍스트 위치 등 시각적 요소를 직접 눈으로 검증
