import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

// ═══════════════════════════════════════════════════════════════
// MARK: - SOUND
// ═══════════════════════════════════════════════════════════════
enum SoundFX {
    static func tap() { AudioServicesPlaySystemSound(1104) }
    static func menu() { AudioServicesPlaySystemSound(1105) }
    static func error() { AudioServicesPlaySystemSound(1053) }
    static func tingTing() {
        AudioServicesPlaySystemSound(1057)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            AudioServicesPlaySystemSound(1057)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - BACKGROUND LAYER
// ═══════════════════════════════════════════════════════════════
struct NeonBackgroundView: View {
    var body: some View {
        ZStack {
            Color.black
            StarfieldView()
            ShootingStarsView()
            FloatingOrbsView()
            FloatingParticlesView(particleCount: 80)
        }
        .ignoresSafeArea()
    }
}

struct StarfieldView: View {
    private struct Star {
        let x: CGFloat; let y: CGFloat
        let size: CGFloat; let phase: Double
    }
    @State private var stars: [Star] = []

    var body: some View {
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for s in stars {
                        let alpha = 0.25 + 0.45 * sin(t * 0.9 + s.phase)
                        let rect = CGRect(x: s.x * size.width, y: s.y * size.height,
                                          width: s.size, height: s.size)
                        ctx.fill(Path(ellipseIn: rect),
                                 with: .color(Color.white.opacity(alpha)))
                    }
                }
            }
            .onAppear {
                guard stars.isEmpty else { return }
                stars = (0..<110).map { _ in
                    Star(x: CGFloat.random(in: 0...1),
                         y: CGFloat.random(in: 0...1),
                         size: CGFloat.random(in: 0.7...2.0),
                         phase: Double.random(in: 0...(2 * .pi)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Sao băng chéo
struct ShootingStarsView: View {
    private struct Shot {
        let startX: CGFloat
        let startY: CGFloat
        let speed: CGFloat
        let delay: Double
    }
    @State private var shots: [Shot] = []

    var body: some View {
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 1.0 / 40.0)) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for s in shots {
                        let elapsed = (t - s.delay).truncatingRemainder(dividingBy: 8)
                        guard elapsed > 0 && elapsed < 3 else { continue }
                        let progress = elapsed / 3.0
                        let x = s.startX * size.width + CGFloat(progress) * 300
                        let y = s.startY * size.height + CGFloat(progress) * 200
                        let alpha = 1.0 - progress

                        // Trail
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x - 60, y: y - 40))
                        ctx.stroke(path,
                                   with: .color(Color.white.opacity(alpha * 0.9)),
                                   lineWidth: 1.6)

                        // Head
                        let head = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
                        ctx.fill(Path(ellipseIn: head),
                                 with: .color(Color.white.opacity(alpha)))
                    }
                }
            }
            .onAppear {
                guard shots.isEmpty else { return }
                shots = (0..<6).map { i in
                    Shot(startX: CGFloat.random(in: 0...0.7),
                         startY: CGFloat.random(in: 0...0.5),
                         speed: CGFloat.random(in: 0.8...1.2),
                         delay: Double(i) * 1.6)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Quả cầu sáng bay lơ lửng
struct FloatingOrbsView: View {
    private struct Orb {
        let baseX: CGFloat; let baseY: CGFloat
        let radius: CGFloat
        let colorSeed: Int
        let phase: Double
    }
    @State private var orbs: [Orb] = []

    var body: some View {
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for o in orbs {
                        let dx = sin(t * 0.35 + o.phase) * 40
                        let dy = cos(t * 0.28 + o.phase) * 30
                        let cx = o.baseX * size.width + dx
                        let cy = o.baseY * size.height + dy
                        let rect = CGRect(x: cx - o.radius, y: cy - o.radius,
                                          width: o.radius * 2, height: o.radius * 2)

                        let color: Color = {
                            switch o.colorSeed % 3 {
                            case 0: return Color.white.opacity(0.14)
                            case 1: return Color.cyan.opacity(0.14)
                            default: return Color.purple.opacity(0.14)
                            }
                        }()

                        ctx.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
            }
            .onAppear {
                guard orbs.isEmpty else { return }
                orbs = (0..<5).map { i in
                    Orb(baseX: CGFloat.random(in: 0.1...0.9),
                        baseY: CGFloat.random(in: 0.1...0.9),
                        radius: CGFloat.random(in: 60...110),
                        colorSeed: i,
                        phase: Double.random(in: 0...(2 * .pi)))
                }
            }
        }
        .allowsHitTesting(false)
        .blur(radius: 8)
    }
}

struct FloatingParticlesView: View {
    var particleCount: Int = 80

    private struct Particle {
        let baseX: CGFloat
        let size: CGFloat
        let speed: CGFloat
        let opacity: Double
        let phase: Double
    }
    @State private var particles: [Particle] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for p in particles {
                    let total = Double(size.height) + 80
                    let traveled = (t * Double(p.speed)).truncatingRemainder(dividingBy: total)
                    let y = size.height + 40 - CGFloat(traveled)
                    let wobble = sin(t * 0.9 + p.phase) * 14
                    let x = p.baseX * size.width + wobble
                    let rect = CGRect(x: x, y: y, width: p.size, height: p.size)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(Color.white.opacity(p.opacity)))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: spawn)
    }
    private func spawn() {
        guard particles.isEmpty else { return }
        particles = (0..<particleCount).map { _ in
            Particle(baseX: CGFloat.random(in: 0...1),
                     size: CGFloat.random(in: 1.0...3.2),
                     speed: CGFloat.random(in: 20...55),
                     opacity: Double.random(in: 0.25...0.9),
                     phase: Double.random(in: 0...(2 * .pi)))
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MODEL
// ═══════════════════════════════════════════════════════════════
struct GameSelection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let prefix: String
}

// ═══════════════════════════════════════════════════════════════
// MARK: - METADATA (override flags để giữ sửa của user)
// ═══════════════════════════════════════════════════════════════
struct PatchMeta: Codable {
    var remoteName: String
    var folder: String
    var tag: String
    var displayName: String
    var note: String
    var tagOverride: Bool = false
    var nameOverride: Bool = false
    var noteOverride: Bool = false
}

enum PatchMetaStore {
    private static let key = "patch_meta_v6"

    static func all() -> [String: PatchMeta] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: PatchMeta].self, from: data)
        else { return [:] }
        return dict
    }
    static func save(_ dict: [String: PatchMeta]) {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    static func set(_ meta: PatchMeta, forKey local: String) {
        var d = all(); d[local] = meta; save(d)
    }
    static func get(forKey local: String) -> PatchMeta? {
        return all()[local]
    }
    static func update(_ block: (inout PatchMeta) -> Void, forKey local: String) {
        var d = all()
        guard var m = d[local] else { return }
        block(&m)
        d[local] = m
        save(d)
    }
    static func importedRemoteNames() -> Set<String> {
        return Set(all().values.map { $0.remoteName })
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SUB VIEWS
// ═══════════════════════════════════════════════════════════════
private struct NeonCard<Content: View>: View {
    let accent: Color
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.9)))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white, accent.opacity(0.6), .white.opacity(0.35)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: accent.opacity(0.4), radius: 20)
            .shadow(color: .white.opacity(0.18), radius: 8)
    }
}

