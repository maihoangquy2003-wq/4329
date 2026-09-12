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
// MARK: - AURORA COSMIC BACKGROUND
// ═══════════════════════════════════════════════════════════════
struct NeonBackgroundView: View {
    var body: some View {
        ZStack {
            Color.black
            AuroraRibbonsView()
            VignetteView()
            StarfieldView()
            FloatingParticlesView(particleCount: 70)
        }
        .ignoresSafeArea()
    }
}

/// 4 dải aurora mềm mại uốn lượn — không màu, chỉ trắng mờ
struct AuroraRibbonsView: View {
    @State private var phase: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ribbon(offset: 0.0, scale: 1.0, baseOpacity: 0.11, geo: geo)
                ribbon(offset: 0.9, scale: 0.75, baseOpacity: 0.08, geo: geo)
                ribbon(offset: 1.7, scale: 1.15, baseOpacity: 0.10, geo: geo)
                ribbon(offset: 2.5, scale: 0.85, baseOpacity: 0.07, geo: geo)
            }
            .blur(radius: 90)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }

    private func ribbon(offset: Double, scale: CGFloat, baseOpacity: Double, geo: GeometryProxy) -> some View {
        let cx = 0.5 + 0.35 * sin(phase + offset)
        let cy = 0.5 + 0.35 * cos(phase * 0.75 + offset)
        return RadialGradient(
            colors: [Color.white.opacity(baseOpacity), Color.clear],
            center: UnitPoint(x: cx, y: cy),
            startRadius: 0,
            endRadius: geo.size.width * 0.75 * scale
        )
    }
}

/// Vignette tối 4 góc
struct VignetteView: View {
    var body: some View {
        RadialGradient(
            colors: [Color.clear, Color.clear, Color.black.opacity(0.75)],
            center: .center,
            startRadius: 0,
            endRadius: 500
        )
        .allowsHitTesting(false)
    }
}

struct StarfieldView: View {
    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let phase: Double
        let speed: Double
    }
    @State private var stars: [Star] = []

    var body: some View {
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for s in stars {
                        let alpha = 0.15 + 0.55 * sin(t * s.speed + s.phase)
                        let rect = CGRect(
                            x: s.x * size.width,
                            y: s.y * size.height,
                            width: s.size, height: s.size
                        )
                        ctx.fill(Path(ellipseIn: rect),
                                 with: .color(Color.white.opacity(max(0, alpha))))
                    }
                }
            }
            .onAppear {
                guard stars.isEmpty else { return }
                stars = (0..<150).map { _ in
                    Star(x: CGFloat.random(in: 0...1),
                         y: CGFloat.random(in: 0...1),
                         size: CGFloat.random(in: 0.5...2.0),
                         phase: Double.random(in: 0...(2 * .pi)),
                         speed: Double.random(in: 0.5...1.6))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct FloatingParticlesView: View {
    var particleCount: Int = 70

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
                    let wobble = sin(t * 0.9 + p.phase) * 16
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
                     size: CGFloat.random(in: 1.0...3.0),
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
// MARK: - METADATA
// ═══════════════════════════════════════════════════════════════
struct PatchMeta: Codable {
    var remoteName: String
    var matchKey: String
    var folder: String
    var tag: String
    var displayName: String
    var note: String
    var tagOverride: Bool = false
    var nameOverride: Bool = false
    var noteOverride: Bool = false
}

enum PatchMetaStore {
    private static let key = "patch_meta_v9"

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
// MARK: - MATCHER
// ═══════════════════════════════════════════════════════════════
enum PatchMatcher {
    static func normalizeLocal(_ name: String) -> String {
        var s = (name as NSString).deletingPathExtension.lowercased()
        s = s.replacingOccurrences(
            of: #"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"#,
            with: "",
            options: .regularExpression
        )
        s = s.replacingOccurrences(of: "zenith_", with: "")
        s = s.replacingOccurrences(of: "_vip", with: "")
        s = s.replacingOccurrences(of: "_free", with: "")
        s = s.replacingOccurrences(of: #"[^a-z0-9_-]"#, with: "_", options: .regularExpression)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return s
    }

    static func match(localName: String, in remotes: [RemoteFileLite]) -> RemoteFileLite? {
        let localKey = normalizeLocal(localName)
        guard !localKey.isEmpty else { return nil }
        for r in remotes where r.matchKey == localKey { return r }
        for r in remotes {
            if r.matchKey.isEmpty { continue }
            if localKey.contains(r.matchKey) || r.matchKey.contains(localKey) { return r }
        }
        return nil
    }
}

struct RemoteFileLite {
    let filename: String
    let matchKey: String
    let folder: String
    let tag: String
    let displayName: String
    let note: String
    let url: String
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SUB VIEWS
// ═══════════════════════════════════════════════════════════════
private struct NeonWhiteCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.88)))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.55), .white],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.4
                    )
            )
            .shadow(color: .white.opacity(0.35), radius: 22)
            .shadow(color: .white.opacity(0.18), radius: 10)
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
                        .foregroundStyle(Color.white.opacity(0.8))
                }
            @unknown default: EmptyView()
            }
        }
        .frame(width: 52, height: 52)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.85), lineWidth: 1.2))
        .shadow(color: .white.opacity(0.55), radius: 14)
    }
}

