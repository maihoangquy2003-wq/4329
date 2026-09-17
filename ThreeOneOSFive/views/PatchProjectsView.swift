import SwiftUI
import UIKit
import ObjectiveC
import UniformTypeIdentifiers
import AudioToolbox

// ═══════════════════════════════════════════════════════════════
// MARK: - SOUND
// ═══════════════════════════════════════════════════════════════
enum SoundFX {
    static func tap()     { AudioServicesPlaySystemSound(1104) }
    static func menu()    { AudioServicesPlaySystemSound(1105) }
    static func error()   { AudioServicesPlaySystemSound(1053) }
    static func success() { AudioServicesPlaySystemSound(1057) }
    static func tingTing() {
        AudioServicesPlaySystemSound(1057)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            AudioServicesPlaySystemSound(1057)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - THEME
// ═══════════════════════════════════════════════════════════════
enum Theme {
    static let bg        = Color.black
    static let surface   = Color(red: 0.043, green: 0.043, blue: 0.043)
    static let surfaceHi = Color(red: 0.078, green: 0.078, blue: 0.078)
    static let ink       = Color.white
    static let inkSoft   = Color.white.opacity(0.7)
    static let inkMuted  = Color.white.opacity(0.4)
    static let line      = Color.white
    static let lineHi    = Color.white.opacity(0.9)
    static let lineMid   = Color.white.opacity(0.35)
    static let gold      = Color(red: 0.850, green: 0.700, blue: 0.400)
    static let danger    = Color(red: 1.0, green: 0.32, blue: 0.32)
}

// ═══════════════════════════════════════════════════════════════
// MARK: - INSTALLER ALERT BLOCKER (Swizzling)
// ═══════════════════════════════════════════════════════════════
enum InstallerAlertBlocker {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true

        DispatchQueue.main.async {
            let orig = #selector(UIViewController.present(_:animated:completion:))
            let new  = #selector(UIViewController.hl_block_present(_:animated:completion:))

            guard let m1 = class_getInstanceMethod(UIViewController.self, orig),
                  let m2 = class_getInstanceMethod(UIViewController.self, new)
            else { return }

            method_exchangeImplementations(m1, m2)
        }
    }

    static func isInstallerAlert(title: String, msg: String) -> Bool {
        let t = title.lowercased()
        let m = msg.lowercased()

        if t == "xong" { return true }
        if t.contains("xong") { return true }
        if m.contains("đã cài đặt gói") { return true }
        if m.contains("cài đặt gói thành công") { return true }
        if m.contains("mở gói trong mục") { return true }
        if m.contains("đã cài đặt") { return true }
        return false
    }

    /// Fallback dismiss bất kỳ UIAlertController nào đang hiện
    static func sweepDismiss() {
        for delay in [0.05, 0.2, 0.5, 1.0, 1.8, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard let scene = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene }).first,
                      let window = scene.windows.first(where: { $0.isKeyWindow })
                        ?? scene.windows.first,
                      let root = window.rootViewController
                else { return }

                var top: UIViewController = root
                while let p = top.presentedViewController { top = p }

                if let alert = top as? UIAlertController,
                   isInstallerAlert(title: alert.title ?? "",
                                    msg: alert.message ?? "") {
                    alert.dismiss(animated: false, completion: nil)
                }
            }
        }
    }
}

extension UIViewController {
    @objc func hl_block_present(_ vc: UIViewController,
                                animated: Bool,
                                completion: (() -> Void)?) {
        if let alert = vc as? UIAlertController,
           InstallerAlertBlocker.isInstallerAlert(title: alert.title ?? "",
                                                  msg: alert.message ?? "") {
            completion?()
            return
        }
        // Gọi lại original (đã bị swizzle) — đúng pattern
        hl_block_present(vc, animated: animated, completion: completion)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - BACKGROUND
// ═══════════════════════════════════════════════════════════════
struct NeonBackgroundView: View {
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            Color.black
            AuroraView()
            VignetteView()
            CosmicFieldView(paused: scenePhase != .active)
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
                     opacity: 0.13, r: geo.size.width * 0.7)
                blob(cx: 0.75 + 0.10 * cos(phase * 0.85),
                     cy: 0.72 + 0.10 * sin(phase * 0.6),
                     opacity: 0.10, r: geo.size.width * 0.8)
            }
            .blur(radius: 60)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: true)) {
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
            colors: [.clear, .clear, Color.black.opacity(0.72)],
            center: .center, startRadius: 0, endRadius: 520
        )
        .allowsHitTesting(false)
    }
}