private struct FFLogoView: View {
    var body: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/free.jpg")) { phase in
            switch phase {
            case .empty:
                ZStack {
                    RoundedRectangle(cornerRadius: 13).fill(Color.white.opacity(0.06))
                    ProgressView().tint(.white)
                }
            case .success(let img):
                img.resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 13))
            case .failure:
                ZStack {
                    RoundedRectangle(cornerRadius: 13).fill(Color.white.opacity(0.06))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.orange)
                }
            @unknown default: EmptyView()
            }
        }
        .frame(width: 52, height: 52)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.75), lineWidth: 1))
        .shadow(color: .white.opacity(0.4), radius: 10)
    }
}

/// Avatar với vòng neon xoay + halo pulse
private struct AvatarView: View {
    @State private var rotate = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Halo pulse
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: pulse ? 110 : 90, height: pulse ? 110 : 90)
                .blur(radius: 20)

            // Rotating neon ring
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.white, Color.cyan, Color.white,
                            Color.purple, Color.white
                        ]),
                        center: .center
                    ),
                    lineWidth: 2.5
                )
                .frame(width: 92, height: 92)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .blur(radius: 1.5)

            // Second inner rotating ring (reverse)
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.cyan.opacity(0.6),
                            Color.clear,
                            Color.purple.opacity(0.6),
                            Color.clear,
                            Color.cyan.opacity(0.6)
                        ]),
                        center: .center
                    ),
                    lineWidth: 1
                )
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(rotate ? -360 : 0))

            // Main avatar
            avatarImage
                .frame(width: 78, height: 78)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 1.2))
        }
        .frame(width: 110, height: 110)
        .onAppear {
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                rotate = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var avatarImage: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Color.black.opacity(0.6)
                    ProgressView().tint(.white)
                }
            case .success(let img):
                img.resizable().scaledToFill()
            case .failure:
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            @unknown default: EmptyView()
            }
        }
    }
}

