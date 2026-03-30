---
title: "Qwen3-ASR 백그라운드 전사 — MLX Metal 의존성 제거"
date: 2026-03-28
tags: [swift, coreml, metal, mlx, dependency]
severity: error
---

# Qwen3-ASR 백그라운드 전사 — MLX Metal 의존성 제거

## 상황

다이나믹 아일랜드에서 녹음 정지 시 백그라운드 전사가 실행되는데, Qwen3-ASR 엔진에서 Metal GPU 크래시가 발생했다. ANE(Neural Engine)로 전환하면 해결될 줄 알았는데, 세 단계에 걸친 문제가 연쇄적으로 나타났다.

## 에러 내용

```
IOGPUMetalError: Insufficient Permission (to submit GPU work from background)
(00000006:kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted)

[METAL] Command buffer execution failed: Insufficient Permission
(to submit GPU work from background)
```

## 원인 분석

### 1차 시도: CoreMLASRModel + `.cpuAndNeuralEngine`

qwen3-asr-swift 라이브러리의 `CoreMLASRModel`을 사용하고 `computeUnits: .cpuAndNeuralEngine`으로 설정. 하지만 **여전히 크래시**. 원인: `CoreMLASRModel`이 `import MLX`를 하고 내부에서 `MLXArray`로 데이터를 주고받음.

```swift
// CoreMLASRModel.swift (라이브러리)
import MLX  // ← 이것이 문제

// CoreMLEncoder.encode() 내부
let melData: [Float] = melFeatures.asArray(Float.self)  // ← Metal 트리거
```

MLX의 `default_device()`가 iOS에서 항상 GPU를 반환하므로, `.asArray()` → `eval()` → `gpu::eval()` → Metal command buffer 제출.

### 2차 시도: ANE 컴파일 실패

iPhone 14 Pro (A16)에서 디코더의 ANE 컴파일 실패:

```
MILCompilerForANE error: failed to compile ANE model using ANEF.
Failure translating MIL->EIR network: std::bad_cast
```

원인: `CoreMLTextDecoder`가 `MLState`(KV 캐시)를 사용하는데, A16 이하 ANE에서 이 연산을 지원하지 않음. ANE 우선 → CPU 폴백 전략으로 해결.

### 3차: 전사 결과 빈 문자열

mel spectrogram 추출 시 `vDSP_mtrans` 파라미터가 원본과 달랐음:

```diff
 // 원본 (WhisperFeatureExtractor.extractFeatures)
 vDSP_mtrans(filterbank, 1, &filterbankT, 1, vDSP_Length(nBins), vDSP_Length(nMels))

 // 잘못된 코드
-vDSP_mtrans(melFilterbank, 1, &filterbankT, 1, vDSP_Length(nMels), vDSP_Length(nBins))
+vDSP_mtrans(melFilterbank, 1, &filterbankT, 1, vDSP_Length(nBins), vDSP_Length(nMels))
```

## 해결 과정

### 최종 해결: GPU-free 독립 래퍼 구현

`Qwen3CoreMLInference` 클래스를 Writ 프로젝트 내에 직접 구현. 라이브러리의 `CoreMLASRModel`을 사용하지 않고, MLX를 완전히 배제:

```swift
// Qwen3CoreMLInference.swift — import MLX 없음
import CoreML
import Foundation
import Accelerate
import Qwen3ASR    // CoreMLTextDecoder, Qwen3Tokenizer 등 재사용
import AudioCommon // AudioSampleLoader 재사용
```

구성:
- **Mel 추출**: Accelerate(CPU) 기반 직접 구현 — `vDSP_fft`, `vDSP_mmul`, `vvlog10f`
- **인코더**: `MLModel` 직접 로드 + `prediction()` 호출 (라이브러리 CoreMLASREncoder의 model이 private이라)
- **디코더**: 라이브러리 `CoreMLTextDecoder`의 public API(`embed/decoderStep/argmax`) 재사용
- **오디오 임베딩 슬라이스**: `MLMultiArray` 포인터 직접 복사

추가 주의점:
- **Hann 윈도우**: `vDSP_hann_window(NORM)`은 대칭 윈도우 → 원본은 주기적 윈도우 사용
- **Mel filterbank**: HTK 공식이 아닌 Slaney piecewise 공식 사용 필요

## 배운 점

MLX 프레임워크는 `MLXArray` 생성만으로는 Metal을 호출하지 않지만(lazy evaluation), `.asArray()` 호출 시 `eval()` → `gpu::eval()` 경로를 타면서 Metal command buffer를 제출한다. CoreML 모델이 ANE에서 동작하더라도, 데이터 브릿지에 MLX를 사용하면 백그라운드에서 크래시한다. GPU-free를 보장하려면 `import MLX` 자체를 제거해야 한다.
