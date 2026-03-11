# Writ — Product Requirements Document

## 1. 제품 개요

**앱 이름:** Writ

**한 줄 소개:** 구독 없이, 내 기기에서 돌아가는 온디바이스 음성 전사 앱

**핵심 가치:** 구독료에 지친 사람들을 위한 1회성 결제 앱. 사용자의 로컬 리소스를 최대한 활용하여 클라우드 서버 비용 없이 고품질 음성 전사를 제공한다.

**비즈니스 모델:** 유니버설 구매 (1회성 유료, **$4.99 / ₩7,500**). iPhone, iPad, Mac, Apple Watch 모두 하나의 구매로 사용 가능. 구독 없음, 추가 결제 없음. 월 약 3건 판매로 Apple Developer Program 연회비($99/year) 유지 가능.

### 배경 및 동기

기존 음성 전사 워크플로우에는 명확한 불편함이 있다:

- **클로바 노트:** 600분 제한이 걸려 있어 자유롭게 사용할 수 없음
- **ChatGPT 음성 인식:** 정확도는 가장 좋지만, 앱에 진입 → 음성 인식 → 전사문 복사 → 붙여넣을 앱으로 이동 → 붙여넣기 과정이 지나치게 번거로움
- **Groq API + Shortcuts:** 녹음 시 Shortcuts UI가 화면을 가리기 때문에 다른 작업과 병행이 불가능

Writ은 이 문제들을 해결한다:
- **Dynamic Island** 로 녹음을 표시하여 화면을 가리지 않음
- **뒷면탭 / 액션 버튼** 으로 어디서든 즉시 녹음 시작
- **Mac에서는 fn 키** 로 빠른 녹음 → 전사 → 클립보드 복사 → 포커스된 인풋에 붙여넣기까지 원스텝
- **로컬 모델** 이므로 제한 없이 무제한 사용 가능
- 녹음 파일이 기기에 남아 **데이터 유실 위험 최소화**

### 핵심 사용 시나리오

1. **빠른 음성 입력 (iPhone — 키보드 방식):** 텍스트 필드에서 Writ 키보드로 전환 → 마이크 버튼 탭 → 녹음 → 전사 → textDocumentProxy로 현재 인풋에 직접 삽입
2. **빠른 음성 입력 (iPhone — 클립보드 방식):** 뒷면탭/액션 버튼 → Dynamic Island 녹음 시작 → 다른 앱 사용 중에도 녹음 유지 → 녹음 중지 → 전사 완료 → 클립보드 복사 → 사용자가 붙여넣기
3. **빠른 음성 입력 (Mac):** fn 키 꾹 누르기 → 녹음 + 전사 + 클립보드 복사 + 포커스된 인풋에 자동 붙여넣기
4. **회의/강의 녹음:** 긴 시간 녹음 → 온디바이스 또는 Mac 서버에서 전사 → 타임스탬프 포함 전사문 확인 → SRT/TXT 내보내기

**타겟 사용자:**
- 회의, 프롬프트 입력 등에서 음성 전사를 자주 사용하는 사람
- 구독형 전사 서비스에 피로감을 느끼는 사람
- Mac Mini 등을 로컬 AI 서버로 활용하는 사람
- Apple 생태계 사용자

---

## 2. 플랫폼 및 기술 스택

### 지원 플랫폼
| 플랫폼 | 최소 OS | 역할 |
|---|---|---|
| iPhone | iOS 17 | 녹음, 온디바이스 전사, Mac 서버 연동 |
| iPad | iPadOS 17 | 녹음, 온디바이스 전사, Mac 서버 연동 |
| Mac | macOS 14 (Sonoma) | 녹음, 온디바이스 전사, **홈 서버 역할** |
| Apple Watch | watchOS 10 | 녹음 전용 (전사는 iPhone에서 처리) |

