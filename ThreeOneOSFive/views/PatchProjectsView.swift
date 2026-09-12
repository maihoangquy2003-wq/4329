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
// MARK: - BACKGROUND
// ═══════════════════════════════════════════════════════════════
struct NeonBackgroundView: View {
    var body: some View {
        ZStack {
            Color.black
            AuroraView()
            VignetteView()
            CosmicFieldView()
        }
        .ignoresSafeArea()
    }
}

struct AuroraView: View {
    @State private var phase: Double = 0
    var body: some View {
        GeometryReader { geo in
            ZStack {
                blob(cx: 0.28 + 0.10 * sin(phase),
                     cy: 0.25 + 0.08 * cos(phase * 0.7),
                     opacity: 0.13, r: geo.size.width * 0.75)
                blob(cx: 0.75 + 0.10 * cos(phase * 0.85),
                     cy: 0.72 + 0.10 * sin(phase * 0.6),
                     opacity: 0.10, r: geo.size.width * 0.85)
                blob(cx: 0.50 + 0.15 * sin(phase * 1.15),
                     cy: 0.50 + 0.15 * cos(phase * 0.9),
                     opacity: 0.08, r: geo.size.width * 0.65)
            }
            .blur(radius: 95)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 26).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
    private func blob(cx: Double, cy: Double, opacity: Double, r: CGFloat) -> some View {
        RadialGradient(
            colors: [Color.white.opacity(opacity), .clear],
            center: UnitPoint(x: cx, y: cy),
            startRadius: 0, endRadius: r
        )
    }
}

struct VignetteView: View {
    var body: some View {
        RadialGradient(
            colors: [.clear, .clear, Color.black.opacity(0.78)],
            center: .center, startRadius: 0, endRadius: 520
        )
        .allowsHitTesting(false)
    }
}

struct CosmicFieldView: View {
    private struct Star {
        let x: CGFloat; let y: CGFloat; let s: CGFloat
        let phase: Double; let freq: Double
    }
    private struct Particle {
        let x: CGFloat; let s: CGFloat
        let speed: CGFloat; let opacity: Double
        let phase: Double
    }
    @State private var stars: [Star] = []
    @State private var particles: [Particle] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for s in stars {
                    let a = 0.18 + 0.58 * sin(t * s.freq + s.phase)
                    let r = CGRect(x: s.x * size.width, y: s.y * size.height,
                                   width: s.s, height: s.s)
                    ctx.fill(Path(ellipseIn: r),
                             with: .color(Color.white.opacity(max(0, a))))
                }
                for p in particles {
                    let total = Double(size.height) + 100
                    let traveled = (t * Double(p.speed)).truncatingRemainder(dividingBy: total)
                    let y = size.height + 50 - CGFloat(traveled)
                    let wobble = sin(t * 0.85 + p.phase) * 18
                    let x = p.x * size.width + wobble
                    let r = CGRect(x: x, y: y, width: p.s, height: p.s)
                    ctx.fill(Path(ellipseIn: r),
                             with: .color(Color.white.opacity(p.opacity)))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: initField)
    }
    private func initField() {
        if stars.isEmpty {
            stars = (0..<110).map { _ in
                Star(x: CGFloat.random(in: 0...1),
                     y: CGFloat.random(in: 0...1),
                     s: CGFloat.random(in: 0.5...2.1),
                     phase: Double.random(in: 0...(2 * .pi)),
                     freq: Double.random(in: 0.5...1.8))
            }
        }
        if particles.isEmpty {
            particles = (0..<55).map { _ in
                Particle(x: CGFloat.random(in: 0...1),
                         s: CGFloat.random(in: 1.0...3.0),
                         speed: CGFloat.random(in: 18...50),
                         opacity: Double.random(in: 0.20...0.85),
                         phase: Double.random(in: 0...(2 * .pi)))
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MODELS
// ═══════════════════════════════════════════════════════════════
struct GameSelection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let prefix: String
}

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

struct RemoteFileLite {
    let filename: String
    let folder: String
    let tag: String
    let displayName: String
    let note: String
    let url: String
}

/// Kết quả kích hoạt: thành công hay thất bại (đều hiện sheet)
struct ActivationInfo: Identifiable {
    let id = UUID()
    let patchName: String
    let note: String
    let success: Bool
    let errorMessage: String?
}

// ═══════════════════════════════════════════════════════════════
// MARK: - META STORE
// ═══════════════════════════════════════════════════════════════
enum PatchMetaStore {
    private static let key = "patch_meta_v12"

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
    static func set(_ meta: PatchMeta, forLocal local: String) {
        var d = all(); d[local] = meta; save(d)
    }
    static func get(forLocal local: String) -> PatchMeta? { return all()[local] }
    static func allRemoteNames() -> Set<String> {
        return Set(all().values.map { $0.remoteName })
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SUB VIEWS
// ═══════════════════════════════════════════════════════════════
private struct NeonCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.9)))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(colors: [.white, .white.opacity(0.5), .white],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1.4)
            )
            .shadow(color: .white.opacity(0.4), radius: 22)
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
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.18))
                .frame(width: pulse ? 116 : 94, height: pulse ? 116 : 94).blur(radius: 24)
            Circle()
                .stroke(AngularGradient(gradient: Gradient(colors: [
                    .white, .white.opacity(0.15), .white, .white.opacity(0.15), .white
                ]), center: .center), lineWidth: 2.5)
                .frame(width: 94, height: 94)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .blur(radius: 1)
            Circle().stroke(Color.white.opacity(0.35),
                            style: StrokeStyle(lineWidth: 0.8, dash: [2, 6]))
                .frame(width: 104, height: 104)
                .rotationEffect(.degrees(rotate ? 180 : 0))
            avatarImage
                .frame(width: 76, height: 76)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 1.4))
        }
        .frame(width: 118, height: 118)
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) { rotate = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
    private var avatarImage: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
            switch phase {
            case .empty:
                ZStack { Color.black.opacity(0.6); ProgressView().tint(.white) }
            case .success(let img): img.resizable().scaledToFill()
            case .failure:
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            @unknown default: EmptyView()
            }
        }
    }
}

