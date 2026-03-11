# Writ

**구독 없이, 내 기기에서 돌아가는 온디바이스 음성 전사 앱**

구독료에 지친 사람들을 위한 1회성 결제 앱. 로컬 리소스를 최대한 활용하여 클라우드 서버 비용 없이 고품질 음성 전사를 제공합니다.

## 주요 기능

- **온디바이스 전사** — 인터넷 없이, 기기에서 직접 전사. 무제한 사용
- **커스텀 키보드** — 어떤 앱에서든 Writ 키보드로 전환하여 음성을 텍스트로 직접 입력
- **Dynamic Island** — 화면을 가리지 않고 녹음 상태 표시. 다른 앱 사용 중에도 녹음 유지
- **빠른 실행** — 뒷면탭, 액션 버튼, Siri Shortcuts로 어디서든 즉시 녹음
- **Mac fn 키** — fn 키 한 번으로 녹음 → 전사 → 클립보드 복사 → 붙여넣기
- **iCloud 동기화** — 녹음본과 전사문을 모든 Apple 기기에서 확인
- **내보내기** — TXT, SRT(타임스탬프 자막) 포맷 지원

## 지원 플랫폼

| 플랫폼 | 최소 OS | 역할 |
|---|---|---|
| iPhone | iOS 17 | 녹음, 온디바이스 전사 |
| iPad | iPadOS 17 | 녹음, 온디바이스 전사 |
| Mac | macOS 14 | 녹음, 온디바이스 전사, 메뉴바 앱 |
| Apple Watch | watchOS 10 | 녹음 (전사는 iPhone에서 처리) |

## 전사 모델

[WhisperKit](https://github.com/argmaxinc/WhisperKit) (MIT) 기반, Apple Silicon 최적화 CoreML 모델 5종 제공:

| 모델 | 크기 | 특징 |
|---|---|---|
| tiny | ~75 MB | 가장 빠름. 구형 기기용 |
| base | ~142 MB | 빠른 속도. 일상적 사용 |
| small | ~466 MB | 속도와 정확도의 균형 |
| large-v3 | ~947 MB | 최고 정확도 |
| large-v3 turbo | ~954 MB | 높은 정확도 + 빠른 속도 |

기기 칩셋에 따라 지원 모델이 자동으로 결정되며, large 모델 전사 실패 시 자동 폴백됩니다.

## 기술 스택

- **UI:** SwiftUI (Multiplatform)
- **전사 엔진:** WhisperKit (CoreML/Neural Engine)
- **데이터 동기화:** CloudKit
- **녹음:** AVAudioSession + Background Modes
- **Dynamic Island:** ActivityKit / Live Activity
- **빠른 실행:** App Intents (Siri Shortcuts)
- **키보드:** UIInputViewController + textDocumentProxy
- **Mac 단축키:** NSEvent global monitor
- **Watch 통신:** WatchConnectivity

## 빌드

Xcode 15 이상, Swift 5.9 이상 필요.

```bash
# 프로젝트 열기
open Writ.xcodeproj
```

SPM 의존성은 Xcode에서 자동으로 resolve됩니다.

## 라이선스

All rights reserved.
