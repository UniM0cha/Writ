# Qwen3-ASR CoreML 통합 계획

## 현재 상태 요약

### Writ 앱 아키텍처
- **SwiftUI 멀티플랫폼 앱** (iPhone/iPad/Mac/Apple Watch)
- **WhisperKit** 기반 온디바이스 음성→텍스트 변환
- **TranscriptionEngine 프로토콜**이 이미 추상화되어 있음 → 새 엔진 교체 용이

### 핵심 파일
| 파일 | 역할 |
|------|------|
| `Writ/Core/Protocols/TranscriptionEngine.swift` | 엔진 추상화 프로토콜 |
| `Writ/Core/Services/WhisperKitEngine.swift` | WhisperKit 구현체 |
| `Writ/Core/Services/ModelManager.swift` | 모델 다운로드/로딩/디바이스 호환성 |
| `Writ/Core/Models/WhisperModel.swift` | 모델 메타데이터 (variant, state, size) |
| `Writ/App/AppState.swift` | 앱 전역 상태, 전사 큐 관리 |

### TranscriptionEngine 프로토콜 (현재)
```swift
protocol TranscriptionEngine: Sendable {
    func transcribe(
        audioURL: URL,
        language: String?,
        progressCallback: (@Sendable (Float) -> Void)?
    ) async throws -> TranscriptionOutput

    func supportedModels() -> [WhisperModelVariant]
    func loadModel(_ model: WhisperModelVariant, progressCallback: (@Sendable (Float) -> Void)?) async throws
    func unloadModel() async
    var currentModel: WhisperModelVariant? { get }
}
```

**문제점:** `WhisperModelVariant`에 하드코딩 → 범용 모델 타입으로 리팩터링 필요

---

## 통합 계획

### Phase 1: CoreML 모델 변환 (Python, 로컬 Mac에서)

#### 환경 세팅
```bash
python3 -m venv qwen3-asr-env
source qwen3-asr-env/bin/activate
pip install coremltools transformers torch torchaudio
```

#### 변환 절차
1. **HuggingFace에서 Qwen3-ASR 모델 다운로드**
   ```python
   from transformers import AutoModelForSpeechSeq2Seq, AutoProcessor
   model = AutoModelForSpeechSeq2Seq.from_pretrained("Qwen/Qwen3-ASR")
   processor = AutoProcessor.from_pretrained("Qwen/Qwen3-ASR")
   ```

2. **Encoder 변환** (audio → mel spectrogram → encoder features)
   ```python
   import coremltools as ct
   # PyTorch encoder를 trace → CoreML 변환
   # 입력: mel spectrogram (Float16, [1, 80, T])
   # 출력: encoder hidden states
   ```

3. **Decoder 변환** (autoregressive, KV-cache 처리 필요)
   - 가장 까다로운 부분
   - coremltools의 StatefulModel 또는 수동 KV-cache 관리
   - 토큰 단위 반복 디코딩

4. **양자화**
   ```python
   # 8-bit 또는 4-bit (palettization)
   mlmodel = ct.models.MLModel("encoder.mlpackage")
   quantized = ct.compression_utils.affine_quantize_weights(mlmodel, mode="linear_symmetric", nbits=8)
   ```

5. **검증**
   ```python
   # 원본 PyTorch vs CoreML 출력 비교
   # WER (Word Error Rate) 측정
   ```

#### 리스크
- coremltools가 Qwen3-ASR의 모든 op을 지원하는지 불확실
- 특히 audio feature extractor, rotary position embedding 등
- 지원 안 되는 op → `ct.converters.mil.register_op`으로 커스텀 구현 필요

#### 예상 결과물
- `qwen3_asr_encoder.mlpackage` (또는 .mlmodelc)
- `qwen3_asr_decoder.mlpackage`
- `tokenizer.json` (토크나이저)
- 변환 스크립트 (`convert_qwen3_asr.py`)

---

### Phase 2: Swift 통합

#### 2-1. 모델 타입 리팩터링

현재 `WhisperModelVariant` enum을 범용화:

