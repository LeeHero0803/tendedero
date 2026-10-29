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
            Clothespin(kind: item.isTextNote ? .text : item.isFileReference ? .file : .image)
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
            // Warm titanium, with enough neutral silver to avoid a gold accent.
            colors = [Color(red: 0.54, green: 0.51, blue: 0.46),
                      Color(red: 0.91, green: 0.88, blue: 0.82),
                      Color(red: 0.72, green: 0.68, blue: 0.61),
                      Color(red: 0.44, green: 0.42, blue: 0.38)]
        case .file:
            colors = [Color(red: 0.48, green: 0.55, blue: 0.61),
                      Color(red: 0.88, green: 0.93, blue: 0.97),
                      Color(red: 0.66, green: 0.74, blue: 0.81),
                      Color(red: 0.39, green: 0.46, blue: 0.53)]
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

    /// A tapered folded body and two unmistakable spring-wire handles.
    private var binderClip: some View {
        ZStack(alignment: .topLeading) {
            wireHandle(offset: 1.6)
                .stroke(Color.black.opacity(0.28), style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
            wireHandle(offset: 1.6)
                .stroke(metal, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            Path { p in
                p.move(to: CGPoint(x: 7, y: 14))
                p.addLine(to: CGPoint(x: 25, y: 14))
                p.addQuadCurve(to: CGPoint(x: 28, y: 24), control: CGPoint(x: 27, y: 17))
                p.addLine(to: CGPoint(x: 4, y: 24))
                p.addQuadCurve(to: CGPoint(x: 7, y: 14), control: CGPoint(x: 5, y: 17))
                p.closeSubpath()
            }
            .fill(metal)
            .overlay {
                Path { p in
                    p.move(to: CGPoint(x: 7, y: 14.5))
                    p.addLine(to: CGPoint(x: 25, y: 14.5))
                    p.move(to: CGPoint(x: 5, y: 23))
                    p.addLine(to: CGPoint(x: 27, y: 23))
                }.stroke(edge, lineWidth: 0.8)
            }
            wireHandle(offset: 0)
                .stroke(Color.black.opacity(0.35), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            wireHandle(offset: 0)
                .stroke(metal, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            Capsule().fill(Color.white.opacity(0.55))
                .frame(width: 7, height: 0.6).offset(x: 12.5, y: 2)
        }
        .frame(width: 32, height: 26)
    }

    private func wireHandle(offset: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 10, y: 18 + offset))
            p.addLine(to: CGPoint(x: 12, y: 12 + offset))
            p.addLine(to: CGPoint(x: 11, y: 5 + offset))
            p.addQuadCurve(to: CGPoint(x: 13, y: 2 + offset), control: CGPoint(x: 10, y: 2 + offset))
            p.addLine(to: CGPoint(x: 19, y: 2 + offset))
            p.addQuadCurve(to: CGPoint(x: 21, y: 5 + offset), control: CGPoint(x: 22, y: 2 + offset))
            p.addLine(to: CGPoint(x: 20, y: 12 + offset))
            p.addLine(to: CGPoint(x: 22, y: 18 + offset))
        }
    }

    /// A broad arched spring plate, circular eye and rolled gripping jaw.
    private var bulldogClip: some View {
        ZStack(alignment: .topLeading) {
            mountainPlate.fill(metal)
            mountainPlate.stroke(edge, lineWidth: 0.7)
            Circle().fill(Color.black.opacity(0.65))
                .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 0.6))
                .frame(width: 4.5, height: 4.5).offset(x: 13.75, y: 7)
            RoundedRectangle(cornerRadius: 1.8)
                .fill(LinearGradient(colors: [.white.opacity(0.7), .clear, .black.opacity(0.3)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 24, height: 5).offset(x: 4, y: 16)
            Capsule().fill(metal).frame(width: 30, height: 4).offset(x: 1, y: 21)
            Capsule().fill(Color.white.opacity(0.7)).frame(width: 26, height: 0.7).offset(x: 3, y: 21.5)
            Capsule().fill(Color.black.opacity(0.35)).frame(width: 26, height: 0.7).offset(x: 3, y: 24)
        }
        .frame(width: 32, height: 26)
    }

    private var mountainPlate: Path {
        Path { p in
            p.move(to: CGPoint(x: 2, y: 22))
            p.addLine(to: CGPoint(x: 2, y: 16))
            p.addQuadCurve(to: CGPoint(x: 8, y: 12), control: CGPoint(x: 2, y: 12))
            p.addCurve(to: CGPoint(x: 24, y: 12), control1: CGPoint(x: 8, y: -1), control2: CGPoint(x: 24, y: -1))
            p.addQuadCurve(to: CGPoint(x: 30, y: 16), control: CGPoint(x: 30, y: 12))
            p.addLine(to: CGPoint(x: 30, y: 22))
            p.closeSubpath()
        }
    }
}