private struct MenuCapsuleButton: View {
    var body: some View {
        HStack(spacing: 5) {
            Text("MỞ MENU")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.8)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .heavy))
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white))
        .shadow(color: .white.opacity(0.6), radius: 10)
    }
}

private struct TagBadge: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    private var bg: Color { isVIP ? Color.yellow.opacity(0.25) : Color.white.opacity(0.12) }
    private var fg: Color { isVIP ? Color.yellow : Color.white.opacity(0.9) }
    private var bd: Color { isVIP ? Color.yellow.opacity(0.75) : Color.white.opacity(0.45) }

    var body: some View {
        Text(tag)
            .font(.system(size: 8, weight: .heavy))
            .tracking(0.8)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
            .overlay(Capsule().stroke(bd, lineWidth: 0.7))
    }
}

private struct PatchIconView: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    private var icon: String { isVIP ? "crown.fill" : "shield.lefthalf.filled" }
    private var color: Color { isVIP ? Color.yellow : Color.white.opacity(0.9) }
    private var border: Color { isVIP ? Color.yellow.opacity(0.65) : Color.white.opacity(0.45) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.05))
                .frame(width: 40, height: 40)
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(color)
        }
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(border, lineWidth: 1))
        .shadow(color: isVIP ? .yellow.opacity(0.35) : .clear, radius: 8)
    }
}

private struct FolderTabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    private var bg: Color { isActive ? Color.white : Color.white.opacity(0.06) }
    private var fg: Color { isActive ? Color.black : Color.white.opacity(0.9) }

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(bg))
                .foregroundStyle(fg)
                .overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1))
                .shadow(color: isActive ? Color.white.opacity(0.6) : .clear, radius: 12)
        }
        .buttonStyle(.plain)
    }
}

/// Banner kích hoạt — hiển thị "HeadLock Zenis" + Note
private struct NoteBanner: View {
    let note: String
    @State private var pulse = false
    @State private var shimmer = false

    private var hasNote: Bool { !note.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.green)
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .shadow(color: .green.opacity(0.9), radius: pulse ? 12 : 5)

                Text("HEADLOCK ZENIS")
                    .font(.custom("Copperplate-Bold", size: 12))
                    .tracking(2)
                    .foregroundStyle(Color.white)

                Spacer()

                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: .green, radius: 6)
            }

            if hasNote {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.green.opacity(0.9))
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.09)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.green.opacity(0.9), Color.green.opacity(0.3), Color.green.opacity(0.9)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    lineWidth: 1.1
                )
        )
        .shadow(color: .green.opacity(0.4), radius: 16)
        .overlay(shimmerOverlay)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                shimmer.toggle()
            }
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, .white.opacity(0.14), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.5)
            .offset(x: shimmer ? geo.size.width : -geo.size.width * 0.5)
            .blendMode(.screen)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
    }
}

private struct PatchRowView: View {
    let isApplied: Bool
    let isWorking: Bool
    let displayName: String
    let tag: String
    let note: String
    let onToggle: (Bool) -> Void
    let onTapTag: () -> Void
    let onRename: () -> Void
    let onEditNote: () -> Void