### 기술 스택
- **UI 프레임워크:** SwiftUI (Multiplatform App 템플릿)
- **음성 전사 엔진:** WhisperKit (MIT, Argmax) — Apple Silicon 최적화, CoreML/Neural Engine 활용
- **전사 엔진 추상화:** `TranscriptionEngine` 프로토콜을 통한 엔진 교체 가능 아키텍처 (v1은 WhisperKit 단독, 향후 Qwen3-ASR 등 대체 엔진 대비)
- **데이터 동기화:** CloudKit (iCloud Private Database)
- **백그라운드 녹음:** AVAudioSession (.playAndRecord) + Background Modes
- **Dynamic Island:** ActivityKit / Live Activity
- **빠른 실행 연동:** App Intents (Siri Shortcuts, 뒷면탭, 액션 버튼)
- **커스텀 키보드 익스텐션:** UIInputViewController + textDocumentProxy (전사문 직접 삽입)
- **Mac 글로벌 단축키:** NSEvent.addGlobalMonitorForEvents (fn 키 빠른 녹음)
- **Apple Watch 통신:** WatchConnectivity (녹음 완료 후 일괄 전송)
- **(v2 예정) 기기 간 근거리 통신:** Bonjour/mDNS (Mac 서버 모드용)

---

## 3. 온디바이스 전사 모델

### WhisperKit 디바이스별 지원 모델 (소스코드 기준)

| 칩 | 대표 기기 | 기본 모델 | 지원 모델 |
|---|---|---|---|
| A12, A13 | iPhone XS/XR, iPhone 11 시리즈, Watch S9/S10 | tiny | tiny, base |
| A14 | iPhone 12 시리즈, iPad Air 4 | base | tiny, base, small |
| A15 | iPhone 13 시리즈, iPhone 14/14 Plus, iPhone SE 3 | base | tiny, base, small |
| A16, A17 Pro, A18 | iPhone 14 Pro/Max, iPhone 15 전체, iPhone 16 전체 | small | tiny, base, small, **large-v3, large-v3 turbo** |
| M 시리즈 | M1/M2/M3/M4 Mac, iPad Pro/Air (M칩) | large-v3 turbo | **전 모델 지원** |

> **참고:** large-v3 및 large-v3 turbo는 CoreML + QLoRA mixed-bit quantization으로 약 947~954MB로 압축된 버전을 사용한다. 원본 대비 정확도 차이는 거의 없으나(WhisperKit ICML 2025 논문 기준 2.2% WER), iPhone에서의 안정성은 기기와 상황에 따라 다를 수 있다.

### 앱에서 제공하는 모델 (5개)

모든 모델은 다국어 버전만 제공한다 (영어 전용 .en 모델 미포함). 기기 한계에 맞는 기본 모델을 자동 설정하되, 사용자가 원하면 해당 기기에서 지원하는 더 큰 모델을 다운로드하여 사용할 수 있다.

| 모델 | 파라미터 | 디스크 (CoreML) | 배포 방식 | 특징 |
|---|---|---|---|---|
| tiny | 39M | ~75 MB | 앱 번들 포함 | 가장 빠름. 정확도 낮음. 구형 기기용 |
| base | 74M | ~142 MB | 앱 번들 포함 | 빠른 속도. 일상적 사용에 적합 |
| small | 244M | ~466 MB | 앱 번들 포함 | 속도와 정확도의 균형. 대부분의 사용자에게 권장 |
| large-v3 | 1.55B | ~947 MB | 앱 내 다운로드 | 최고 정확도. A16+ iPhone, M칩 기기에서 사용 가능. 느림 |
| large-v3 turbo | 809M | ~954 MB | 앱 내 다운로드 | large-v2급 정확도 + 빠른 속도. 디코더 4층(tiny급). 실용적 고품질 모드 |

### 제외한 모델 및 사유