struct CosmicFieldView: View {
    var paused: Bool = false
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
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for s in stars {
                    let a = 0.18 + 0.55 * sin(t * s.freq + s.phase)
                    let r = CGRect(x: s.x * size.width, y: s.y * size.height,
                                   width: s.s, height: s.s)
                    ctx.fill(Path(ellipseIn: r),
                             with: .color(Color.white.opacity(max(0, a))))
                }
                for p in particles {
                    let total = Double(size.height) + 100
                    let traveled = (t * Double(p.speed))
                        .truncatingRemainder(dividingBy: total)
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
            stars = (0..<55).map { _ in
                Star(x: CGFloat.random(in: 0...1),
                     y: CGFloat.random(in: 0...1),
                     s: CGFloat.random(in: 0.5...2.0),
                     phase: Double.random(in: 0...(2 * .pi)),
                     freq: Double.random(in: 0.5...1.8))
            }
        }
        if particles.isEmpty {
            particles = (0..<25).map { _ in
                Particle(x: CGFloat.random(in: 0...1),
                         s: CGFloat.random(in: 1.0...2.8),
                         speed: CGFloat.random(in: 20...45),
                         opacity: Double.random(in: 0.22...0.75),
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
    var uid: String
    var remoteKey: String
    var remoteName: String
    var gameType: String
    var folder: String
    var tag: String
    var displayName: String
    var note: String
    var tagOverride: Bool
    var nameOverride: Bool
    var noteOverride: Bool
    var orphaned: Bool

    init(uid: String = "",
         remoteKey: String,
         remoteName: String,
         gameType: String,
         folder: String,
         tag: String,
         displayName: String,
         note: String,
         tagOverride: Bool = false,
         nameOverride: Bool = false,
         noteOverride: Bool = false,
         orphaned: Bool = false) {
        self.uid = uid
        self.remoteKey = remoteKey
        self.remoteName = remoteName
        self.gameType = gameType
        self.folder = folder
        self.tag = tag
        self.displayName = displayName
        self.note = note
        self.tagOverride = tagOverride
        self.nameOverride = nameOverride
        self.noteOverride = noteOverride
        self.orphaned = orphaned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid          = (try? c.decode(String.self, forKey: .uid)) ?? ""
        remoteKey    = (try? c.decode(String.self, forKey: .remoteKey)) ?? ""
        remoteName   = (try? c.decode(String.self, forKey: .remoteName)) ?? ""
        gameType     = (try? c.decode(String.self, forKey: .gameType)) ?? "ffnormal"
        folder       = (try? c.decode(String.self, forKey: .folder)) ?? ""
        tag          = (try? c.decode(String.self, forKey: .tag)) ?? "FREE"
        displayName  = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        note         = (try? c.decode(String.self, forKey: .note)) ?? ""
        tagOverride  = (try? c.decode(Bool.self, forKey: .tagOverride)) ?? false
        nameOverride = (try? c.decode(Bool.self, forKey: .nameOverride)) ?? false
        noteOverride = (try? c.decode(Bool.self, forKey: .noteOverride)) ?? false
        orphaned     = (try? c.decode(Bool.self, forKey: .orphaned)) ?? false
    }
}

struct RemoteFileLite {
    let filename: String
    let gameType: String
    let folder: String
    let tag: String
    let displayName: String
    let note: String
    let url: String

    var compositeKey: String { "\(gameType)/\(folder)/\(filename)" }

    var uid: String {
        var h: UInt64 = 1469598103934665603
        for b in compositeKey.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return String(h, radix: 16)
    }
}

struct ActivationInfo: Identifiable {
    let id = UUID()
    let patchName: String
    let tag: String
    let note: String
    let success: Bool
    let errorMessage: String?
}

// ═══════════════════════════════════════════════════════════════
// MARK: - META STORE
// ═══════════════════════════════════════════════════════════════
enum PatchMetaStore {
    private static let key = "patch_meta_v21"

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

    static func set(_ meta: PatchMeta, uid: String) {
        var d = all()
        d[uid] = meta
        save(d)
    }

    static func get(uid: String) -> PatchMeta? {
        all()[uid]
    }

    static func lookup(localName: String) -> PatchMeta? {
        if let uid = LocalMapStore.uid(forLocal: localName),
           let m = all()[uid] {
            return m
        }
        for m in all().values where m.remoteName == localName {
            return m
        }
        let base = (localName as NSString).deletingPathExtension.lowercased()
        for m in all().values {
            let rbase = (m.remoteName as NSString).deletingPathExtension.lowercased()
            if !rbase.isEmpty && rbase == base { return m }
        }
        return nil
    }
}

enum LocalMapStore {
    private static let key = "patch_localmap_v21"

    static func all() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
    }

    static func save(_ d: [String: String]) {
        UserDefaults.standard.set(d, forKey: key)
    }

    static func link(local: String, uid: String) {
        var d = all()
        d[local] = uid
        save(d)
    }

    static func uid(forLocal local: String) -> String? {
        all()[local]
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SMALL COMPONENTS
// ═══════════════════════════════════════════════════════════════
private struct NeonCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.4), .white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.4
                    )
            )
            .shadow(color: .white.opacity(0.10), radius: 14)
            .shadow(color: .white.opacity(0.04), radius: 6)
    }
}

