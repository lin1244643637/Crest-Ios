import SwiftUI

/// 使用 Canvas 绘制持续漂移的黑白弥散光带登录背景。
struct AnimatedLoginBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date()
    @State private var seed = Int.random(in: 0..<1_000_000)

    var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 60,
            paused: reduceMotion || scenePhase != .active
        )) { timeline in
            let time = reduceMotion ? 0 : max(0, timeline.date.timeIntervalSince(startedAt))

            Canvas(opaque: true, rendersAsynchronously: true) { context, size in
                let bounds = Path(CGRect(origin: .zero, size: size))
                context.fill(bounds, with: .color(.black))

                for index in 0..<4 {
                    drawRibbon(index, time: time, context: context, size: size)
                }

                context.fill(
                    bounds,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .black.opacity(0.24), location: 0),
                            .init(color: .clear, location: 0.2),
                            .init(color: .clear, location: 0.48),
                            .init(color: .black.opacity(0.66), location: 1)
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 叠加不同宽度和模糊程度的曲线，形成一条有层次的光带。
    private func drawRibbon(_ index: Int, time: Double, context: GraphicsContext, size: CGSize) {
        let channel = index * 100
        let lane: CGFloat = [-0.08, 0.62, 1.02, 0.28][index]
        let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        let shortSide = min(size.width, size.height)
        let widths: [CGFloat] = [0.56, 0.38, 0.29, 0.19]
        let width = shortSide * widths[index] * (1 + drift(time, channel: channel + 8) * 0.18)

        let p0 = CGPoint(
            x: size.width * (lane + drift(time, channel: channel) * 0.44),
            y: size.height * -0.35
        )
        let p1 = CGPoint(
            x: size.width * (lane + direction * 0.65 + drift(time, channel: channel + 2) * 0.75),
            y: size.height * (0.18 + drift(time, channel: channel + 3) * 0.16)
        )
        let p2 = CGPoint(
            x: size.width * (1 - lane - direction * 0.65 + drift(time, channel: channel + 4) * 0.75),
            y: size.height * (0.72 + drift(time, channel: channel + 5) * 0.20)
        )
        let p3 = CGPoint(
            x: size.width * (1 - lane + drift(time, channel: channel + 1) * 0.55),
            y: size.height * 1.35
        )

        var samples: [(center: CGPoint, normal: CGPoint, width: CGFloat, bias: CGFloat, scatter: CGFloat)] = []
        for step in 0...80 {
            let t = CGFloat(step) / 80
            let u = 1 - t
            let along = Double(t) + time * 0.012
            let bend = variation(along * 4.3, time: time, channel: channel + 12)
            let detail = variation(along * 10.7, time: time, channel: channel + 25)
            let breadth = variation(along * 5.1, time: time, channel: channel + 40)
            let bias = variation(along * 7.4, time: time, channel: channel + 55)
            let scatter = variation(along * 3.8, time: time, channel: channel + 70)
            let dx = 3 * u * u * (p1.x - p0.x) + 6 * u * t * (p2.x - p1.x) + 3 * t * t * (p3.x - p2.x)
            let dy = 3 * u * u * (p1.y - p0.y) + 6 * u * t * (p2.y - p1.y) + 3 * t * t * (p3.y - p2.y)
            let length = max(hypot(dx, dy), 1)
            let normal = CGPoint(x: dy / length, y: -dx / length)
            let displacement = shortSide * (bend * 0.23 + detail * 0.045)
            let center = CGPoint(
                x: u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x + normal.x * displacement,
                y: u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y + normal.y * displacement
            )
            let localWidth = width * (0.16 + pow((breadth + 1) * 0.5, 1.6) * 1.4)
            samples.append((center, normal, localWidth, bias, scatter))
        }

        // Independent edges and a displaced outer contour let light feather into shadow.
        func contour(scale: CGFloat, dispersion: CGFloat, offset: CGFloat = 0) -> Path {
            var path = Path()
            for side in [CGFloat(1), -1] {
                for step in samples.indices {
                    let sample = samples[side > 0 ? step : samples.count - 1 - step]
                    let spread = shortSide * dispersion
                    let radius = sample.width * scale * (0.5 + side * sample.bias * 0.24)
                        + spread * (0.65 + sample.scatter * side * 0.35)
                    let distance = side * radius + sample.width * offset + spread * sample.scatter
                    let point = CGPoint(
                        x: sample.center.x + sample.normal.x * distance,
                        y: sample.center.y + sample.normal.y * distance
                    )
                    if side > 0 && step == 0 { path.move(to: point) }
                    else { path.addLine(to: point) }
                }
            }
            path.closeSubpath()
            return path
        }

        let lightPosition = drift(time, channel: channel + 6)
        let intensity = 0.72 + Double(drift(time, channel: channel + 7)) * 0.16
        let start = CGPoint(x: size.width * (-0.2 + lightPosition * 0.35), y: size.height * -0.1)
        let end = CGPoint(x: size.width * (1.1 + lightPosition * 0.25), y: size.height * 1.05)
        let surface = Gradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .white.opacity(0.12), location: 0.18),
            .init(color: .white.opacity(intensity * 0.64), location: 0.35),
            .init(color: .white.opacity(intensity), location: 0.48),
            .init(color: Color(white: 0.12).opacity(0.88), location: 0.65),
            .init(color: .white.opacity(0.22), location: 0.83),
            .init(color: .clear, location: 1)
        ])

        context.drawLayer { glow in
            glow.blendMode = .screen
            glow.opacity = 0.62
            glow.addFilter(.blur(radius: shortSide * 0.14))
            glow.fill(
                contour(scale: 1.5, dispersion: 0.20),
                with: .linearGradient(surface, startPoint: start, endPoint: end)
            )
        }

        context.drawLayer { ribbon in
            ribbon.addFilter(.blur(radius: shortSide * (index == 0 ? 0.045 : 0.028)))
            ribbon.fill(
                contour(scale: 1, dispersion: 0),
                with: .linearGradient(surface, startPoint: start, endPoint: end)
            )
        }

        context.drawLayer { reflection in
            reflection.blendMode = .screen
            reflection.addFilter(.blur(radius: shortSide * 0.035))
            reflection.fill(
                contour(scale: 0.24, dispersion: 0.025, offset: -0.20),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0.1),
                        .init(color: .white.opacity(intensity * 0.50), location: 0.43),
                        .init(color: .white.opacity(intensity * 0.72), location: 0.52),
                        .init(color: .clear, location: 0.74)
                    ]),
                    startPoint: start,
                    endPoint: end
                )
            )
        }
    }

    private func variation(_ position: Double, time: Double, channel: Int) -> CGFloat {
        let step = Int(floor(position))
        let fraction = position - floor(position)
        let eased = CGFloat(fraction * fraction * (3 - 2 * fraction))
        let from = drift(time, channel: channel + step)
        let to = drift(time, channel: channel + step + 1)
        return from + (to - from) * eased
    }

    // Independent schedules and quintic interpolation keep random targets smooth.
    private func drift(_ time: Double, channel: Int) -> CGFloat {
        let position = time / (9 + Double(channel % 7) * 1.3) + Double(channel) * 0.37
        let step = Int(floor(position))
        let fraction = position - floor(position)
        let eased = fraction * fraction * fraction * (fraction * (fraction * 6 - 15) + 10)
        let from = randomUnit(step: step, channel: channel)
        let to = randomUnit(step: step + 1, channel: channel)
        return CGFloat((from + (to - from) * eased) * 2 - 1)
    }

    /// 根据种子产生稳定的伪随机值，让动画连续且每次启动略有不同。
    private func randomUnit(step: Int, channel: Int) -> Double {
        let value = sin(Double(seed + step * 1013 + channel * 7919) * 12.9898) * 43758.5453
        return value - floor(value)
    }
}
