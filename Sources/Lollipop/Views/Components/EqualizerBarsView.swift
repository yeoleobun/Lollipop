import AppKit
import QuartzCore
import SwiftUI

/// Animated 3-bar Apple Music-style equalizer indicator for the currently playing track row.
/// Uses native `CALayer`s with `CABasicAnimation` on `transform.scale.y` so CoreAnimation
/// runs entirely on the WindowServer/GPU with zero SwiftUI layout or main-thread CPU cost.
struct EqualizerBarsView: View {
    let isPlaying: Bool

    var body: some View {
        EqualizerBarsRepresentable(isPlaying: isPlaying)
            .frame(width: 14, height: 15)
    }
}

private struct EqualizerBarsRepresentable: NSViewRepresentable {
    let isPlaying: Bool

    func makeNSView(context: Context) -> EqualizerBarsNSView {
        let view = EqualizerBarsNSView()
        view.setPlaying(isPlaying, animated: false)
        return view
    }

    func updateNSView(_ nsView: EqualizerBarsNSView, context: Context) {
        nsView.setPlaying(isPlaying, animated: true)
    }
}

private final class EqualizerBarsNSView: NSView {
    private struct BarSpec {
        let minH: CGFloat
        let maxH: CGFloat
        let duration: CFTimeInterval
        let timeOffset: CFTimeInterval
    }

    private static let specs: [BarSpec] = [
        BarSpec(minH: 4, maxH: 13, duration: 0.45, timeOffset: 0.0),
        BarSpec(minH: 6, maxH: 15, duration: 0.35, timeOffset: 0.14),
        BarSpec(minH: 3, maxH: 11, duration: 0.52, timeOffset: 0.27),
    ]

    private static let animationKey = "lollipop.equalizer.scaleY"
    private static let barWidth: CGFloat = 3
    private static let barSpacing: CGFloat = 2
    private static let pausedHeight: CGFloat = 4

    private var barLayers: [CALayer] = []
    private var desiredPlaying = false
    private var isAnimating = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        setupBars()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 14, height: 15)
    }

    private func setupBars() {
        let rootLayer = CALayer()
        rootLayer.masksToBounds = false
        self.layer = rootLayer

        let accentCGColor = NSColor(AppColors.accent).cgColor
        let totalWidth = CGFloat(Self.specs.count) * Self.barWidth
            + CGFloat(Self.specs.count - 1) * Self.barSpacing
        let startX = (14 - totalWidth) / 2

        for (index, spec) in Self.specs.enumerated() {
            let bar = CALayer()
            bar.backgroundColor = accentCGColor
            bar.cornerRadius = 1
            bar.bounds = CGRect(x: 0, y: 0, width: Self.barWidth, height: spec.maxH)
            bar.anchorPoint = CGPoint(x: 0.5, y: 0)
            let centerX = startX + CGFloat(index) * (Self.barWidth + Self.barSpacing) + Self.barWidth / 2
            bar.position = CGPoint(x: centerX, y: 0)
            bar.transform = CATransform3DMakeScale(1, Self.pausedHeight / spec.maxH, 1)
            rootLayer.addSublayer(bar)
            barLayers.append(bar)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        for bar in barLayers {
            bar.contentsScale = scale
        }
        syncAnimationState(animated: false)
    }

    func setPlaying(_ playing: Bool, animated: Bool) {
        desiredPlaying = playing
        syncAnimationState(animated: animated)
    }

    private func syncAnimationState(animated: Bool) {
        let shouldAnimate = desiredPlaying && window != nil
        guard shouldAnimate != isAnimating else { return }
        isAnimating = shouldAnimate

        if shouldAnimate {
            for (bar, spec) in zip(barLayers, Self.specs) {
                let minScale = max(0.2, spec.minH / spec.maxH)
                bar.transform = CATransform3DIdentity
                let anim = CABasicAnimation(keyPath: "transform.scale.y")
                anim.fromValue = minScale
                anim.toValue = 1.0
                anim.duration = spec.duration
                anim.timeOffset = spec.timeOffset
                anim.autoreverses = true
                anim.repeatCount = .infinity
                anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                anim.isRemovedOnCompletion = false
                bar.add(anim, forKey: Self.animationKey)
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(!animated)
            CATransaction.setAnimationDuration(0.18)
            for (bar, spec) in zip(barLayers, Self.specs) {
                bar.removeAnimation(forKey: Self.animationKey)
                bar.transform = CATransform3DMakeScale(1, Self.pausedHeight / spec.maxH, 1)
            }
            CATransaction.commit()
        }
    }
}