private struct FFLogoView: View {
    var body: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/ipa/free.jpg")) { phase in
            switch phase {
            case .empty:
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceHi)
                    ProgressView().tint(.white)
                }
            case .success(let img):
                img.resizable().scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            case .failure:
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceHi)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 58, height: 58)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white, lineWidth: 1.5)
        )
        .shadow(color: .white.opacity(0.3), radius: 10)
    }
}

private struct AvatarView: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.3),
                              style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                .frame(width: 108, height: 108)
            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: 92, height: 92)
                .shadow(color: .white.opacity(0.5), radius: 10)
            avatarImage
                .frame(width: 78, height: 78)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
        }
        .frame(width: 118, height: 118)
    }

    private var avatarImage: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/ipa/li.jpg")) { phase in
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
                    Theme.surfaceHi
                    Image(systemName: "person.fill")
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            @unknown default:
                EmptyView()
            }
        }
    }
}

private struct ChevronCircle: View {
    var body: some View {
        ZStack {
            Circle().fill(.white).frame(width: 36, height: 36)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.black)
        }
        .shadow(color: .white.opacity(0.55), radius: 10)
    }
}

private struct TagPill: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isVIP ? "crown.fill" : "shield.fill")
                .font(.system(size: 8, weight: .heavy))
            Text(tag)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(isVIP ? Theme.gold : .white)
        .background(
            Capsule().fill(isVIP ? Theme.gold.opacity(0.16) : Color.white.opacity(0.06))
        )
        .overlay(
            Capsule().strokeBorder(
                isVIP ? Theme.gold : Color.white.opacity(0.7),
                lineWidth: 1.2
            )
        )
    }
}

private struct PatchIconView: View {
    let tag: String
    let isApplied: Bool
    private var isVIP: Bool { tag == "VIP" }

    var body: some View {
        ZStack {
            if isApplied {
                AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/ipa/li.jpg")) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Circle().fill(Theme.surfaceHi)
                            ProgressView().tint(.white).scaleEffect(0.7)
                        }
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        ZStack {
                            Circle().fill(Theme.surfaceHi)
                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: .white.opacity(0.45), radius: 10)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isVIP ? Theme.gold.opacity(0.14) : Color.white.opacity(0.06))
                        .frame(width: 52, height: 52)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isVIP ? Theme.gold : Color.white.opacity(0.5),
                            lineWidth: 1.5
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: isVIP ? "crown.fill" : "shield.lefthalf.filled")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(isVIP ? Theme.gold : .white)
                }
            }
        }
    }
}