    private var rowBg: Color { isApplied ? Color.white.opacity(0.06) : Color.white.opacity(0.02) }
    private var rowBorder: Color { isApplied ? Color.green.opacity(0.7) : Color.white.opacity(0.32) }

    var body: some View {
        HStack(spacing: 10) {
            PatchIconView(tag: tag)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(displayName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    Button(action: onTapTag) { TagBadge(tag: tag) }
                        .buttonStyle(.plain)
                }
                if !note.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                        Text(note)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .lineLimit(2)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(get: { isApplied }, set: { onToggle($0) }))
                .labelsHidden()
                .tint(Color.green)
                .disabled(isWorking)
                .shadow(color: isApplied ? .green.opacity(0.6) : .clear, radius: 10)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 14).fill(rowBg))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(rowBorder, lineWidth: 1))
        .shadow(color: isApplied ? Color.green.opacity(0.4) : .clear, radius: 14)
        .contextMenu {
            Button(action: onRename) { Label("Đổi tên hiển thị", systemImage: "pencil") }
            Button(action: onTapTag) { Label("Đổi VIP / FREE", systemImage: "crown") }
            Button(action: onEditNote) { Label("Sửa ghi chú", systemImage: "note.text") }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MAIN VIEW
// ═══════════════════════════════════════════════════════════════
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore

    @State private var isAutoSyncing = false
    @State private var actionAlert: PatchStoreAlert?
    @State private var selectedGame: GameSelection?

    private let autoTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    init(
        onOpenSettings: @escaping () -> Void = {},
        onOpenLogs: @escaping () -> Void = {}
    ) {
        self.onOpenSettings = onOpenSettings
        self.onOpenLogs = onOpenLogs
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) {
                    header
                    content
                }
            }
            .navigationBarHidden(true)
            .onAppear { syncRemotePatches() }
            .onReceive(autoTimer) { _ in syncRemotePatches() }
            .sheet(item: $selectedGame) { game in
                PatchGameDetailView(
                    game: game,
                    store: store,
                    actionAlert: $actionAlert,
                    language: language
                )
            }
            .alert(item: $actionAlert) { alert in
                Alert(
                    title: Text(alert.titleKey),
                    message: Text(alert.message(language: language)),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            AvatarView()

            Text("ZENITH SOLITUDE")
                .font(.custom("Copperplate-Bold", size: 20))
                .tracking(4)
                .foregroundStyle(Color.white)
                .shadow(color: .white.opacity(0.7), radius: 14)
                .padding(.top, 4)

            Text("HEADLOCK ZENIS")
                .font(.system(size: 10, weight: .heavy))
                .tracking(4)
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                cardMax
                cardNormal

                Text("By Zenith Solitude")
                    .font(.custom("Copperplate", size: 11))
                    .tracking(3)
                    .foregroundStyle(Color.white.opacity(0.4))
                    .padding(.top, 8)
                    .shadow(color: .white.opacity(0.3), radius: 8)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 36)
        }
    }

    private var cardMax: some View {
        gameCard(title: "Free Fire Max", prefix: "ffmax_",
                 accent: Color(red: 1.0, green: 0.30, blue: 0.15))
    }
    private var cardNormal: some View {
        gameCard(title: "Free Fire Thường", prefix: "ffnormal_",
                 accent: Color(red: 0.30, green: 0.65, blue: 1.0))
    }

    @ViewBuilder
    private func gameCard(title: String, prefix: String, accent: Color) -> some View {
        Button {
            SoundFX.menu()
            selectedGame = GameSelection(title: title, prefix: prefix)
        } label: {
            NeonCard(accent: accent) {
                HStack(spacing: 12) {
                    FFLogoView()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white)
                        Text("Headlock Zenis")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    Spacer()
                    if isAutoSyncing {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        MenuCapsuleButton()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Sync — RE-MATCH TOÀN BỘ (fix folder)
    private func syncRemotePatches() {
        guard !isAutoSyncing else { return }
        isAutoSyncing = true
        Task { await runSync() }
    }

    private func runSync() async {
        do {
            guard let listUrl = URL(string: "https://solitudepremium.click/ipa/proxy/list.php") else {
                await MainActor.run { isAutoSyncing = false }
                return
            }
            let (data, _) = try await URLSession.shared.data(from: listUrl)
            let remoteFiles = try JSONDecoder().decode([RemoteFile].self, from: data)

            // BƯỚC 1 — Import file chưa có
            let imported = PatchMetaStore.importedRemoteNames()
            var newlyImported = false
            for file in remoteFiles {
                if imported.contains(file.filename) { continue }
                guard let fileURL = URL(string: file.url) else { continue }
                await MainActor.run { store.importPackage(from: .remote(fileURL)) }
                newlyImported = true
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }

            if newlyImported {
                await MainActor.run { store.reload() }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            // BƯỚC 2 — Re-match TOÀN BỘ local items với remote files
            let localItems = await MainActor.run { store.items }
            for item in localItems {
                let localName = item.packageURL.lastPathComponent
                guard let remote = findRemoteMatch(localName: localName, in: remoteFiles) else { continue }

                if var existing = PatchMetaStore.get(forKey: localName) {
                    // Folder luôn cập nhật từ remote (nguồn sự thật)
                    existing.folder = remote.folder ?? "Khác"
                    existing.remoteName = remote.filename
                    if !existing.tagOverride { existing.tag = remote.tag ?? "FREE" }
                    if !existing.nameOverride { existing.displayName = remote.displayName ?? "" }
                    if !existing.noteOverride { existing.note = remote.note ?? "" }
                    PatchMetaStore.set(existing, forKey: localName)
                } else {
                    let meta = PatchMeta(
                        remoteName:  remote.filename,
                        folder:      remote.folder ?? "Khác",
                        tag:         remote.tag ?? "FREE",
                        displayName: remote.displayName ?? "",
                        note:        remote.note ?? ""
                    )
                    PatchMetaStore.set(meta, forKey: localName)
                }
            }
        } catch {
            print("Lỗi đồng bộ: \(error.localizedDescription)")
        }
        await MainActor.run {
            store.reload()
            isAutoSyncing = false
        }
    }

    /// Tìm remote file khớp với local file.
    /// Local: "ZENITH_aim_51067270_F5D3-XXXX.3105"
    /// Remote: "aim_51067270_FREE.3105" → clean base "aim_51067270"
    private func findRemoteMatch(localName: String, in remotes: [RemoteFile]) -> RemoteFile? {
        let localBase = (localName as NSString).deletingPathExtension.lowercased()
        for remote in remotes {
            var remoteBase = (remote.filename as NSString).deletingPathExtension.lowercased()
            remoteBase = remoteBase
                .replacingOccurrences(of: "_vip", with: "")
                .replacingOccurrences(of: "_free", with: "")
            if remoteBase.isEmpty { continue }
            if localBase.contains(remoteBase) {
                return remote
            }
        }
        return nil
    }

    private struct RemoteFile: Decodable {
        let filename: String
        let gameType: String
        let folder: String?
        let displayName: String?
        let tag: String?
        let note: String?
        let url: String
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DETAIL VIEW
// ═══════════════════════════════════════════════════════════════
struct PatchGameDetailView: View {
    let game: GameSelection
    @ObservedObject var store: PatchProjectStore
    @Binding var actionAlert: PatchStoreAlert?
    let language: AppLanguage

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFolder: String?
    @State private var workingFileID: String?
    @State private var renameItem: PatchLibraryItem?
    @State private var renameText: String = ""
    @State private var tagPickerItem: PatchLibraryItem?
    @State private var noteItem: PatchLibraryItem?
    @State private var noteText: String = ""
    @State private var refreshTick: Int = 0

    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) {
                    if let activeItem = activeItem {
                        NoteBanner(note: currentNote(for: activeItem))
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.spring(response: 0.4), value: activeItem.id)
                    }
                    if !folders.isEmpty { folderTabs }
                    listContent
                }
            }
            .navigationTitle(game.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { closeButton }
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onReceive(refreshTimer) { _ in
                refreshTick &+= 1
                store.reload()
            }
            .alert(item: $actionAlert) { alert in
                Alert(
                    title: Text(alert.titleKey),
                    message: Text(alert.message(language: language)),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Đổi tên hiển thị", isPresented: renameBinding) {
                TextField("Tên mới", text: $renameText)
                Button("Huỷ", role: .cancel) { renameItem = nil }
                Button("Lưu") { commitRename() }
            }
            .alert("Ghi chú", isPresented: noteBinding) {
                TextField("Ghi chú cho patch", text: $noteText)
                Button("Huỷ", role: .cancel) { noteItem = nil }
                Button("Lưu") { commitNote() }
            }
            .confirmationDialog("Chọn loại tag", isPresented: tagBinding, titleVisibility: .visible) {
                Button("VIP 👑") { commitTag("VIP") }
                Button("FREE 🛡") { commitTag("FREE") }
                Button("Huỷ", role: .cancel) { tagPickerItem = nil }
            }
        }
    }

    private var gameItems: [PatchLibraryItem] {
        _ = refreshTick
        return store.items.filter { item in
            let name = item.packageURL.lastPathComponent
            let isMax = name.hasPrefix("ffmax_")
            let isNormal = name.hasPrefix("ffnormal_")
            let isPlain = !isMax && !isNormal
            if game.prefix == "ffmax_" { return isMax }
            return isNormal || isPlain
        }
    }

    private var folders: [String] {
        var set = Set(gameItems.map { folderName(for: $0) })
        set.remove("")
        return Array(set).sorted()
    }

    private var displayedItems: [PatchLibraryItem] {
        guard let selected = selectedFolder else { return gameItems }
        return gameItems.filter { folderName(for: $0) == selected }
    }

    private var activeItem: PatchLibraryItem? {
        for item in gameItems {
            if DevicePatchService.latestReceipt(projectID: item.id) != nil {
                return item
            }
        }
        return nil
    }

    private var renameBinding: Binding<Bool> {
        Binding(get: { renameItem != nil }, set: { if !$0 { renameItem = nil } })
    }
    private var tagBinding: Binding<Bool> {
        Binding(get: { tagPickerItem != nil }, set: { if !$0 { tagPickerItem = nil } })
    }
    private var noteBinding: Binding<Bool> {
        Binding(get: { noteItem != nil }, set: { if !$0 { noteItem = nil } })
    }

    private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                SoundFX.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
    }

    private var folderTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(folders, id: \.self) { folder in
                    FolderTabButton(
                        title: folder,
                        isActive: selectedFolder == folder,
                        action: { selectFolder(folder) }
                    )
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 10)
    }

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(displayedItems) { item in
                    patchRow(item: item)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 36)
        }
    }

    @ViewBuilder
    private func patchRow(item: PatchLibraryItem) -> some View {
        let receipt = DevicePatchService.latestReceipt(projectID: item.id)
        let isApplied = (receipt != nil)
        let fileID = item.id.uuidString
        let tag = currentTag(for: item)
        let name = displayName(for: item)
        let note = currentNote(for: item)

        PatchRowView(
            isApplied: isApplied,
            isWorking: (workingFileID == fileID),
            displayName: name,
            tag: tag,
            note: note,
            onToggle: { newValue in
                if newValue { SoundFX.tingTing() } else { SoundFX.tap() }
                togglePatch(item: item, activate: newValue)
            },
            onTapTag: {
                SoundFX.tap()
                tagPickerItem = item
            },
            onRename: {
                SoundFX.tap()
                renameItem = item
                renameText = name
            },
            onEditNote: {
                SoundFX.tap()
                noteItem = item
                noteText = note
            }
        )
    }

    private func selectFolder(_ folder: String) {
        SoundFX.tap()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selectedFolder = (selectedFolder == folder) ? nil : folder
        }
    }

    private func localKey(for item: PatchLibraryItem) -> String {
        return item.packageURL.lastPathComponent
    }

    private func displayName(for item: PatchLibraryItem) -> String {
        if let meta = PatchMetaStore.get(forKey: localKey(for: item)),
           !meta.displayName.isEmpty {
            return meta.displayName
        }
        if let name = item.project?.name, !name.isEmpty { return name }
        return item.packageURL
            .deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: "_VIP", with: "")
            .replacingOccurrences(of: "_FREE", with: "")
            .replacingOccurrences(of: "ffmax_", with: "")
            .replacingOccurrences(of: "ffnormal_", with: "")
    }

    private func currentTag(for item: PatchLibraryItem) -> String {
        if let meta = PatchMetaStore.get(forKey: localKey(for: item)),
           !meta.tag.isEmpty {
            return meta.tag
        }
        let base = item.packageURL.deletingPathExtension().lastPathComponent
        return base.hasSuffix("_VIP") ? "VIP" : "FREE"
    }

    private func currentNote(for item: PatchLibraryItem) -> String {
        return PatchMetaStore.get(forKey: localKey(for: item))?.note ?? ""
    }

    private func folderName(for item: PatchLibraryItem) -> String {
        if let meta = PatchMetaStore.get(forKey: localKey(for: item)),
           !meta.folder.isEmpty {
            return meta.folder
        }
        let comps = item.packageURL.pathComponents.filter { $0 != "/" }
        if let idx = comps.firstIndex(where: { $0 == "ffmax" || $0 == "ffnormal" }),
           idx + 2 < comps.count {
            return comps[idx + 1]
        }
        let parent = item.packageURL.deletingLastPathComponent().lastPathComponent
        let ignore: Set<String> = ["Documents", "tmp", "proxy", "PatchProjects", "PatchProjectStore", ""]
        if !ignore.contains(parent) { return parent }
        return "Khác"
    }

    private func commitRename() {
        guard let item = renameItem else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            PatchMetaStore.update({ $0.displayName = trimmed; $0.nameOverride = true },
                                  forKey: localKey(for: item))
            store.reload()
        }
        renameItem = nil
    }

    private func commitTag(_ tag: String) {
        guard let item = tagPickerItem else { return }
        PatchMetaStore.update({ $0.tag = tag; $0.tagOverride = true },
                              forKey: localKey(for: item))
        store.reload()
        tagPickerItem = nil
    }

    private func commitNote() {
        guard let item = noteItem else { return }
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        PatchMetaStore.update({ $0.note = trimmed; $0.noteOverride = true },
                              forKey: localKey(for: item))
        store.reload()
        noteItem = nil
    }

    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        let fileID = item.id.uuidString
        workingFileID = fileID

        Task.detached(priority: .userInitiated) {
            do {
                try await performToggle(item: item, activate: activate)
                await MainActor.run {
                    store.reload()
                    workingFileID = nil
                    if activate {
                        // Chỉ hiện alert khi BẬT. Khi TẮT không hiện gì.
                        let name = displayName(for: item)
                        actionAlert = PatchStoreAlert(
                            titleKey: "Đã kích hoạt",
                            messageKey: "HeadLock Zenis — \(name)"
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    workingFileID = nil
                    SoundFX.error()
                    actionAlert = PatchStoreAlert(
                        titleKey: "Lỗi",
                        messageKey: "Thao tác thất bại: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    private func performToggle(item: PatchLibraryItem, activate: Bool) throws {
        if activate {
            guard let project = item.project else { return }
            _ = try DevicePatchService.apply(project: project)
        } else {
            guard let receipt = DevicePatchService.latestReceipt(projectID: item.id) else { return }
            try DevicePatchService.restore(receipt: receipt)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - UNLOCK VIEW
// ═══════════════════════════════════════════════════════════════
struct PatchUnlockView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    let request: PatchPasswordRequest
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(language.text("patch.password"), text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .onSubmit(unlock)
                        .onChange(of: password) { _ in
                            store.clearUnlockError()
                        }
                    if let errorKey = store.unlockErrorKey {
                        Text(errorText(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(language.text("patch.unlock"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("patch.unlock"), action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }

    private func errorText(_ key: String) -> String {
        if let arg = store.unlockErrorArgument {
            return language.text(key, arg)
        }
        return language.text(key)
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - PRESENTATION MODIFIER
// ═══════════════════════════════════════════════════════════════
private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore

    func body(content: Content) -> some View {
        content
            .sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { request in
                PatchUnlockView(store: store, request: request)
            }
    }
}

extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View {
        modifier(PatchStorePresentationModifier(store: store))
    }
}
