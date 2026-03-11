import SwiftUI

// MARK: - Colors

enum WritColor {
    // MARK: Backgrounds
    static let background = Color(light: .hex(0xF2F2F7), dark: .hex(0x000000))
    static let cardBackground = Color(light: .hex(0xFFFFFF), dark: .hex(0x1C1C1E))
    static let recordingBackground = Color(light: .hex(0x000000), dark: .hex(0x000000))

    // MARK: Accents
    static let accent = Color(light: .hex(0x007AFF), dark: .hex(0x0A84FF))
    static let recordingRed = Color(light: .hex(0xFF3B30), dark: .hex(0xFF453A))
    static let success = Color(light: .hex(0x34C759), dark: .hex(0x30D158))
    static let warning = Color(light: .hex(0xFF9500), dark: .hex(0xFF9F0A))

    // MARK: Text
    static let primaryText = Color(light: .hex(0x000000), dark: .hex(0xFFFFFF))
    static let secondaryText = Color(.hex(0x8E8E93))
    static let tertiaryText = Color(light: .hex(0x6C6C70), dark: .hex(0xAEAEB2))

    // MARK: UI Elements
    static let divider = Color(light: .black.opacity(0.08), dark: .white.opacity(0.08))
    static let searchBarBackground = Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.12)
    static let chipBackground = Color(.hex(0xE5E5EA))
    static let accentLight = Color(light: .hex(0x007AFF).opacity(0.12), dark: .hex(0x0A84FF).opacity(0.15))

    // MARK: Status
    static let statusCompleteBackground = Color(.hex(0xE8F5E9))
    static let statusCompleteText = Color(.hex(0x2E7D32))
    static let statusProcessingBackground = Color(.hex(0xFFF3E0))
    static let statusProcessingText = Color(.hex(0xE65100))
    static let statusWaitingBackground = Color(.hex(0xF3F4F6))
    static let statusWaitingText = Color(.hex(0x6C6C70))

    // MARK: Waveform
    static let waveformPlayed = Color(light: .hex(0x007AFF), dark: .hex(0x0A84FF))
    static let waveformUnplayed = Color(.hex(0xD1D1D6))
}

// MARK: - Spacing

enum WritSpacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Corner Radius

enum WritRadius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 8
    static let card: CGFloat = 12
    static let sheet: CGFloat = 14
    static let chip: CGFloat = 16
    static let pill: CGFloat = 20
    static let button: CGFloat = 10
}

// MARK: - Typography

enum WritFont {
    static let largeTitle: Font = .system(size: 34, weight: .bold)
    static let title: Font = .system(size: 22, weight: .semibold)
    static let body: Font = .system(size: 17)
    static let transcript: Font = .system(size: 16)
    static let callout: Font = .system(size: 14)
    static let caption: Font = .system(size: 13)
    static let smallCaption: Font = .system(size: 11, weight: .medium)
    static let tabLabel: Font = .system(size: 10, weight: .medium)
    static let timer: Font = .system(size: 56, weight: .ultraLight, design: .default)
    static let timerWatch: Font = .system(size: 32, weight: .light, design: .default)
    static let timestamp: Font = .system(size: 12, weight: .medium).monospacedDigit()
}

// MARK: - Dimensions

enum WritDimension {
    // Record Button
    static let recordButtonOuter: CGFloat = 80
    static let recordButtonInner: CGFloat = 60
    static let recordButtonBorder: CGFloat = 4
    static let recordButtonStopSize: CGFloat = 30
    static let recordButtonStopRadius: CGFloat = 8

    // Watch Record Button
    static let watchRecordButtonOuter: CGFloat = 72
    static let watchRecordButtonInner: CGFloat = 54
    static let watchRecordButtonBorder: CGFloat = 3

    // Icons
    static let statusIconSize: CGFloat = 44
    static let statusIconRadius: CGFloat = 10
    static let statusDotSize: CGFloat = 8
    static let modelDotSize: CGFloat = 6
    static let actionIconSize: CGFloat = 36
    static let exportIconSize: CGFloat = 28

    // Keyboard
    static let keyboardMicButton: CGFloat = 64
    static let keyboardStopButton: CGFloat = 48
    static let keyboardHeight: CGFloat = 260

    // Waveform
    static let waveformBarWidth: CGFloat = 3
    static let waveformBarRadius: CGFloat = 2
    static let waveformSeekHeight: CGFloat = 48
    static let playButtonSize: CGFloat = 48

    // Storage Bar
    static let storageBarHeight: CGFloat = 6

    // Progress Bar
    static let progressBarHeight: CGFloat = 3

    // Player
    static let seekMarkerWidth: CGFloat = 2
    static let seekMarkerDotSize: CGFloat = 8
}

// MARK: - Animation

enum WritAnimation {
    static let backgroundTransition: Animation = .easeInOut(duration: 0.3)
    static let buttonMorph: Animation = .easeOut(duration: 0.2)
    static let waveform: Animation = .easeInOut(duration: 0.7)
    static let pulse: Animation = .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    static let toast: Animation = .easeInOut(duration: 0.3)
}

// MARK: - Color Helpers

private extension Color {
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
        #endif
    }

    init(_ resolved: Color) {
        self = resolved
    }
}

private extension Color {
    static func hex(_ value: UInt) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