private struct CustomToggle: View {
    let isOn: Bool
    let disabled: Bool
    let action: (Bool) -> Void
    var body: some View {
        Button {
            guard !disabled else { return }
            action(!isOn)
        } label: {
            ZStack {
                Capsule()
                    .fill(isOn ? Color.white : Color.white.opacity(0.08))
                    .frame(width: 52, height: 30)
                    .overlay(
                        Capsule().strokeBorder(
                            isOn ? .white : Color.white.opacity(0.45),
                            lineWidth: 1.4
                        )
                    )
                    .shadow(color: isOn ? .white.opacity(0.55) : .clear, radius: 10)
                HStack {
                    if isOn {
                        Spacer()
                        Circle()
                            .fill(.black)
                            .frame(width: 22, height: 22)
                            .padding(.trailing, 3)
                    } else {
                        Circle()
                            .fill(.white)
                            .frame(width: 22, height: 22)
                            .padding(.leading, 3)
                        Spacer()
                    }
                }
                .frame(width: 52, height: 30)
            }
            .animation(.spring(response: 0.26, dampingFraction: 0.72), value: isOn)
            .opacity(disabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

private struct FolderPill: View {
    let title: String
    let count: Int
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isActive ? Color.black : Color.white.opacity(0.55))
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1.0)
                    .foregroundStyle(isActive ? .black : .white)
                Text("\(count)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(isActive ? .black.opacity(0.55)
                                    : .white.opacity(0.4))
                    .padding(.leading, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isActive ? Color.white : Color.white.opacity(0.04))
            )
            .overlay(
                Capsule().strokeBorder(
                    isActive ? Color.white : Color.white.opacity(0.28),
                    lineWidth: 1.2
                )
            )
            .shadow(color: isActive ? .white.opacity(0.4) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct PatchCard: View {
    let isApplied: Bool
    let isWorking: Bool
    let displayName: String
    let tag: String
    let note: String
    let onToggle: (Bool) -> Void
    let onTapTag: () -> Void
    let onRename: () -> Void
    let onEditNote: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            PatchIconView(tag: tag, isApplied: isApplied)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(displayName)
                        .font(.system(size: 14.5, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Button(action: onTapTag) {
                        TagPill(tag: tag)
                    }
                    .buttonStyle(.plain)
                }
                if !note.isEmpty {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 2)
                        Text(note)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }

            Spacer(minLength: 4)

            if isWorking {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
                    .frame(width: 52, height: 30)
            } else {
                CustomToggle(isOn: isApplied, disabled: false) { nv in
                    onToggle(nv)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isApplied
                            ? [Color.white.opacity(0.09), Color.white.opacity(0.03)]
                            : [Color.white.opacity(0.03), Color.white.opacity(0.012)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isApplied ? Color.white : Color.white.opacity(0.28),
                    lineWidth: isApplied ? 1.6 : 1.1
                )
        )
        .shadow(color: isApplied ? .white.opacity(0.18) : .black.opacity(0.25),
                radius: isApplied ? 10 : 6,
                y: 3)
        .contextMenu {
            Button(action: onRename) {
                Label("Đổi tên", systemImage: "pencil")
            }
            Button(action: onTapTag) {
                Label("Đổi VIP/FREE", systemImage: "crown")
            }
            Button(action: onEditNote) {
                Label("Sửa ghi chú", systemImage: "note.text")
            }
        }
    }
}

private struct EmptyStateView: View {
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(
                        .white.opacity(0.25),
                        style: StrokeStyle(lineWidth: 1.4, dash: [3, 5])
                    )
                    .frame(width: 74, height: 74)
                Image(systemName: "tray")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SHEET (thành công có note + lỗi)
// ═══════════════════════════════════════════════════════════════
struct ActivationNoteSheet: View {
    let info: ActivationInfo
    let onDismiss: () -> Void

    @State private var pulse = false
    @State private var copied = false

    private var isError: Bool { !info.success }
    private var accent: Color { isError ? Theme.danger : .white }
    private var hasNote: Bool {
        !info.note.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AuroraView().ignoresSafeArea().opacity(0.5)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer(minLength: 40)

                    // ⭐ TOP ICON — avatar khi success, triangle khi lỗi
                    topIcon

                    // ⭐ TITLE
                    titleBlock

                    // Error reason
                    if isError, let errMsg = info.errorMessage, !errMsg.isEmpty {
                        errorBlock(errMsg)
                    }

                    // Note + copy
                    if hasNote {
                        noteBlock
                    }

                    // Close
                    Button {
                        SoundFX.tap()
                        onDismiss()
                    } label: {
                        Text("ĐÃ HIỂU")
                            .font(.system(size: 14, weight: .heavy))
                            .tracking(3)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.white)
                            )
                            .padding(.horizontal, 40)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 50)
                }
            }
        }
    }

    // ⭐ Avatar khi success, triangle đỏ khi lỗi
    private var topIcon: some View {
        Group {
            if isError {
                ZStack {
                    Circle()
                        .strokeBorder(accent.opacity(0.25), lineWidth: 1.5)
                        .frame(width: pulse ? 128 : 106, height: pulse ? 128 : 106)
                    Circle()
                        .fill(accent)
                        .frame(width: 88, height: 88)
                        .shadow(color: accent.opacity(0.5), radius: 20, y: 6)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.8)
                        .repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            } else {
                // ⭐ Avatar tròn với viền trắng khi thành công
                ZStack {
                    Circle()
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 118, height: 118)

                    AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/ipa/li.jpg")) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Circle().fill(Theme.surfaceHi)
                                ProgressView().tint(.white)
                            }
                        case .success(let img):
                            img.resizable().scaledToFill()
                        case .failure:
                            ZStack {
                                Circle().fill(Theme.surfaceHi)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 34, weight: .heavy))
                                    .foregroundStyle(.white)
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: .white.opacity(0.6), radius: 22)
                }
            }
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            Text("HEADLOCK ZENIS")
                .font(.system(size: 11, weight: .heavy))
                .tracking(4.5)
                .foregroundStyle(.white.opacity(0.55))

            if isError {
                Text("KHÔNG KÍCH HOẠT ĐƯỢC")
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.center)
                    .shadow(color: accent.opacity(0.7), radius: 14)
                    .padding(.horizontal, 20)
            } else {
                Text("KÍCH HOẠT THÀNH CÔNG")
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Text(info.patchName)
                .font(.system(size: isError ? 15 : 18, weight: .heavy))
                .tracking(isError ? 0.5 : 1)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 2)

            if !info.tag.isEmpty {
                TagPill(tag: info.tag)
            }
        }
    }

    private func errorBlock(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(accent)
                Text("LÝ DO")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2.2)
                    .foregroundStyle(accent)
            }
            Text(msg)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent.opacity(0.5), lineWidth: 1.3)
        )
        .padding(.horizontal, 24)
    }

    private var noteBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Text("GHI CHÚ")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2.2)
                    .foregroundStyle(.white)
                Spacer()
            }

            Text(info.note)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            .white.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                )

            Button {
                SoundFX.tap()
                UIPasteboard.general.string = info.note
                withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                    copied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                        copied = false
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc.fill")
                        .font(.system(size: 12, weight: .heavy))
                    Text(copied ? "ĐÃ COPY VÀO CLIPBOARD" : "COPY GHI CHÚ")
                        .font(.system(size: 11.5, weight: .heavy))
                        .tracking(1.8)
                }
                .foregroundStyle(copied ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(copied ? Color.white : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white, lineWidth: 1.4)
                )
                .shadow(color: copied ? .white.opacity(0.5) : .clear, radius: 12)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.8), lineWidth: 1.3)
        )
        .padding(.horizontal, 22)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MAIN VIEW