| 모델 | 제외 사유 |
|---|---|
| .en 모델 (tiny.en, base.en, small.en, medium.en) | 영어 전용. Writ은 다국어 앱이므로 다국어 모델만 제공. |
| medium | 769M 파라미터로 small과 large 사이에 위치하나, CoreML 압축 large 모델(947MB)과 크기가 비슷하면서 정확도는 large보다 낮아 존재 의의가 약함. A16+ 기기에서 large를 쓰는 게 나으므로 제외. |
| large-v1 | large-v2에 의해 완전히 대체됨. 모든 면에서 v2 이상이 우위. |
| large-v2 | large-v3에 의해 대체됨. v3가 v2 대비 10~20% 오류율 감소. turbo도 v2급 정확도이므로 v2를 별도로 제공할 필요 없음. |
| distil-large-v3 | HuggingFace 커뮤니티 파생 모델. large-v3 turbo가 OpenAI 공식 경량화 모델로서 동일한 역할을 더 잘 수행. 관리 복잡도 증가 대비 이점 부족. |
| large-v3 full-size (2.9GB) | CoreML 압축 버전(947MB)과 정확도 차이가 거의 없음 (WhisperKit QLoRA 압축으로 품질 보장). 3배 큰 용량 대비 이점 없음. |

### 기기별 전사 전략 및 한계점

**A12~A13 (iPhone XS/XR, iPhone 11 시리즈)**
- 사용 가능 모델: tiny, base
- 기본 모델: tiny
- 한계점: RAM 3~4GB로 small 이상 로드 불가. 전사 속도 느림. UI에 "이 기기에서는 tiny/base 모델만 사용 가능합니다" 안내 표시.

**A14 (iPhone 12 시리즈, iPad Air 4)**
- 사용 가능 모델: tiny, base, small
- 기본 모델: base
- 한계점: RAM 4~6GB. small 모델까지는 안정적. 긴 녹음(1시간+) 전사 시 시간 소요 안내 필요.

**A15 (iPhone 13 시리즈, iPhone 14/14 Plus, iPhone SE 3)**
- 사용 가능 모델: tiny, base, small
- 기본 모델: base
- 한계점: A14와 유사. RAM 4~6GB. large 모델 미지원. UI에서 large 모델은 비활성 + "iPhone 14 Pro 이상에서 사용 가능" 안내.

**A16, A17 Pro, A18 (iPhone 14 Pro/Max ~ iPhone 16 전체)**
- 사용 가능 모델: tiny, base, small, large-v3, large-v3 turbo
- 기본 모델: small
- 한계점: RAM 6~8GB. large 모델(~950MB) 로드 가능하나, 다른 앱과 병행 시 메모리 압박으로 크래시 가능성 있음. 전사 속도가 Mac 대비 현저히 느림. UI에 "고품질 모드: 전사 시간이 더 걸리며, 다른 앱 사용 시 중단될 수 있습니다" 경고 표시. 실패 시 small 모델로 자동 폴백.

**M 시리즈 (Mac, iPad Pro/Air M칩)**
- 사용 가능 모델: 전 모델
- 기본 모델: large-v3 turbo (Mac), small (iPad)
- 한계점: Mac에서는 사실상 제한 없음. M칩 iPad는 Mac과 동일 모델 지원이나 발열/배터리 고려 필요.

**Apple Watch (S9, S10)**
- 사용 가능 모델: 없음 (전사 불가)
- 역할: 녹음 전용. 녹음 완료 후 iPhone으로 전송하여 전사.

### large-v3 vs large-v3 turbo 선택 가이드 (앱 내 안내용)

| | large-v3 | large-v3 turbo |
|---|---|---|
| 정확도 | **최고** (v3 원본급) | large-v2급 (v3보다 약간 낮음) |
| 속도 | 느림 (디코더 32층) | **빠름** (디코더 4층, tiny급) |
| 크기 | ~947 MB | ~954 MB |
| 추천 상황 | 정확도가 최우선인 경우 (회의록, 중요 녹음) | 빠른 전사가 필요한 일상 사용 |
| 한국어 참고 | 최고 정확도 | 일부 언어에서 정확도 하락 보고 있으나 한국어 관련 별도 데이터 부족. 테스트 필요 |

### 전사 결과물
- **타임스탬프:** WhisperKit의 word-level 및 segment-level 타임스탬프 지원
- **화자 분리:** v1에서는 미지원 (향후 오픈소스 기반 구현 검토)
- **지원 언어:** Whisper 지원 다국어, 사용자가 녹음 시 언어 선택

---

## 4. 앱 아키텍처

### 동기화 구조 (v1)

