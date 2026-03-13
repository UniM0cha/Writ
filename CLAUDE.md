# Writ 프로젝트

## PRD
PRD 파일: `writ-prd.md` — 기능 구현/제거 판단 시 반드시 참조할 것
처음부터 iPhone/iPad/Mac/Apple Watch 멀티플랫폼으로 설계된 앱
iCloud 동기화는 유료 개발자 계정 전환 후 구현 예정 → 설정 UI 유지, 제거 금지

## 품질 검증 (필수)
- 구현 완료 후 반드시 `feature:test-writing` → `feature:code-review` 순서로 실행
- 구현 계획(plan) 작성 시에도 검증 단계에 test-writer + code-reviewer를 항상 명시

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