private struct MenuCapsule: View {
    var body: some View {
        HStack(spacing: 5) {
            Text("MỞ MENU").font(.system(size: 11, weight: .heavy)).tracking(0.8)
            Image(systemName: "chevron.right").font(.system(size: 9, weight: .heavy))
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(Color.white))
        .shadow(color: .white.opacity(0.75), radius: 14)
    }
}

private struct TagBadge: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    var body: some View {
        Text(tag)
            .font(.system(size: 8, weight: .heavy)).tracking(0.8)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(Color.white.opacity(isVIP ? 0.22 : 0.12)))
            .foregroundStyle(Color.white)
            .overlay(Capsule().stroke(Color.white.opacity(isVIP ? 0.9 : 0.5),
                                      lineWidth: isVIP ? 1 : 0.7))
            .shadow(color: isVIP ? .white.opacity(0.5) : .clear, radius: 6)
    }
}

private struct PatchIconView: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    private var icon: String { isVIP ? "crown.fill" : "shield.lefthalf.filled" }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.06))
                .frame(width: 40, height: 40)
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.white.opacity(isVIP ? 1.0 : 0.85))
        }
        .overlay(RoundedRectangle(cornerRadius: 11)
            .stroke(Color.white.opacity(isVIP ? 0.75 : 0.45), lineWidth: 1))
        .shadow(color: isVIP ? .white.opacity(0.5) : .clear, radius: 10)
    }
}

private struct FolderTab: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    private var bg: Color { isActive ? Color.white : Color.white.opacity(0.05) }
    private var fg: Color { isActive ? Color.black : Color.white.opacity(0.9) }
    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy)).tracking(1.2)
                .padding(.horizontal, 18).padding(.vertical, 9)
                .background(Capsule().fill(bg))
                .foregroundStyle(fg)
                .overlay(Capsule().stroke(Color.white.opacity(0.65), lineWidth: 1.1))
                .shadow(color: isActive ? Color.white.opacity(0.8) : .clear, radius: 16)
        }
        .buttonStyle(.plain)
    }
}