```
[Apple Watch] ──WatchConnectivity──▶ [iPhone]
                                        │
                                        ▼
                              ┌──── CloudKit ────┐
                              │  (iCloud Private  │
                              │   Database)       │
                              └───────────────────┘
                                   ▲        ▲
                                   │        │
                              [iPad]      [Mac]
```

v1에서는 모든 기기가 각자 온디바이스 전사를 수행하고, 녹음본과 전사 결과를 CloudKit으로 동기화한다. Mac 서버 모드(iPhone의 녹음을 Mac에서 대신 전사)는 v2에서 추가한다.

### 전사 플로우

**모드 1 — 온디바이스 전사**
1. 각 기기(iPhone/iPad/Mac)에서 녹음
2. 해당 기기에서 지원하는 모델 중 사용자가 선택한 모델로 온디바이스 전사
3. 결과를 CloudKit에 업로드 (네트워크 가용 시)
4. large 모델 전사 실패 시 small 모델로 자동 폴백

**모드 2 — Apple Watch**
1. Apple Watch에서 녹음
2. 녹음 완료 후 WatchConnectivity로 iPhone에 일괄 전송
3. iPhone에서 전사 처리 (모드 1)

---

## 5. 기능 상세

### 5.1 녹음

**빠른 실행 (iPhone)**
- App Intent / Siri Shortcuts 제공: "Writ 녹음 시작/중지" 액션
- 사용자가 뒷면탭(Back Tap) 또는 액션 버튼에 Writ Shortcut 연결 가능
- Shortcut 실행 시 앱이 백그라운드에서 녹음 시작 + Dynamic Island 활성화
- 화면을 가리지 않으므로 다른 앱 사용 중에도 녹음 유지

**빠른 실행 (Mac)**
- fn 키 길게 누르기로 빠른 녹음 모드 진입
- 녹음 → 전사 → 클립보드 복사 → 포커스된 인풋에 자동 붙여넣기 (원스텝)
- 메뉴바 앱에서 글로벌 단축키 설정 가능

**일반 녹음**
- 모든 기기에서 녹음 가능 (iPhone, iPad, Mac, Apple Watch)
- iPhone/iPad: 백그라운드 녹음 지원
- Dynamic Island에서 녹음 시작/중지 가능 (Live Activity)
- 잠금 화면에서도 녹음 상태 확인 가능
- 긴 시간 녹음 지원 (회의, 강의 등)
- Mac: 메뉴바 앱 + 별도 윈도우에서 녹음 가능
- Apple Watch: 녹음 전용 (녹음 완료 후 iPhone 전송)

### 5.2 전사

- 온디바이스 전사 (오프라인 가능, 모든 전사는 각 기기 로컬에서 처리)
- 사용자가 기기에서 지원하는 모델 중 원하는 모델을 선택 가능
- 기기별 기본 모델 자동 설정 (A12~A13: tiny, A14~A15: base, A16+: small, M칩 Mac: large-v3 turbo)
- 지원하지 않는 모델은 비활성 표시 + 사유 안내 (예: "이 기기의 RAM이 부족하여 large 모델을 사용할 수 없습니다")
- large 모델 사용 시 경고 표시: "전사 시간이 더 걸리며, 다른 앱 사용 시 중단될 수 있습니다"
- large 모델 전사 실패 시 기본 모델로 자동 폴백
- word-level 타임스탬프 포함
- 사용자 언어 선택 (Whisper 지원 다국어)
- 전사 완료 시 알림

### 5.3 커스텀 키보드 익스텐션 (iPhone/iPad)

Writ 키보드를 제공하여, 어떤 앱의 텍스트 필드에서든 음성 전사 결과를 직접 삽입할 수 있도록 한다.

- 지구본 키(키보드 전환)로 Writ 키보드 활성화
- 마이크 버튼 탭 → 녹음 → 전사 → `textDocumentProxy.insertText()` 로 현재 인풋에 직접 삽입
- "최근 전사문 삽입" 버튼: 앱에서 전사 완료된 결과를 키보드에서 바로 삽입
- 키보드 익스텐션의 메모리 제한(~70MB)으로 인해, 키보드 내에서 직접 모델을 로드하지 않고 메인 앱과의 App Group 공유 또는 앱 실행 위임 방식으로 전사 처리
- 비밀번호 필드 등 보안 텍스트 입력에서는 시스템 키보드로 자동 전환