```swift
// 새로운 범용 모델 식별자
enum ASREngineType: String, Codable, Sendable {
    case whisperKit
    case qwen3ASR
}

// WhisperModelVariant는 그대로 유지 (WhisperKit 전용)
// Qwen3 전용 variant 추가
enum Qwen3ModelVariant: String, Codable, Sendable, CaseIterable {
    case qwen3ASR       // 기본 모델
    case qwen3ASRTurbo  // 경량화 버전 (있다면)
}

// TranscriptionEngine 프로토콜은 제네릭 또는 Any 타입으로 변경
protocol TranscriptionEngine: Sendable {
    associatedtype ModelVariant
    func transcribe(audioURL: URL, language: String?, progressCallback: (@Sendable (Float) -> Void)?) async throws -> TranscriptionOutput
    func supportedModels() -> [ModelVariant]
    func loadModel(_ model: ModelVariant, progressCallback: (@Sendable (Float) -> Void)?) async throws
    func unloadModel() async
}
```

#### 2-2. Qwen3ASREngine 구현

```swift
final class Qwen3ASREngine: TranscriptionEngine, @unchecked Sendable {
    typealias ModelVariant = Qwen3ModelVariant

    private var encoder: MLModel?
    private var decoder: MLModel?
    private var tokenizer: Qwen3Tokenizer?

    func transcribe(audioURL: URL, language: String?, progressCallback: (@Sendable (Float) -> Void)?) async throws -> TranscriptionOutput {
        // 1. Audio → Mel Spectrogram (vDSP/Accelerate)
        // 2. Mel → Encoder (CoreML)
        // 3. Encoder output → Decoder (CoreML, autoregressive loop)
        // 4. Token IDs → Text (Tokenizer)
        // 5. Segment timestamps 추출
    }
}
```

#### 2-3. 오디오 전처리 (Accelerate 프레임워크)
```swift
// Qwen3-ASR은 Whisper와 다른 mel spectrogram 파라미터를 사용할 수 있음
// - sample rate, n_fft, hop_length, n_mels 확인 필요
// - vDSP.FFT + Accelerate로 네이티브 구현
```

#### 2-4. 토크나이저
- `tokenizer.json`을 번들에 포함
- Swift에서 BPE 토크나이저 구현 (또는 swift-tokenizers 라이브러리 활용)

#### 2-5. 설정 UI 추가
```
설정 > 전사 엔진
├── WhisperKit (기본)
│   └── 모델 선택: tiny / base / small / large-v3 / large-v3 turbo
└── Qwen3-ASR
    └── 모델 다운로드 / 삭제
```

---

### Phase 3: 테스트 및 최적화

1. **정확도 비교**: 같은 오디오 → WhisperKit vs Qwen3-ASR WER 비교
2. **성능 벤치마크**: 전사 속도, 메모리 사용량, 배터리 소모
3. **디바이스 호환성**: A14 이상에서 CoreML 추론 검증
4. **Edge cases**: 긴 오디오, 다국어 혼합, 노이즈 환경

---

## 권장 작업 순서

```
[로컬 Mac에서]
1. Python 환경 세팅 + Qwen3-ASR 모델 다운로드
2. 모델 구조 분석 (어떤 op 사용하는지)
3. Encoder CoreML 변환 시도
4. Decoder CoreML 변환 시도
5. 변환 성공 시 → 양자화 + 검증
   변환 실패 시 → 실패 원인 분석, 대안 검토

[변환 성공 후]
6. TranscriptionEngine 프로토콜 리팩터링
7. Qwen3ASREngine 구현
8. 오디오 전처리 (mel spectrogram) 구현
9. 토크나이저 구현
10. 설정 UI 추가
11. 테스트 + 벤치마크
```

## 병행 전략 (권장)

**지금 당장**: WhisperKit으로 앱 완성 (v1 출시)
**병행 작업**: CoreML 변환 실험 (성공 여부 확인)
**변환 성공 시**: v1.1 또는 v2에서 Qwen3-ASR 엔진 추가

이렇게 하면 WhisperKit 앱은 정상 출시하면서, Qwen3-ASR은 리스크 없이 실험할 수 있음.

---

## 필요 환경

| 항목 | 요구사항 |
|------|---------|
| Mac | Apple Silicon (M1+) |
| RAM | 16GB+ (모델 변환 시) |
| 디스크 | 20GB+ (PyTorch + CoreML 모델) |
| Python | 3.10+ |
| Xcode | 15+ (CoreML 5) |
| coremltools | 8.0+ |
| transformers | 4.40+ |
| torch | 2.2+ |