private struct AvatarView: View {
    @State private var rotate = false
    @State private var pulse = false
    @State private var rotate2 = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: pulse ? 118 : 96, height: pulse ? 118 : 96)
                .blur(radius: 24)

            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.white, Color.white.opacity(0.2), Color.white,
                            Color.white.opacity(0.15), Color.white
                        ]),
                        center: .center
                    ),
                    lineWidth: 2.5
                )
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .blur(radius: 1)

            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.7), Color.clear,
                            Color.white.opacity(0.6), Color.clear,
                            Color.white.opacity(0.7)
                        ]),
                        center: .center
                    ),
                    lineWidth: 1
                )
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(rotate2 ? -360 : 0))

            Circle()
                .stroke(
                    Color.white.opacity(0.35),
                    style: StrokeStyle(lineWidth: 0.8, dash: [2, 6])
                )
                .frame(width: 104, height: 104)
                .rotationEffect(.degrees(rotate ? 180 : 0))

            avatarImage
                .frame(width: 78, height: 78)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 1.4))
        }
        .frame(width: 120, height: 120)
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotate = true
            }
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                rotate2 = true
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
        .overlay(Capsule().stroke(Color.white, lineWidth: 1))
        .shadow(color: .white.opacity(0.75), radius: 14)
    }
}

private struct TagBadge: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }

    var body: some View {
        Text(tag)
            .font(.system(size: 8, weight: .heavy))
            .tracking(0.8)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.white.opacity(isVIP ? 0.22 : 0.12)))
            .foregroundStyle(Color.white)
            .overlay(
                Capsule().stroke(
                    Color.white.opacity(isVIP ? 0.9 : 0.5),
                    lineWidth: isVIP ? 1 : 0.7
                )
            )
            .shadow(color: isVIP ? .white.opacity(0.5) : .clear, radius: 6)
    }
}

private struct PatchIconView: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    private var icon: String { isVIP ? "crown.fill" : "shield.lefthalf.filled" }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.white.opacity(0.06))
                .frame(width: 40, height: 40)
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.white.opacity(isVIP ? 1.0 : 0.85))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.white.opacity(isVIP ? 0.75 : 0.45), lineWidth: 1)
        )
        .shadow(color: isVIP ? .white.opacity(0.5) : .clear, radius: 10)
    }
}

private struct FolderTabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    private var bg: Color { isActive ? Color.white : Color.white.opacity(0.05) }
    private var fg: Color { isActive ? Color.black : Color.white.opacity(0.9) }

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.2)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(bg))
                .foregroundStyle(fg)
                .overlay(Capsule().stroke(Color.white.opacity(0.65), lineWidth: 1.1))
                .shadow(color: isActive ? Color.white.opacity(0.8) : .clear, radius: 16)
        }
        .buttonStyle(.plain)
    }
}

private struct NoteBanner: View {
    let note: String
    @State private var pulse = false
    @State private var shimmer = false

    private var hasNote: Bool {
        !note.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .shadow(color: .white.opacity(0.95), radius: pulse ? 14 : 6)

                Text("HEADLOCK ZENIS")
                    .font(.custom("Copperplate-Bold", size: 12))
                    .tracking(2)
                    .foregroundStyle(Color.white)

                Spacer()

                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .shadow(color: .white, radius: 8)
            }

