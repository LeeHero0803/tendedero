import SwiftUI

/// One photo with its clothespin. All the charm lives here: it drops onto
/// the line, swings, sways with the breeze and falls when you pull it off.
struct PeggedView: View {
    let item: Pegged
    @ObservedObject var line: Line

    @State private var swing: Double = 0
    @State private var arrived = false
    @State private var hovering = false

    private var copied: Bool { line.copiedID == item.id }
    private var dragging: Bool { line.draggingID == item.id }
    private var pressed: Bool { line.pressedID == item.id }

    var body: some View {
        VStack(spacing: -12) {
            Clothespin(kind: item.clipKind)
                .zIndex(1)
            card
        }
        .rotationEffect(.degrees(swing + item.tilt), anchor: .top)
        .offset(y: arrived ? 0 : -46)
        // The fall itself is drawn over the whole screen by CaptureFlight, so
        // the card here just steps aside at once.
        .opacity(item.falling || item.flying ? 0 : (arrived ? 1 : 0))
        .transaction { t in if item.falling { t.animation = nil } }
        .animation(.easeOut(duration: 0.16), value: item.flying)
        .onAppear(perform: arrive)
        .onChange(of: item.flying) { was, now in if was && !now { land() } }
        .onChange(of: line.gust) { _, _ in breeze() }
        .onChange(of: copied) { _, isCopied in if isCopied { nudge(3) } }
    }

    /// The photo fits inside the card area keeping its proportions, so the
    /// white border hugs it whether the screenshot is wide or tall.
    static func photoSize(for size: CGSize) -> CGSize {
        let maxW = Layout.cardWidth - 14, maxH = Layout.photoMaxHeight
        guard size.width > 0, size.height > 0 else { return CGSize(width: maxW, height: maxH) }
        let scale = min(maxW / size.width, maxH / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    /// The card around the photo: the photo plus the glass inset.
    static func cardSize(for size: CGSize) -> CGSize {
        let p = photoSize(for: size)
        return CGSize(width: p.width + Frame.inset * 2, height: p.height + Frame.inset * 2)
    }

    /// Distance from the top of the hanging view (the clip) to the card.
    static let cardOffsetBelowTop: CGFloat = 26 - 12

    private var photoSize: CGSize { Self.photoSize(for: item.thumb.size) }

    private var card: some View {
        Image(nsImage: item.thumb)
            .resizable()
            .interpolation(.high)
            .frame(width: photoSize.width, height: photoSize.height)
            // Concentric corners: the photo's radius is the frame's minus the
            // inset, the way macOS rounds nested shapes.
            .clipShape(RoundedRectangle(cornerRadius: Frame.radius - Frame.inset, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Frame.radius - Frame.inset, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .overlay {
                // A recording says so with a play button over its first frame.
                if item.isRecording {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 28)
                        .glassFrame(circle: true)
                        .allowsHitTesting(false)
                }
            }
            .padding(Frame.inset)
            .glassFrame(cornerRadius: Frame.radius)
            .shadow(color: .black.opacity(hovering ? 0.26 : 0.18), radius: hovering ? 14 : 10, y: hovering ? 8 : 5)
            // Holding presses the photo in slowly, so a long press feels like
            // it is building up to something.
            .scaleEffect(pressed ? 0.95 : (hovering ? 1.035 : 1), anchor: .top)
            .animation(pressed ? .easeInOut(duration: 0.45) : .spring(response: 0.3, dampingFraction: 0.6), value: pressed)
            .opacity(dragging ? 0.45 : 1)
            .overlay(alignment: .topLeading) {
                // Drawn here, clicked through GrabView, which sits on top. A
                // cross sends a file in Tendedero's folder to the Trash; for a
                // file anywhere else it only hides it from the line.
                Image(systemName: line.isInInbox(item.id) ? "xmark" : "eye.slash")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 20, height: 20)
                    .glassFrame(circle: true)
                    .padding(3)
                    .opacity(hovering && !dragging ? 1 : 0)
                    .scaleEffect(hovering ? 1 : 0.6)
                    .allowsHitTesting(false)
            }
            .overlay(GrabArea(item: item, line: line))
            .overlay(alignment: .bottom) {
                if copied {
                    Label(L("Copied"), systemImage: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .glassFrame(capsule: true)
                        .offset(y: 16)
                        .transition(.opacity.combined(with: .offset(y: -4)))
                }
            }
            .animation(.easeOut(duration: 0.18), value: hovering)
            .animation(.easeOut(duration: 0.2), value: copied)
            .onHover { hovering = $0 }
            .background(
                GeometryReader { g in
                    Color.clear.preference(key: HitRectsKey.self,
                                           value: item.falling ? [:] : [item.id: g.frame(in: .global)])
                }
            )
    }

    private func arrive() {
        // A capture that flew in is already in place; the flight did the arriving.
        if item.flying {
            arrived = true
            return
        }
        swing = 16
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { arrived = true }
        withAnimation(.interpolatingSpring(stiffness: 46, damping: 2.6)) { swing = 0 }
    }

    /// Landing after the flight: no jump, just a small sway from rest.
    private func land() {
        nudge(2.2)
    }

    private func breeze() {
        let delay = Double.random(in: 0...0.35)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            nudge(Double.random(in: 1.6...3.4))
        }
    }

    private func nudge(_ degrees: Double) {
        withAnimation(.easeOut(duration: 0.3)) { swing = degrees }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.interpolatingSpring(stiffness: 38, damping: 2.4)) { swing = 0 }
        }
    }
}