### 5.4 전사 결과 관리

- 녹음본 + 전사문 목록 관리
- 타임스탬프 포함 전사문 뷰 (세그먼트 탭 시 해당 오디오 위치로 이동)
- 전사문 텍스트 클립보드 복사
- 전사 완료 후 클립보드에 자동 복사 옵션

### 5.5 공유 및 내보내기

- 녹음본 공유 (iOS Share Sheet)
- 전사문 공유 (iOS Share Sheet)
- 전사문 클립보드 복사 (순수 텍스트)
- 내보내기 포맷: TXT (순수 텍스트), SRT (타임스탬프 자막)

### 5.6 동기화

- 녹음본 및 전사문 iCloud(CloudKit) 자동 동기화
- 같은 Apple ID 기기 간 자동 동기화
- 별도 서버 불필요

### 5.7 녹음본 저장 관리

- 설정에서 자동삭제 기간 선택 (30일, 90일, 180일, 삭제 안 함)
- iCloud 저장 공간 사용 (사용자의 iCloud 용량)

### 5.8 Mac 앱

- 메뉴바 앱으로 상주 + 별도 윈도우에서 녹음/전사/기록 확인
- 클램셸 모드 동작 지원
- fn 키 빠른 녹음 → 전사 → 붙여넣기
- large-v3 / large-v3 turbo 모델 앱 내 다운로드 가능
- **(v2 예정) Mac 서버 모드:** iPhone/iPad에서 보낸 녹음을 Mac에서 대신 전사 (Bonjour + CloudKit). 잠자기 방지 옵션 포함.

---

## 6. UI 구조

### iPhone / iPad

```
┌─────────────────────────┐
│  Tab 1: 녹음             │  녹음 버튼, 파형 시각화, 언어 선택
│  Tab 2: 기록             │  녹음/전사 목록, 검색
│  Tab 3: 설정             │  모델 관리 (다운로드/선택/한계 안내), 자동삭제, 언어
└─────────────────────────┘
```

### Mac

```
┌─────────────────────────┐
│  메뉴바 아이콘            │  빠른 녹음 시작/중지, 모델 상태
│  메인 윈도우              │  녹음, 전사 기록, 모델 관리, 설정
└─────────────────────────┘
```

### Apple Watch

```
┌─────────────────────────┐
│  녹음 버튼               │  탭하여 녹음 시작/중지
│  녹음 목록               │  최근 녹음, iPhone 전송 상태
└─────────────────────────┘
```

### Dynamic Island (iPhone)

```
Compact: [● REC  00:03:42]
Expanded: [● 녹음 중  00:03:42  ■ 중지]
```

---

## 7. 기술적 고려사항

### 전사 엔진 추상화 레이어

v1은 WhisperKit 단독이지만, 향후 엔진 교체(Qwen3-ASR CoreML 등)를 대비하여 프로토콜 기반 추상화를 적용한다.

```swift
protocol TranscriptionEngine {
    func transcribe(audio: URL, language: String?) async throws -> TranscriptionResult
    func supportedModels(for device: DeviceCapability) -> [TranscriptionModel]
    func loadModel(_ model: TranscriptionModel) async throws
    func unloadModel() async
}
```

- v1 구현체: `WhisperKitEngine: TranscriptionEngine`
- 프로토콜은 컴파일 타임에 해소되므로 런타임 성능 오버헤드 없음
- 엔진 교체, Mock 테스트, A/B 테스트 구조 대비

**검토 후 제외한 대안 엔진:**

