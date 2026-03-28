---
title: "SwiftUI Menu의 _UIReparentingView 경고 — 무시해도 안전"
date: 2026-03-27
tags: [til, swift, ui]
severity: warning
---

# SwiftUI Menu의 _UIReparentingView 경고 — 무시해도 안전

## 증상

```
Adding '_UIReparentingView' as a subview of UIHostingController.view is not supported
and may result in a broken view hierarchy. Add your view above UIHostingController.view
in a common superview or insert it into your SwiftUI content in a UIViewRepresentable instead.
```

녹음 탭에서 언어 설정 `Menu`를 탭할 때 콘솔에 출력됨.

## 원인

SwiftUI `Menu`가 내부적으로 UIKit의 `UIMenu`/`UIContextMenuInteraction`을 사용하여 팝업을 표시하는데, 이 과정에서 `_UIReparentingView`를 `UIHostingController.view`의 서브뷰로 삽입하려 하면서 발생하는 프레임워크 내부 경고. 특히 `TabView → NavigationStack → ZStack → Menu` 같은 깊은 뷰 계층에서 잘 발생한다.

## 해결

**무시.** Apple SwiftUI 프레임워크의 내부 구현 이슈로, 앱 코드의 버그가 아니다. 실제 UI 동작(메뉴 열기, 선택)에는 영향 없음. 향후 SwiftUI 업데이트에서 자연 해결될 가능성이 높다.