enum Frame {
    static let radius: CGFloat = 16
    static let inset: CGFloat = 4
}

extension View {
    /// A crisp glass: the system's blurred material with a thin specular
    /// edge, lit from above. No refraction, so the background stays sharp
    /// around the frame instead of bending like gel.
    func glassFrame(cornerRadius: CGFloat = 0, circle: Bool = false, capsule: Bool = false) -> some View {
        let shape: AnyShape = circle ? AnyShape(Circle())
            : capsule ? AnyShape(Capsule())
            : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        return background(.ultraThinMaterial, in: shape)
            .overlay(
                shape.stroke(
                    LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.12)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.75)
            )
            .overlay(shape.stroke(Color.black.opacity(0.10), lineWidth: 0.5).padding(-0.5))
    }
}

/// Distinct stationery silhouettes, all inside the original 26-point height
/// so card attachment, hit testing and flight geometry remain aligned.
struct Clothespin: View {
    enum Kind { case image, text, file }
    var kind: Kind = .image

    private var metal: LinearGradient {
        let colors: [Color]
        switch kind {
        case .image:
            colors = [Color(white: 0.70), Color(white: 0.93), Color(white: 0.82), Color(white: 0.62)]
        case .text:
            colors = [Color(red: 0.70, green: 0.69, blue: 0.66),
                      Color(red: 0.94, green: 0.93, blue: 0.90),
                      Color(red: 0.82, green: 0.80, blue: 0.77),
                      Color(red: 0.63, green: 0.62, blue: 0.59)]
        case .file:
            colors = [Color(red: 0.67, green: 0.70, blue: 0.73),
                      Color(red: 0.91, green: 0.94, blue: 0.96),
                      Color(red: 0.78, green: 0.82, blue: 0.85),
                      Color(red: 0.59, green: 0.63, blue: 0.66)]
        }
        return LinearGradient(stops: [
            .init(color: colors[0], location: 0),
            .init(color: colors[1], location: 0.35),
            .init(color: colors[2], location: 0.65),
            .init(color: colors[3], location: 1),
        ], startPoint: .leading, endPoint: .trailing)
    }

    private let edge = LinearGradient(colors: [.white.opacity(0.9), .black.opacity(0.25)],
                                      startPoint: .top, endPoint: .bottom)

    var body: some View {
        Group {
            switch kind {
            case .image: photoPin
            case .text: binderClip
            case .file: bulldogClip
            }
        }
        .frame(width: 34, height: 26)
        .shadow(color: .black.opacity(0.30), radius: 2, y: 1.5)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var photoPin: some View {
        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
            .fill(metal)
            .frame(width: 9, height: 26)
            .overlay(RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .stroke(edge, lineWidth: 0.6))
            .overlay(alignment: .top) {
                Capsule().fill(Color.black.opacity(0.32))
                    .frame(width: 5, height: 1.4).padding(.top, 8.5)
            }
    }

    /// A small folded body and one quiet wire loop suggest a binder clip.
    private var binderClip: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(metal)
                .frame(width: 16, height: 9)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(edge, lineWidth: 0.5))
                .offset(x: 9, y: 16)
            Path { p in
                p.move(to: CGPoint(x: 13, y: 18))
                p.addLine(to: CGPoint(x: 12.5, y: 6))
                p.addQuadCurve(to: CGPoint(x: 14.5, y: 3), control: CGPoint(x: 12, y: 3))
                p.addLine(to: CGPoint(x: 19.5, y: 3))
                p.addQuadCurve(to: CGPoint(x: 21.5, y: 6), control: CGPoint(x: 22, y: 3))
                p.addLine(to: CGPoint(x: 21, y: 18))
            }
            .stroke(metal, style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 34, height: 26)
    }

    /// A narrow arched plate with a single eye; no extra chrome or embossing.
    private var bulldogClip: some View {
        ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: CGPoint(x: 7, y: 23))
                p.addLine(to: CGPoint(x: 7, y: 17))
                p.addQuadCurve(to: CGPoint(x: 12, y: 14), control: CGPoint(x: 7, y: 14))
                p.addCurve(to: CGPoint(x: 22, y: 14), control1: CGPoint(x: 12, y: 4), control2: CGPoint(x: 22, y: 4))
                p.addQuadCurve(to: CGPoint(x: 27, y: 17), control: CGPoint(x: 27, y: 14))
                p.addLine(to: CGPoint(x: 27, y: 23))
                p.closeSubpath()
            }
            .fill(metal)
            Circle().fill(Color.black.opacity(0.35))
                .frame(width: 2.5, height: 2.5).offset(x: 15.75, y: 10)
            Capsule().fill(metal).frame(width: 20, height: 2).offset(x: 7, y: 23)
        }
        .frame(width: 34, height: 26)
    }
}

extension Pegged {
    /// One source of truth for the live card and its flight/removal animation.
    var clipKind: Clothespin.Kind { isTextNote ? .text : isFileReference ? .file : .image }
}