| 엔진 | 한국어 | 제외 사유 |
|---|---|---|
| Apple SpeechAnalyzer (iOS 26) | O (ko_KR) | 한국어 전사 품질이 기존 SFSpeechRecognizer와 체감 차이 없음. 직접 테스트 결과 부적합 판정. iOS 26+ 전용이라 하위 호환성도 불리. |
| Qwen3-ASR 0.6B | O (52개 언어) | 오픈소스 SOTA급 정확도. CoreML/Swift 통합(speech-swift)이 아직 초기 단계라 v1에서는 시기상조. 성숙 시 v2+ 후보. |
| NVIDIA Parakeet TDT v3 | X | 한국어 미지원 (25개 유럽 언어만). |
| Canary Qwen 2.5B | X | 한국어 미지원. 2.5B로 iPhone 온디바이스 불가. |
| Voxtral (Mistral) | 불확실 | 3B 최소. iPhone 불가. 한국어 지원 불확실. |

### WhisperKit 통합
- WhisperKit 오픈소스 (MIT 라이선스) 사용
- SPM(Swift Package Manager)으로 의존성 관리
- CoreML 백엔드로 Neural Engine + CPU 동시 활용
- 다국어 모델만 사용 (.en 영어 전용 모델 미포함)
- tiny/base/small 모델: 앱 번들 포함 또는 최초 실행 시 다운로드
- large-v3 / large-v3 turbo (CoreML QLoRA 압축, 각 ~950MB): 설정에서 사용자 요청 시 앱 내 다운로드
- 기기 칩 식별 후 WhisperKit의 DeviceSupport 매핑에 따라 지원 모델 목록을 UI에 표시
- 지원하지 않는 모델은 비활성 + 사유 표시
- large 모델 전사 실패(메모리 부족 등) 시 기본 모델로 자동 폴백 로직 필수

### 커스텀 키보드 익스텐션
- iOS 키보드 익스텐션 메모리 제한: ~70MB (디바이스마다 상이)
- 키보드 내에서 Whisper 모델 직접 로드 불가 (tiny 모델조차 75MB)
- 구현 전략: 키보드에서 녹음 시작 → 메인 앱(또는 App Group 공유 프로세스)에 전사 위임 → 결과를 App Group UserDefaults/파일로 전달 → 키보드에서 textDocumentProxy.insertText() 호출
- 보안 텍스트 필드, 전화번호 필드에서는 자동으로 시스템 키보드 전환

### CloudKit
- Private Database 사용 (사용자의 iCloud 용량 사용, 개발자 서버 비용 0원)
- CKAsset으로 오디오 파일 저장
- CKRecord로 전사 결과 저장
- CKSubscription으로 변경사항 실시간 감지

### 백그라운드 동작
- Background Modes: Audio 활성화
- AVAudioSession: .playAndRecord 카테고리
- Live Activity: 녹음 상태를 Dynamic Island 및 잠금 화면에 표시

### Mac 앱
- NSApplication: .activationPolicy(.accessory) — 메뉴바 전용 모드
- 클램셸 모드 지원: Power Nap 또는 caffeinate 활용
- fn 키 글로벌 단축키: NSEvent.addGlobalMonitorForEvents

### (v2 예정) Mac 서버 모드
- Bonjour/mDNS: 같은 Wi-Fi 네트워크 내 Mac 서버 자동 탐지
- 로컬 통신 시 CloudKit보다 빠른 직접 전송, 네트워크 불가 시 CloudKit 폴백
- IOPMAssertionCreateWithName — 잠자기 방지 (사용자 설정 시)

---

## 8. v1 범위 및 향후 로드맵

### v1 (MVP) — 로컬 온디바이스 올인
- [x] iPhone/iPad/Mac/Apple Watch 멀티플랫폼 앱
- [x] 5개 모델 제공: tiny, base, small, large-v3, large-v3 turbo (다국어 버전만, CoreML 압축)
- [x] 기기별 지원 모델 자동 감지 + 한계점 UI 안내 (미지원 모델 비활성, 경고 표시, 자동 폴백)
- [x] Mac large-v3 / large-v3 turbo 다운로드 및 전사
- [x] CloudKit 동기화 (녹음본 + 전사문)
- [x] Dynamic Island + 백그라운드 녹음
- [x] App Intent / Siri Shortcuts (뒷면탭, 액션 버튼 연동)
- [x] 커스텀 키보드 익스텐션 (전사문 인풋 직접 삽입)
- [x] Mac fn 키 빠른 녹음 → 전사 → 붙여넣기
- [x] word-level 타임스탬프
- [x] TXT/SRT 내보내기
- [x] 클립보드 복사
- [x] 자동삭제 정책
- [x] 전사 엔진 추상화 레이어 (`TranscriptionEngine` 프로토콜, v1은 WhisperKit 구현체 단독)