// ═══════════════════════════════════════════════════════════════
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore

    @State private var actionAlert: PatchStoreAlert?
    @State private var selectedGame: GameSelection?
    @State private var isSyncing = false
    @State private var lastSyncDate: Date = .distantPast
    @State private var syncGuard = false

    private let autoTimer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()

    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    init(onOpenSettings: @escaping () -> Void = {},
         onOpenLogs: @escaping () -> Void = {}) {
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
                InstallerAlertBlocker.install()
                store.reload()
                triggerSync(force: true)
            }
            .onReceive(autoTimer) { _ in
                if Date().timeIntervalSince(lastSyncDate) > 12 {
                    triggerSync(force: false)
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    store.reload()
                    triggerSync(force: true)
                }
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
        VStack(spacing: 0) {
            HStack {
                Spacer()
                syncPill
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 4)

            AvatarView()
                .padding(.top, 2)

            Text("ZENITH SOLITUDE")
                .font(.system(size: 21, weight: .black, design: .serif))
                .tracking(3.5)
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.6), radius: 14)
                .padding(.top, 12)

            HStack(spacing: 10) {
                Rectangle().fill(.white.opacity(0.35)).frame(width: 26, height: 1)
                Text("HEADLOCK ZENIS")
                    .font(.system(size: 9.5, weight: .heavy))
                    .tracking(4.2)
                    .foregroundStyle(.white.opacity(0.55))
                Rectangle().fill(.white.opacity(0.35)).frame(width: 26, height: 1)
            }
            .padding(.top, 8)
            .padding(.bottom, 22)
        }
    }

    private var syncPill: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill((isSyncing ? Color.yellow : Color.green).opacity(0.18))
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(isSyncing ? Color.yellow : Color.green)
                    .frame(width: 7, height: 7)
                    .shadow(
                        color: (isSyncing ? Color.yellow : Color.green).opacity(0.9),
                        radius: 6
                    )
            }
            Text(isSyncing ? "ĐANG CẬP NHẬT" : "ĐÃ KẾT NỐI")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 1))
        .animation(.easeInOut(duration: 0.25), value: isSyncing)
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                gameCard(title: "Free Fire Max", subtitle: "PREMIUM EDITION", prefix: "ffmax")
                gameCard(title: "Free Fire Thường", subtitle: "CLASSIC EDITION", prefix: "ffnormal")

                HStack(spacing: 8) {
                    Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
                    Text("BY ZENITH SOLITUDE")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize()
                    Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
                }
                .padding(.horizontal, 40)
                .padding(.top, 22)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 50)
        }
        .refreshable { triggerSync(force: true) }
    }

    private func gameCard(title: String, subtitle: String, prefix: String) -> some View {
        Button {
            SoundFX.menu()
            selectedGame = GameSelection(title: title, prefix: prefix)
        } label: {
            NeonCard {
                HStack(spacing: 14) {
                    FFLogoView()
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.system(size: 16.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(subtitle)
                            .font(.system(size: 9.5, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    ChevronCircle()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
            }
        }
        .buttonStyle(.plain)
    }

    private func triggerSync(force: Bool) {
        guard !syncGuard else { return }
        syncGuard = true
        Task {
            await syncNow(force: force)
            await MainActor.run { syncGuard = false }
        }
    }

    private func syncNow(force: Bool) async {
        if !force {
            let elapsed = Date().timeIntervalSince(lastSyncDate)
            if elapsed < 2.0 { return }
        }
        await MainActor.run { isSyncing = true }
        await SyncEngine.shared.run(store: store)
        await MainActor.run {
            isSyncing = false
            lastSyncDate = Date()
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SYNC ENGINE
// ═══════════════════════════════════════════════════════════════
final class SyncEngine {
    static let shared = SyncEngine()
    private let lock = NSLock()
    private var isRunning = false
    private init() {}

    func run(store: PatchProjectStore) async {
        if isRunning { return }
        isRunning = true
        defer { isRunning = false }

        guard let remotes = await fetchRemotes() else { return }

        var remoteByUID: [String: RemoteFileLite] = [:]
        remoteByUID.reserveCapacity(remotes.count)
        for r in remotes { remoteByUID[r.uid] = r }

        var metaDict = PatchMetaStore.all()
        for (uid, var meta) in metaDict {
            if let remote = remoteByUID[uid] {
                meta.orphaned   = false
                meta.remoteKey  = remote.compositeKey
                meta.remoteName = remote.filename
                meta.gameType   = remote.gameType
                meta.folder     = remote.folder
                if !meta.tagOverride  { meta.tag         = remote.tag }
                if !meta.nameOverride { meta.displayName = remote.displayName }
                if !meta.noteOverride { meta.note        = remote.note }
            } else {
                meta.orphaned = true
            }
            metaDict[uid] = meta
        }
        PatchMetaStore.save(metaDict)

        await MainActor.run { store.reload() }

        let missing = remotes.filter { metaDict[$0.uid] == nil }
        guard !missing.isEmpty else { return }

        for remote in missing {
            await importOne(remote: remote, store: store)
        }

        await MainActor.run { store.reload() }
    }

    private func importOne(remote: RemoteFileLite,
                           store: PatchProjectStore) async {
        guard let url = URL(string: remote.url) else { return }

        let before = await MainActor.run {
            Set(store.items.map { $0.packageURL.lastPathComponent })
        }

        await MainActor.run {
            store.importPackage(from: .remote(url))
        }

        for _ in 0..<900 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run { store.reload() }

            let after = await MainActor.run {
                Set(store.items.map { $0.packageURL.lastPathComponent })
            }
            let newFiles = after.subtracting(before)

            guard let newFile = newFiles.first else { continue }

            lock.lock()
            LocalMapStore.link(local: newFile, uid: remote.uid)

            let meta = PatchMeta(
                uid:         remote.uid,
                remoteKey:   remote.compositeKey,
                remoteName:  remote.filename,
                gameType:    remote.gameType,
                folder:      remote.folder,
                tag:         remote.tag,
                displayName: remote.displayName,
                note:        remote.note,
                orphaned:    false
            )
            PatchMetaStore.set(meta, uid: remote.uid)
            lock.unlock()

            print("✅ \(remote.compositeKey) → local:\(newFile)")
            return
        }

        print("⚠️ Timeout: \(remote.compositeKey)")
    }

    private func fetchRemotes() async -> [RemoteFileLite]? {
        let ts = Int(Date().timeIntervalSince1970)
        guard let url = URL(
            string: "https://solitudepremium.click/ipa/ipa/list.php?t=\(ts)"
        ) else { return nil }

        for attempt in 0..<2 {
            do {
                var req = URLRequest(url: url)
                req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                req.timeoutInterval = 12
                req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                req.setValue("no-cache", forHTTPHeaderField: "Pragma")
                req.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")

                let (data, _) = try await URLSession.shared.data(for: req)

                struct Wire: Decodable {
                    let uid: String?
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
                        gameType:    w.gameType,
                        folder:      w.folder      ?? "Chung",
                        tag:         w.tag         ?? "FREE",
                        displayName: w.displayName ?? "",
                        note:        w.note        ?? "",
                        url:         w.url
                    )
                }
            } catch {
                print("Fetch \(attempt) failed: \(error.localizedDescription)")
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
        return nil
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var activationInfo: ActivationInfo?
    @State private var selectedFolder: String? = nil
    @State private var workingFileID: String? = nil
    @State private var renameItem: PatchLibraryItem?
    @State private var renameText: String = ""
    @State private var tagPickerItem: PatchLibraryItem?
    @State private var noteItem: PatchLibraryItem?
    @State private var noteText: String = ""
    @State private var refreshTick: Int = 0
    @State private var didInitialSync = false

    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) {
                    topBar
                    folderBar
                    listContent
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                InstallerAlertBlocker.install()
                store.reload()
                syncFolders()
                guard !didInitialSync else { return }
                didInitialSync = true
                Task {
                    await SyncEngine.shared.run(store: store)
                    await MainActor.run {
                        store.reload()
                        refreshTick &+= 1
                        syncFolders()
                    }
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    Task {
                        await SyncEngine.shared.run(store: store)
                        await MainActor.run {
                            store.reload()
                            refreshTick &+= 1
                            syncFolders()
                        }
                    }
                }
            }
            .onReceive(refreshTimer) { _ in
                refreshTick &+= 1
                store.reload()
                syncFolders()
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
            .confirmationDialog("Chọn tag",
                                isPresented: tagBinding,
                                titleVisibility: .visible) {
                Button("VIP 👑") { commitTag("VIP") }
                Button("FREE 🛡") { commitTag("FREE") }
                Button("Huỷ", role: .cancel) { tagPickerItem = nil }
            }
            .fullScreenCover(item: $activationInfo) { info in
                ActivationNoteSheet(info: info) {
                    activationInfo = nil
                }
            }
        }
    }

    // ⭐ Ẩn dòng "1 PATCH · 1 FOLDER" khi chỉ có 1 patch 1 folder
    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                SoundFX.tap()
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.4))
                        .shadow(color: .white.opacity(0.25), radius: 8)
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(game.title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)

                if displayedItems.count > 1 || folders.count > 1 {
                    Text("\(displayedItems.count) PATCH · \(folders.count) FOLDER")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var folderBar: some View {
        if folders.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(folders, id: \.self) { f in
                        FolderPill(
                            title: f,
                            count: gameItems.filter { folderName(for: $0) == f }.count,
                            isActive: selectedFolder == f
                        ) {
                            SoundFX.tap()
                            withAnimation(.spring(response: 0.32,
                                                 dampingFraction: 0.75)) {
                                selectedFolder = f
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
            }
            .padding(.bottom, 14)
        }
    }

    private func syncFolders() {
        let currentFolders = folders
        if currentFolders.isEmpty {
            selectedFolder = nil
            return
        }
        if let sel = selectedFolder, currentFolders.contains(sel) {
            return
        }
        selectedFolder = currentFolders.first
    }

    private var gameItems: [PatchLibraryItem] {
        _ = refreshTick
        return store.items.filter { item in
            let name = item.packageURL.lastPathComponent
            let meta = PatchMetaStore.lookup(localName: name)

            if let m = meta, !m.gameType.isEmpty {
                if m.orphaned { return false }
                return m.gameType == game.prefix
            }

            let isMax = name.hasPrefix("ffmax_")
            let isNormal = name.hasPrefix("ffnormal_")
            let isPlain = !isMax && !isNormal
            if game.prefix == "ffmax" { return isMax }
            return isNormal || isPlain
        }
    }

    private var folders: [String] {
        let names = gameItems
            .map { folderName(for: $0) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var unique: [String] = []
        for n in names {
            if !unique.contains(n) { unique.append(n) }
        }
        return unique.sorted()
    }

    private var displayedItems: [PatchLibraryItem] {
        if folders.count <= 1 {
            return gameItems
        }
        guard let sel = selectedFolder else { return [] }
        return gameItems.filter { folderName(for: $0) == sel }
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renameItem != nil },
            set: { if !$0 { renameItem = nil } }
        )
    }

    private var tagBinding: Binding<Bool> {
        Binding(
            get: { tagPickerItem != nil },
            set: { if !$0 { tagPickerItem = nil } }
        )
    }

    private var noteBinding: Binding<Bool> {
        Binding(
            get: { noteItem != nil },
            set: { if !$0 { noteItem = nil } }
        )
    }

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            if displayedItems.isEmpty {
                EmptyStateView(
                    message: folders.isEmpty
                        ? "Chưa có folder nào.\nĐang đồng bộ dữ liệu từ server..."
                        : "Folder này chưa có patch nào."
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(displayedItems) { item in
                        patchRow(item: item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
    }

    private func patchRow(item: PatchLibraryItem) -> some View {
        let receipt = DevicePatchService.latestReceipt(projectID: item.id)
        let isApplied = (receipt != nil)
        let name = displayName(for: item)
        return PatchCard(
            isApplied: isApplied,
            isWorking: workingFileID == item.id.uuidString,
            displayName: name,
            tag: currentTag(for: item),
            note: currentNote(for: item),
            onToggle: { nv in
                if nv { SoundFX.tingTing() } else { SoundFX.tap() }
                togglePatch(item: item, activate: nv)
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
                noteText = currentNote(for: item)
            }
        )
    }

    private func localKey(for item: PatchLibraryItem) -> String {
        item.packageURL.lastPathComponent
    }

    private func meta(for item: PatchLibraryItem) -> PatchMeta? {
        PatchMetaStore.lookup(localName: localKey(for: item))
    }

    private func displayName(for item: PatchLibraryItem) -> String {
        if let m = meta(for: item), !m.displayName.isEmpty {
            return m.displayName
        }
        if let n = item.project?.name, !n.isEmpty {
            return n
        }
        return item.packageURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_VIP", with: "")
            .replacingOccurrences(of: "_FREE", with: "")
            .replacingOccurrences(of: "ffmax_", with: "")
            .replacingOccurrences(of: "ffnormal_", with: "")
    }

    private func currentTag(for item: PatchLibraryItem) -> String {
        if let m = meta(for: item), !m.tag.isEmpty {
            return m.tag
        }
        return item.packageURL.deletingPathExtension().lastPathComponent
            .hasSuffix("_VIP") ? "VIP" : "FREE"
    }

    private func currentNote(for item: PatchLibraryItem) -> String {
        meta(for: item)?.note ?? ""
    }

    private func folderName(for item: PatchLibraryItem) -> String {
        if let m = meta(for: item), !m.folder.isEmpty {
            return m.folder
        }

        let fname = item.packageURL.lastPathComponent
        if let range = fname.range(
            of: #"^ZENITH_([a-zA-Z0-9]+)_"#,
            options: .regularExpression
        ) {
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

        return "CHƯA PHÂN LOẠI"
    }

    private func commitRename() {
        guard let item = renameItem else { return }
        let t = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else {
            renameItem = nil
            return
        }
        let localName = localKey(for: item)
        guard let uid = LocalMapStore.uid(forLocal: localName),
              var m = PatchMetaStore.get(uid: uid) else {
            renameItem = nil
            return
        }
        m.displayName = t
        m.nameOverride = true
        PatchMetaStore.set(m, uid: uid)
        store.reload()
        renameItem = nil
    }

    private func commitTag(_ tag: String) {
        guard let item = tagPickerItem else { return }
        let localName = localKey(for: item)
        guard let uid = LocalMapStore.uid(forLocal: localName),
              var m = PatchMetaStore.get(uid: uid) else {
            tagPickerItem = nil
            return
        }
        m.tag = tag
        m.tagOverride = true
        PatchMetaStore.set(m, uid: uid)
        store.reload()
        tagPickerItem = nil
    }

    private func commitNote() {
        guard let item = noteItem else { return }
        let t = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let localName = localKey(for: item)
        guard let uid = LocalMapStore.uid(forLocal: localName),
              var m = PatchMetaStore.get(uid: uid) else {
            noteItem = nil
            return
        }
        m.note = t
        m.noteOverride = true
        PatchMetaStore.set(m, uid: uid)
        store.reload()
        noteItem = nil
    }

    // ⭐ TOGGLE — 3 tính năng:
    //    1. Tắt các patch khác cùng folder trước khi bật
    //    2. Chặn popup "Xong" bằng blocker + sweep
    //    3. Hiện sheet có note + avatar khi thành công
    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        workingFileID = item.id.uuidString
        let nameSnap = displayName(for: item)
        let tagSnap = currentTag(for: item)
        let noteSnap = currentNote(for: item)
        let targetFolder = folderName(for: item)
        let gamePrefix = game.prefix

        // ⭐ Tìm các patch khác đang active trong CÙNG FOLDER + CÙNG GAME
        let conflictIDs: [UUID] = activate ? store.items.compactMap { other in
            guard other.id != item.id else { return nil }

            let otherName = other.packageURL.lastPathComponent
            let otherMeta = PatchMetaStore.lookup(localName: otherName)

            // Xác định game của patch kia
            let otherGame: String
            if let m = otherMeta, !m.gameType.isEmpty {
                otherGame = m.gameType
            } else if otherName.hasPrefix("ffmax_") {
                otherGame = "ffmax"
            } else if otherName.hasPrefix("ffnormal_") {
                otherGame = "ffnormal"
            } else {
                otherGame = "ffnormal"
            }
            guard otherGame == gamePrefix else { return nil }

            // Xác định folder của patch kia
            let otherFolder: String
            if let m = otherMeta, !m.folder.isEmpty {
                otherFolder = m.folder
            } else {
                otherFolder = "CHƯA PHÂN LOẠI"
            }
            guard otherFolder == targetFolder else { return nil }

            // Đang active?
            guard DevicePatchService.latestReceipt(projectID: other.id) != nil else {
                return nil
            }
            return other.id
        } : []

        Task.detached(priority: .userInitiated) {

            // ⭐ BƯỚC 1: Tắt tất cả patch conflict trong cùng folder
            for cid in conflictIDs {
                if let r = DevicePatchService.latestReceipt(projectID: cid) {
                    try? DevicePatchService.restore(receipt: r)
                }
            }

            // ⭐ BƯỚC 2: Xử lý toggle
            if !activate {
                do {
                    if let r = DevicePatchService.latestReceipt(projectID: item.id) {
                        try DevicePatchService.restore(receipt: r)
                    }
                    InstallerAlertBlocker.sweepDismiss()
                    await MainActor.run {
                        store.reload()
                        workingFileID = nil
                    }
                } catch {
                    await MainActor.run {
                        workingFileID = nil
                        SoundFX.error()
                        activationInfo = ActivationInfo(
                            patchName: nameSnap,
                            tag: tagSnap,
                            note: noteSnap,
                            success: false,
                            errorMessage: "Không thể tắt: \(error.localizedDescription)"
                        )
                    }
                }
                return
            }

            do {
                guard let p = item.project else {
                    print("❌ project nil: \(item.packageURL)")
                    await MainActor.run { workingFileID = nil }
                    return
                }

                // Chặn popup từ trước khi apply
                InstallerAlertBlocker.sweepDismiss()

                _ = try DevicePatchService.apply(project: p)

                // Chặn tiếp sau khi apply (alert có thể show trễ)
                InstallerAlertBlocker.sweepDismiss()

                await MainActor.run {
                    store.reload()
                    workingFileID = nil
                    SoundFX.success()

                    // ⭐ Hiện sheet khi CÓ NOTE — để user copy ghi chú
                    if !noteSnap.trimmingCharacters(in: .whitespaces).isEmpty {
                        activationInfo = ActivationInfo(
                            patchName: nameSnap,
                            tag: tagSnap,
                            note: noteSnap,
                            success: true,
                            errorMessage: nil
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    store.reload()
                    workingFileID = nil
                    SoundFX.error()
                    activationInfo = ActivationInfo(
                        patchName: nameSnap,
                        tag: tagSnap,
                        note: noteSnap,
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
                    Button(language.text("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("patch.unlock"), action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }

    private func errorText(_ key: String) -> String {
        if let a = store.unlockErrorArgument {
            return language.text(key, a)
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
            .sheet(
                item: $store.passwordRequest,
                onDismiss: store.cancelUnlock
            ) { request in
                PatchUnlockView(store: store, request: request)
            }
    }
}

extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View {
        modifier(PatchStorePresentationModifier(store: store))
    }
}