            if hasNote {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.95))
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.35), Color.white],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    lineWidth: 1.3
                )
        )
        .shadow(color: .white.opacity(0.5), radius: 20)
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
                colors: [.clear, .white.opacity(0.20), .clear],
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

    private var rowBg: Color { isApplied ? Color.white.opacity(0.08) : Color.white.opacity(0.02) }
    private var rowBorder: Color { isApplied ? Color.white.opacity(0.95) : Color.white.opacity(0.4) }

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
                            .foregroundStyle(Color.white.opacity(0.55))
                        Text(note)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(get: { isApplied }, set: { onToggle($0) }))
                .labelsHidden()
                .tint(Color.white)
                .disabled(isWorking)
                .shadow(color: isApplied ? .white.opacity(0.8) : .clear, radius: 14)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 14).fill(rowBg))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(rowBorder, lineWidth: 1.1))
        .shadow(color: isApplied ? Color.white.opacity(0.5) : .clear, radius: 18)
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

    private let autoTimer = Timer.publish(every: 12, on: .main, in: .common).autoconnect()

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
                .shadow(color: .white.opacity(0.8), radius: 18)
                .padding(.top, 4)

            Text("HEADLOCK ZENIS")
                .font(.system(size: 10, weight: .heavy))
                .tracking(4.5)
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                cardMax
                cardNormal

                Text("By Zenith Solitude")
                    .font(.custom("Copperplate", size: 11))
                    .tracking(3)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.top, 12)
                    .shadow(color: .white.opacity(0.4), radius: 12)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 40)
        }
    }

    private var cardMax: some View {
        gameCard(title: "Free Fire Max", prefix: "ffmax_")
    }
    private var cardNormal: some View {
        gameCard(title: "Free Fire Thường", prefix: "ffnormal_")
    }

    @ViewBuilder
    private func gameCard(title: String, prefix: String) -> some View {
        Button {
            SoundFX.menu()
            selectedGame = GameSelection(title: title, prefix: prefix)
        } label: {
            NeonWhiteCard {
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

    // MARK: Sync
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
            var request = URLRequest(url: listUrl)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 20
            let (data, _) = try await URLSession.shared.data(for: request)

            struct WireRemote: Decodable {
                let filename: String
                let gameType: String
                let folder: String?
                let displayName: String?
                let tag: String?
                let note: String?
                let matchKey: String?
                let url: String
            }
            let wire = try JSONDecoder().decode([WireRemote].self, from: data)
            let remotes: [RemoteFileLite] = wire.map { w in
                let mk = w.matchKey ?? PatchMatcher.normalizeLocal(
                    (w.filename as NSString).deletingPathExtension
                )
                return RemoteFileLite(
                    filename:    w.filename,
                    matchKey:    mk,
                    folder:      w.folder ?? "",
                    tag:         w.tag ?? "FREE",
                    displayName: w.displayName ?? "",
                    note:        w.note ?? "",
                    url:         w.url
                )
            }

            // BƯỚC 1 — Lưu metadata vào UserDefaults để tra cứu (không cần poll)
            let imported = PatchMetaStore.importedRemoteNames()

            // BƯỚC 2 — Import file chưa có
            for r in remotes {
                if imported.contains(r.filename) { continue }
                guard let url = URL(string: r.url) else { continue }
                await MainActor.run { store.importPackage(from: .remote(url)) }
                try? await Task.sleep(nanoseconds: 800_000_000)
            }

            // BƯỚC 3 — Đợi store update
            await MainActor.run { store.reload() }
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            // BƯỚC 4 — Match TOÀN BỘ local items
            let localItems = await MainActor.run { store.items }
            for item in localItems {
                let localName = item.packageURL.lastPathComponent
                guard let remote = PatchMatcher.match(localName: localName, in: remotes),
                      !remote.folder.isEmpty
                else { continue }

                if var existing = PatchMetaStore.get(forKey: localName) {
                    existing.folder     = remote.folder
                    existing.remoteName = remote.filename
                    existing.matchKey   = remote.matchKey
                    if !existing.tagOverride  { existing.tag = remote.tag }
                    if !existing.nameOverride { existing.displayName = remote.displayName }
                    if !existing.noteOverride { existing.note = remote.note }
                    PatchMetaStore.set(existing, forKey: localName)
                } else {
                    let meta = PatchMeta(
                        remoteName:  remote.filename,
                        matchKey:    remote.matchKey,
                        folder:      remote.folder,
                        tag:         remote.tag,
                        displayName: remote.displayName,
                        note:        remote.note
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
    @State private var selectedFolder: String? = nil
    @State private var didInitFolder = false
    @State private var workingFileID: String?
    @State private var renameItem: PatchLibraryItem?
    @State private var renameText: String = ""
    @State private var tagPickerItem: PatchLibraryItem?
    @State private var noteItem: PatchLibraryItem?
    @State private var noteText: String = ""
    @State private var refreshTick: Int = 0

    private let refreshTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

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
            .onAppear {
                // MẶC ĐỊNH chọn folder đầu tiên
                if !didInitFolder, let first = folders.first {
                    selectedFolder = first
                    didInitFolder = true
                }
            }
            .onReceive(refreshTimer) { _ in
                refreshTick &+= 1
                store.reload()
                if !didInitFolder, let first = folders.first {
                    selectedFolder = first
                    didInitFolder = true
                }
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
            let correctGame = game.prefix == "ffmax_" ? isMax : (isNormal || isPlain)
            guard correctGame else { return false }
            guard let meta = PatchMetaStore.get(forKey: name),
                  !meta.folder.isEmpty else { return false }
            return true
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
            selectedFolder = folder
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
        return ""
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
                let name = await MainActor.run { displayName(for: item) }
                await MainActor.run {
                    store.reload()
                    workingFileID = nil
                    if activate {
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