### v2 (향후) — Mac 서버 모드 + 고급 기능
- [ ] Mac 홈 서버 모드 (Bonjour + CloudKit): iPhone/iPad 녹음을 Mac에서 large-v3로 대신 전사
- [ ] 외부 네트워크에서도 Mac 서버 접근 (CloudKit 경유)
- [ ] 잠자기 방지 옵션 (서버 모드 전용)
- [ ] 화자 분리 (오픈소스 pyannote CoreML 변환)
- [ ] 실시간 스트리밍 전사
- [ ] 전사 결과 검색
- [ ] PDF 내보내기
- [ ] 위젯 (녹음 빠른 시작)
- [ ] 전사 결과 편집 기능
- [ ] Qwen3-ASR CoreML 엔진 추가 검토 (0.6B: Whisper 대비 경량 + 높은 정확도, CoreML 통합 성숙 시)

---

## 9. 제약사항 및 리스크

| 항목 | 내용 | 대응 |
|---|---|---|
| iPhone large-v3 안정성 | A16+ iPhone에서 large-v3(947MB) 로드 시 크래시/멈춤 가능성 (GitHub 이슈 보고 있음) | 경고 UI 표시, 실패 시 기본 모델로 자동 폴백, 안정성 테스트 후 지원 범위 조정 |
| 구형 기기 사용자 불만 | A12~A15 사용자는 large 모델 사용 불가 | 모델 비활성 사유를 명확히 안내, v2에서 Mac 서버 모드로 보완 |
| 키보드 익스텐션 메모리 제한 | iOS 키보드 메모리 ~70MB, Whisper 모델 직접 로드 불가 | 메인 앱에 전사 위임 후 App Group으로 결과 전달 |
| iPhone 메모리 압박 | small 모델(~852MB)도 다른 앱과 병행 시 메모리 부족 가능 | 메모리 압박 감지 시 모델 언로드 후 재로드 |
| 앱 용량 | tiny/base/small 모델을 모두 번들에 포함하면 앱 크기 ~700MB+ | 기본은 small만 번들, tiny/base는 선택 다운로드로 분리 검토. 또는 최초 실행 시 기기에 맞는 모델만 다운로드 |
| iCloud 용량 | 녹음 파일이 사용자의 iCloud 용량을 소모 | 자동삭제 정책 + 용량 경고 UI |
| CloudKit 알림 지연 | Mac에서 CloudKit 알림 수신이 지연될 수 있음 | 네이티브 macOS 앱으로 구현, 폴링 폴백 |
| Apple Watch 파일 전송 | WatchConnectivity 대용량 파일 전송 불안정 가능 | 녹음 완료 후 백그라운드 전송, 실패 시 재시도 |
| Whisper 한국어 품질 | 일상 대화 환경에서 정확도 저하 가능 | 사용자 언어 수동 선택 옵션, 향후 fine-tuning 검토 |
| Windows 미지원 | Apple 생태계 전용 | 앱의 정체성으로 수용 |
| 경쟁 앱 | Superwhisper, Whisper Notes 등 유사 앱 존재 | 커스텀 키보드, Dynamic Island 빠른 실행, 1회 결제, 전 모델 개방을 차별점으로 |

### 개발자 계정별 구현 범위

현재 무료 개발자 계정(Personal Team)을 사용 중이므로, 일부 Apple Capability가 제한된다. 아래는 무료/유료 계정별로 구현 가능한 기능 정리.

