import SwiftUI

/// 对下层真实内容进行模糊，不额外叠加 SwiftUI 材质底色。
struct BackdropBlur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemUltraThinMaterial

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {}
}