private struct PatchRow: View {
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
                .labelsHidden().tint(Color.white).disabled(isWorking)
                .shadow(color: isApplied ? .white.opacity(0.8) : .clear, radius: 14)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 14).fill(rowBg))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(rowBorder, lineWidth: 1.1))
        .shadow(color: isApplied ? Color.white.opacity(0.5) : .clear, radius: 18)
        .contextMenu {
            Button(action: onRename) { Label("Đổi tên", systemImage: "pencil") }
            Button(action: onTapTag) { Label("Đổi VIP/FREE", systemImage: "crown") }
            Button(action: onEditNote) { Label("Sửa ghi chú", systemImage: "note.text") }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ACTIVATION SHEET (Smart: success / fail)
// ═══════════════════════════════════════════════════════════════
struct ActivationNoteSheet: View {
    let info: ActivationInfo
    let onDismiss: () -> Void
    @State private var pulse = false
    @State private var shimmer = false

    private var accent: Color { info.success ? Color.white : Color(red: 1.0, green: 0.35, blue: 0.35) }
    private var titleText: String { info.success ? "ĐÃ KÍCH HOẠT" : "KHÔNG KÍCH HOẠT ĐƯỢC" }
    private var iconName: String { info.success ? "bolt.shield.fill" : "exclamationmark.triangle.fill" }
    private var hasNote: Bool { !info.note.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AuroraView().ignoresSafeArea().opacity(0.6)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer(minLength: 40)

                    // ICON
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.12))
                            .frame(width: pulse ? 110 : 96, height: pulse ? 110 : 96)
                            .blur(radius: 22)
                        Circle()
                            .strokeBorder(
                                LinearGradient(colors: [accent, accent.opacity(0.35), accent],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 2)
                            .frame(width: 96, height: 96)
                        Image(systemName: iconName)
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(accent)
                            .shadow(color: accent.opacity(0.95), radius: pulse ? 22 : 12)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }

                    // TITLE
                    VStack(spacing: 8) {
                        Text("HEADLOCK ZENIS")
                            .font(.system(size: 14, weight: .heavy)).tracking(4)
                            .foregroundStyle(Color.white.opacity(0.7))
                        Text(titleText)
                            .font(.system(size: 20, weight: .heavy)).tracking(2)
                            .foregroundStyle(accent)
                            .shadow(color: accent.opacity(0.8), radius: 16)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        Text(info.patchName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                            .padding(.horizontal, 20)
                    }

                    // ERROR MESSAGE (nếu có)
                    if let errMsg = info.errorMessage, !errMsg.isEmpty, !info.success {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(accent)
                                Text("LÝ DO")
                                    .font(.system(size: 10, weight: .heavy)).tracking(2)
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }
                            Text(errMsg)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(accent.opacity(0.06)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(accent.opacity(0.45), lineWidth: 1.1)
                        )
                        .shadow(color: accent.opacity(0.3), radius: 16)
                        .padding(.horizontal, 24)
                    }

                    // NOTE CARD (luôn hiện nếu có)
                    if hasNote {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.white)
                                Text("GHI CHÚ")
                                    .font(.system(size: 10, weight: .heavy)).tracking(2)
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }
                            Text(info.note)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.95))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    LinearGradient(colors: [.white, .white.opacity(0.35), .white],
                                                   startPoint: .leading, endPoint: .trailing),
                                    lineWidth: 1.2)
                        )
                        .shadow(color: .white.opacity(0.4), radius: 18)
                        .overlay(shimmerOverlay)
                        .onAppear {
                            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                                shimmer = true
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // HINT (nếu fail)
                    if !info.success {
                        Text("💡 Hãy chắc chắn game đã được cài đặt trên thiết bị, sau đó thử lại.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer(minLength: 20)

                    // CONFIRM BUTTON
                    Button {
                        SoundFX.tap()
                        onDismiss()
                    } label: {
                        Text("ĐÃ HIỂU")
                            .font(.system(size: 15, weight: .heavy)).tracking(3)
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(accent))
                            .overlay(Capsule().stroke(accent, lineWidth: 1))
                            .shadow(color: accent.opacity(0.7), radius: 20)
                            .padding(.horizontal, 40)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, .white.opacity(0.20), .clear],
                           startPoint: .leading, endPoint: .trailing)
            .frame(width: geo.size.width * 0.5)
            .offset(x: shimmer ? geo.size.width : -geo.size.width * 0.5)
            .blendMode(.screen)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .allowsHitTesting(false)
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

    private let autoTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

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
            .onAppear {
                Task { await syncNow() }
            }
            .onReceive(autoTimer) { _ in
                Task { await syncNow() }
            }
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
                .font(.system(size: 20, weight: .heavy, design: .serif))
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
                gameCard(title: "Free Fire Max", prefix: "ffmax_")
                gameCard(title: "Free Fire Thường", prefix: "ffnormal_")
                Text("By Zenith Solitude")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.top, 12)
                    .shadow(color: .white.opacity(0.4), radius: 12)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 40)
        }
        .refreshable { await syncNow() }
    }

    @ViewBuilder
    private func gameCard(title: String, prefix: String) -> some View {
        Button {
            SoundFX.menu()
            selectedGame = GameSelection(title: title, prefix: prefix)
        } label: {
            NeonCard {
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
                        MenuCapsule()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .buttonStyle(.plain)
    }

    private func syncNow() async {
        guard !isAutoSyncing else { return }
        await MainActor.run { isAutoSyncing = true }
        await SyncEngine.shared.run(store: store)
        await MainActor.run { isAutoSyncing = false }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SYNC ENGINE
// ═══════════════════════════════════════════════════════════════
final class SyncEngine {
    static let shared = SyncEngine()
    private var isRunning = false
    private init() {}

    func run(store: PatchProjectStore) async {
        if isRunning { return }
        isRunning = true
        defer { isRunning = false }

        guard let remotes = await fetchRemotes() else { return }
        let existing = PatchMetaStore.allRemoteNames()

        for remote in remotes {
            if existing.contains(remote.filename) { continue }
            guard let url = URL(string: remote.url) else { continue }
            await importAndTag(remote: remote, url: url, store: store)
        }

        let items = await MainActor.run { store.items }
        await reMatchOrphans(items: items, remotes: remotes)

        await MainActor.run { store.reload() }
    }

    private func fetchRemotes() async -> [RemoteFileLite]? {
        do {
            guard let url = URL(string: "https://solitudepremium.click/ipa/proxy/list.php") else {
                return nil
            }
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 20
            let (data, _) = try await URLSession.shared.data(for: req)

            struct Wire: Decodable {
                let filename: String
                let gameType: String
                let folder: String?
                let displayName: String?
                let tag: String?
                let note: String?
                let url: String
            }
            let wire = try JSONDecoder().decode([Wire].self, from: data)
            return wire.map { w in
                RemoteFileLite(
                    filename:    w.filename,
                    folder:      w.folder ?? "Chung",
                    tag:         w.tag ?? "FREE",
                    displayName: w.displayName ?? "",
                    note:        w.note ?? "",
                    url:         w.url
                )
            }
        } catch {
            print("Fetch error: \(error.localizedDescription)")
            return nil
        }
    }

    private func importAndTag(remote: RemoteFileLite, url: URL, store: PatchProjectStore) async {
        let before = await MainActor.run {
            Set(store.items.map { $0.packageURL.lastPathComponent })
        }
        await MainActor.run {
            store.importPackage(from: .remote(url))
        }
        for attempt in 0..<60 {
            try? await Task.sleep(nanoseconds: 250_000_000)
            await MainActor.run { store.reload() }
            let after = await MainActor.run {
                Set(store.items.map { $0.packageURL.lastPathComponent })
            }
            let diff = after.subtracting(before)
            if let newFile = diff.first {
                print("✅ Matched \(remote.filename) → \(newFile) at attempt \(attempt)")
                let meta = PatchMeta(
                    remoteName:  remote.filename,
                    folder:      remote.folder,
                    tag:         remote.tag,
                    displayName: remote.displayName,
                    note:        remote.note
                )
                PatchMetaStore.set(meta, forLocal: newFile)
                return
            }
        }
        print("⚠️ Timeout: \(remote.filename)")
    }

    private func reMatchOrphans(items: [PatchLibraryItem], remotes: [RemoteFileLite]) async {
        for item in items {
            let localName = item.packageURL.lastPathComponent
            if PatchMetaStore.get(forLocal: localName) != nil { continue }

            let internalName = item.project?.name ?? ""
            let internalSlug = normalize(internalName)
            if !internalSlug.isEmpty {
                for r in remotes {
                    let rSlug = normalize(r.displayName)
                    if rSlug.isEmpty { continue }
                    if rSlug.contains(internalSlug) || internalSlug.contains(rSlug) {
                        let meta = PatchMeta(
                            remoteName:  r.filename,
                            folder:      r.folder,
                            tag:         r.tag,
                            displayName: r.displayName,
                            note:        r.note
                        )
                        PatchMetaStore.set(meta, forLocal: localName)
                        break
                    }
                }
            }
        }
    }

    private func normalize(_ s: String) -> String {
        return s.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
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
    @State private var activationInfo: ActivationInfo?
    @State private var selectedFolder: String? = nil
    @State private var didInit = false
    @State private var workingFileID: String?
    @State private var renameItem: PatchLibraryItem?
    @State private var renameText: String = ""
    @State private var tagPickerItem: PatchLibraryItem?
    @State private var noteItem: PatchLibraryItem?
    @State private var noteText: String = ""
    @State private var refreshTick: Int = 0

    private let refreshTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) {
                    if !folders.isEmpty { folderTabs }
                    listContent
                }
            }
            .navigationTitle(game.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        SoundFX.tap(); dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
            }
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                Task {
                    await SyncEngine.shared.run(store: store)
                    await MainActor.run { initFirstFolder() }
                }
            }
            .onReceive(refreshTimer) { _ in
                refreshTick &+= 1
                store.reload()
                initFirstFolder()
            }
            .alert(item: $actionAlert) { alert in
                Alert(
                    title: Text(alert.titleKey),
                    message: Text(alert.message(language: language)),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Đổi tên", isPresented: renameBinding) {
                TextField("Tên mới", text: $renameText)
                Button("Huỷ", role: .cancel) { renameItem = nil }
                Button("Lưu") { commitRename() }
            }
            .alert("Ghi chú", isPresented: noteBinding) {
                TextField("Ghi chú", text: $noteText)
                Button("Huỷ", role: .cancel) { noteItem = nil }
                Button("Lưu") { commitNote() }
            }
            .confirmationDialog("Chọn tag", isPresented: tagBinding, titleVisibility: .visible) {
                Button("VIP 👑") { commitTag("VIP") }
                Button("FREE 🛡") { commitTag("FREE") }
                Button("Huỷ", role: .cancel) { tagPickerItem = nil }
            }
            // Sheet kích hoạt — hiện NGAY trong detail view
            .fullScreenCover(item: $activationInfo) { info in
                ActivationNoteSheet(info: info) {
                    activationInfo = nil
                }
            }
        }
    }

    private func initFirstFolder() {
        guard !didInit, let first = folders.first else { return }
        selectedFolder = first
        didInit = true
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
        guard let sel = selectedFolder else { return gameItems }
        return gameItems.filter { folderName(for: $0) == sel }
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

    private var folderTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(folders, id: \.self) { f in
                    FolderTab(title: f, isActive: selectedFolder == f) {
                        SoundFX.tap()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedFolder = f
                        }
                    }
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
        let name = displayName(for: item)
        PatchRow(
            isApplied: isApplied,
            isWorking: workingFileID == item.id.uuidString,
            displayName: name,
            tag: currentTag(for: item),
            note: currentNote(for: item),
            onToggle: { nv in
                if nv { SoundFX.tingTing() } else { SoundFX.tap() }
                togglePatch(item: item, activate: nv)
            },
            onTapTag: { SoundFX.tap(); tagPickerItem = item },
            onRename: { SoundFX.tap(); renameItem = item; renameText = name },
            onEditNote: { SoundFX.tap(); noteItem = item; noteText = currentNote(for: item) }
        )
    }

    private func localKey(for item: PatchLibraryItem) -> String {
        return item.packageURL.lastPathComponent
    }

    private func meta(for item: PatchLibraryItem) -> PatchMeta? {
        return PatchMetaStore.get(forLocal: localKey(for: item))
    }

    private func displayName(for item: PatchLibraryItem) -> String {
        if let m = meta(for: item), !m.displayName.isEmpty { return m.displayName }
        if let n = item.project?.name, !n.isEmpty { return n }
        return item.packageURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_VIP", with: "")
            .replacingOccurrences(of: "_FREE", with: "")
            .replacingOccurrences(of: "ffmax_", with: "")
            .replacingOccurrences(of: "ffnormal_", with: "")
    }

    private func currentTag(for item: PatchLibraryItem) -> String {
        if let m = meta(for: item), !m.tag.isEmpty { return m.tag }
        return item.packageURL.deletingPathExtension().lastPathComponent
            .hasSuffix("_VIP") ? "VIP" : "FREE"
    }

    private func currentNote(for item: PatchLibraryItem) -> String {
        return meta(for: item)?.note ?? ""
    }

    private func folderName(for item: PatchLibraryItem) -> String {
        if let m = meta(for: item), !m.folder.isEmpty { return m.folder }
        let fname = item.packageURL.lastPathComponent
        if let range = fname.range(of: #"^ZENITH_([a-zA-Z0-9]+)_"#, options: .regularExpression) {
            let matched = String(fname[range])
                .replacingOccurrences(of: "ZENITH_", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            if !matched.isEmpty { return matched.uppercased() }
        }
        let comps = item.packageURL.pathComponents.filter { $0 != "/" }
        if let idx = comps.firstIndex(where: { $0 == "ffmax" || $0 == "ffnormal" }),
           idx + 2 < comps.count {
            return comps[idx + 1]
        }
        return "Chung"
    }

    private func commitRename() {
        guard let item = renameItem else { return }
        let t = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { renameItem = nil; return }
        let key = localKey(for: item)
        if var m = PatchMetaStore.get(forLocal: key) {
            m.displayName = t; m.nameOverride = true
            PatchMetaStore.set(m, forLocal: key)
        } else {
            let newMeta = PatchMeta(
                remoteName: key, folder: folderName(for: item),
                tag: currentTag(for: item), displayName: t,
                note: currentNote(for: item), nameOverride: true
            )
            PatchMetaStore.set(newMeta, forLocal: key)
        }
        store.reload()
        renameItem = nil
    }

    private func commitTag(_ tag: String) {
        guard let item = tagPickerItem else { return }
        let key = localKey(for: item)
        if var m = PatchMetaStore.get(forLocal: key) {
            m.tag = tag; m.tagOverride = true
            PatchMetaStore.set(m, forLocal: key)
        } else {
            let newMeta = PatchMeta(
                remoteName: key, folder: folderName(for: item),
                tag: tag, displayName: displayName(for: item),
                note: currentNote(for: item), tagOverride: true
            )
            PatchMetaStore.set(newMeta, forLocal: key)
        }
        store.reload()
        tagPickerItem = nil
    }

    private func commitNote() {
        guard let item = noteItem else { return }
        let t = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = localKey(for: item)
        if var m = PatchMetaStore.get(forLocal: key) {
            m.note = t; m.noteOverride = true
            PatchMetaStore.set(m, forLocal: key)
        } else {
            let newMeta = PatchMeta(
                remoteName: key, folder: folderName(for: item),
                tag: currentTag(for: item), displayName: displayName(for: item),
                note: t, noteOverride: true
            )
            PatchMetaStore.set(newMeta, forLocal: key)
        }
        store.reload()
        noteItem = nil
    }

    // ⭐️ TOGGLE: Bắt mọi lỗi và show sheet với status tương ứng
    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        workingFileID = item.id.uuidString
        let nameSnapshot = displayName(for: item)
        let noteSnapshot = currentNote(for: item)

        Task.detached(priority: .userInitiated) {
            // Nếu TẮT: chỉ gọi restore, không hiện sheet
            if !activate {
                do {
                    if let r = DevicePatchService.latestReceipt(projectID: item.id) {
                        try DevicePatchService.restore(receipt: r)
                    }
                    await MainActor.run {
                        store.reload()
                        workingFileID = nil
                    }
                } catch {
                    await MainActor.run {
                        workingFileID = nil
                        SoundFX.error()
                        // Nếu restore fail, thông báo qua sheet với success=false
                        activationInfo = ActivationInfo(
                            patchName: nameSnapshot,
                            note: noteSnapshot,
                            success: false,
                            errorMessage: "Không thể tắt patch: \(error.localizedDescription)"
                        )
                    }
                }
                return
            }

            // Nếu BẬT: gọi apply, bắt lỗi
            do {
                guard let p = item.project else {
                    await MainActor.run { workingFileID = nil }
                    return
                }
                _ = try DevicePatchService.apply(project: p)

                // Thành công → sheet xanh
                await MainActor.run {
                    store.reload()
                    workingFileID = nil
                    activationInfo = ActivationInfo(
                        patchName: nameSnapshot,
                        note: noteSnapshot,
                        success: true,
                        errorMessage: nil
                    )
                }
            } catch {
                // ⭐️ THẤT BẠI → sheet đỏ với lý do + note
                await MainActor.run {
                    store.reload()
                    workingFileID = nil
                    SoundFX.error()
                    activationInfo = ActivationInfo(
                        patchName: nameSnapshot,
                        note: noteSnapshot,
                        success: false,
                        errorMessage: error.localizedDescription
                    )
                }
            }
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
                        .onChange(of: password) { _ in store.clearUnlockError() }
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
        if let a = store.unlockErrorArgument { return language.text(key, a) }
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