**무료 계정(Personal Team)으로 구현 가능:**
- 녹음 (AVAudioRecorder) — iPhone, iPad, Mac, Watch 전부
- 온디바이스 전사 (WhisperKit) — 모든 모델
- SwiftData 로컬 저장 (기기 내 영속성)
- 기록 목록 / 상세 뷰 / 오디오 플레이어
- TXT, SRT 내보내기 / 클립보드 복사
- 설정 (모델 관리, 언어 선택, 자동삭제)
- Mac 메뉴바 앱 (MenuBarExtra)
- Mac fn 키 녹음 → 전사 → 붙여넣기
- Local Notification (전사 완료 알림 등)
- App Intents / Siri Shortcuts (뒷면탭, 액션 버튼)
- Dynamic Island / Live Activity
- Apple Watch 녹음 + WatchConnectivity 전송

**유료 계정(Apple Developer Program, $99/년) 전환 후 추가해야 하는 기능:**

| 기능 | 필요 Capability | 사유 |
|---|---|---|
| 키보드 확장 ↔ 메인 앱 전사 위임 | App Groups | 키보드 확장은 별도 프로세스이므로 메인 앱과 파일을 공유하려면 App Group 컨테이너 필수 |
| iCloud 동기화 (기기 간) | iCloud (CloudKit) | CloudKit Private DB 사용에 유료 프로그램 필요 |
| CloudKit 변경 실시간 감지 | Push Notifications | CKSubscription 원격 알림 수신에 필요 |
| App Store 배포 | Apple Developer Program | 유료 앱($4.99) 판매를 위해 필수 |

> **참고:** 유료 계정 없이도 앱의 핵심 루프(녹음 → 전사 → 기록 → 내보내기)는 전부 동작한다. 키보드 확장과 iCloud 동기화는 유료 전환 후 entitlements 파일에 App Groups/iCloud 항목을 추가하면 된다.

---

## 10. 부록

### 경쟁 앱 분석

| 앱 | 가격 모델 | 온디바이스 | iPhone large-v3 | Mac 서버 | 커스텀 키보드 | Dynamic Island | 문제점 |
|---|---|---|---|---|---|---|---|
| 클로바 노트 | 무료 (600분 제한) | X | X | X | X | X | 사용량 제한, 클라우드 의존 |
| ChatGPT 음성 인식 | 구독 | X | X | X | X | X | 앱 전환 과정 불편 |
| Groq API + Shortcuts | API 종량 | X | X | X | X | X | 화면 가림 |
| Apple 기본 받아쓰기 / SpeechAnalyzer | 무료 | O | X | X | O (시스템) | X | 한국어 전사 품질 매우 낮음 (직접 테스트 확인) |
| Superwhisper | 구독 $5.41/월 | O | O (Pro SDK) | X | O | O | 구독제 |
| Whisper Notes | 1회 $4.99 | O | X (축소 모델) | X | X | X | 키보드 없음, DI 없음 |
| **Writ** | **1회 결제** | **O** | **O (947MB)** | **v2 예정** | **O** | **O** | **전 모델 개방, 기기별 안내** |

### Whisper 모델 사양 참조 (Writ 제공 모델)

| 모델 | 파라미터 | 인코더/디코더 | CoreML 압축 크기 | 배포 | 비고 |
|---|---|---|---|---|---|
| tiny | 39M | 4층/4층 | ~75 MB | 번들 | 구형 기기(A12~A13) 전용 |
| base | 74M | 6층/6층 | ~142 MB | 번들 | 빠른 속도, 일상 사용 |
| small | 244M | 12층/12층 | ~466 MB | 번들 | 속도/정확도 균형. 대부분 사용자 기본 |
| large-v3 | 1.55B | 32층/32층 | ~947 MB | 다운로드 | 최고 정확도. 느림 |
| large-v3 turbo | 809M | 32층/4층 | ~954 MB | 다운로드 | large-v2급 정확도 + 빠른 속도. 실용적 고품질 |

> 모든 모델은 다국어 버전(99개 언어 지원)만 제공. 영어 전용(.en) 모델은 미포함.
> large 계열은 CoreML QLoRA mixed-bit quantization 압축 버전 사용. full-size(2.9GB) 는 미제공.
> 제외 모델 상세 사유는 섹션 3 "제외한 모델 및 사유" 참조.
