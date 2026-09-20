import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

// ═══════════════════════════════════════════════════════════════
// MARK: - SOUND FX
// ═══════════════════════════════════════════════════════════════
enum SoundFX {
    static func tap()      { AudioServicesPlaySystemSound(1104) }
    static func menu()     { AudioServicesPlaySystemSound(1105) }
    static func error()    { AudioServicesPlaySystemSound(1053) }
    static func success()  { AudioServicesPlaySystemSound(1057) }
    static func tingTing() {
        AudioServicesPlaySystemSound(1057)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            AudioServicesPlaySystemSound(1057)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - KẺ HỦY DIỆT ALERT MẶC ĐỊNH (CHẶN TRIỆT ĐỂ 100% BẢNG "XONG")
// ═══════════════════════════════════════════════════════════════
enum AlertInterceptor {
    private static var killerTimer: Timer?
    
    static func startNuking() {
        killerTimer?.invalidate()
        killerTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            nukeAlert()
        }
        if let timer = killerTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    static func stopNuking() {
        killerTimer?.invalidate()
        killerTimer = nil
    }
    
    private static func nukeAlert() {
        DispatchQueue.main.async {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows {
                    var topVC = window.rootViewController
                    while let presented = topVC?.presentedViewController {
                        topVC = presented
                    }
                    if let alert = topVC as? UIAlertController {
                        let t = alert.title ?? ""
                        let m = alert.message ?? ""
                        if t.contains("Xong") || t.contains("Success") || t.contains("Thành công") || m.contains("thành công") || m.contains("successfully") || m.contains("Done") {
                            alert.dismiss(animated: false, completion: nil)
                        }
                    }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MAX SHIELD (MÀN HÌNH CHỜ CAO CẤP)
// ═══════════════════════════════════════════════════════════════
final class MaxShield {
    static let shared = MaxShield()
    private var win: UIWindow?
    private var timer: Timer?; private var hideTimer: Timer?
    private init() {}

    func activate(duration: TimeInterval = 10.0) {
        AlertInterceptor.startNuking()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.deactivate()
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
            let w = UIWindow(windowScene: scene)
            w.windowLevel = UIWindow.Level.alert + 999999
            w.backgroundColor = .black
            w.rootViewController = UIHostingController(rootView: ShieldView())
            w.rootViewController?.view.backgroundColor = .clear
            w.makeKeyAndVisible()
            self.win = w

            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in w.isHidden = false; w.alpha = 1 }
            if let t = self.timer { RunLoop.main.add(t, forMode: .common) }
            self.hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in self.deactivate() }
        }
    }
    
    func deactivate() {
        AlertInterceptor.stopNuking()
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate(); self?.timer = nil
            self?.hideTimer?.invalidate(); self?.hideTimer = nil
            self?.win?.isHidden = true; self?.win = nil
        }
    }
}

private struct ShieldView: View {
    @State private var pulse = false; @State private var dots = ""
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack {
                    Circle().strokeBorder(Color.blue.opacity(0.3), lineWidth: 2).frame(width: 140, height: 140).scaleEffect(pulse ? 1.15 : 0.92)
                    Circle().fill(Color.blue.opacity(0.1)).frame(width: 100, height: 100).blur(radius: 10)
                    ProgressView().tint(.white).scaleEffect(1.6)
                }
                VStack(spacing: 10) {
                    Text("ZENITH CORE").font(.system(size: 11, weight: .heavy)).tracking(4.5).foregroundStyle(.blue.opacity(0.8))
                    Text("ĐANG ÁP DỤNG PATCH\(dots)").font(.system(size: 16, weight: .heavy)).tracking(2.5).foregroundStyle(.white)
                    Text("Hệ thống đang thiết lập tệp lõi an toàn").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.4)).padding(.top, 4)
                }
            }
        }.onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in dots = String(repeating: ".", count: (dots.count + 1) % 4) }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - THEME & GIAO DIỆN CYBERPUNK / NEON DARK
// ═══════════════════════════════════════════════════════════════
enum Theme {
    static let bg         = Color(red: 0.03, green: 0.03, blue: 0.05)
    static let surface    = Color(red: 0.08, green: 0.09, blue: 0.13)
    static let surfaceHi  = Color(red: 0.14, green: 0.16, blue: 0.22)
    static let borderDim  = Color.blue.opacity(0.2)
    static let neonBlue   = Color(red: 0.2, green: 0.6, blue: 1.0)
}

struct NeonBackgroundView: View {
    var body: some View {
        ZStack {
            Theme.bg
            LinearGradient(colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.05), Color.clear], startAngle: .topLeading, endAngle: .bottomTrailing).ignoresSafeArea()
        }.ignoresSafeArea()
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MODELS
// ═══════════════════════════════════════════════════════════════
struct GameSelection: Identifiable, Hashable { let id = UUID(); let title: String; let prefix: String }

struct PatchMeta: Codable {
    var uid: String; var localName: String; var remoteName: String; var gameType: String; var folder: String; var tag: String; var displayName: String; var note: String
    init(uid: String="", localName: String="", remoteName: String="", gameType: String="", folder: String="", tag: String="FREE", displayName: String="", note: String="") {
        self.uid = uid; self.localName = localName; self.remoteName = remoteName; self.gameType = gameType; self.folder = folder; self.tag = tag; self.displayName = displayName; self.note = note
    }
}

struct RemoteFileLite {
    let uid: String, filename: String, gameType: String, folder: String, tag: String, displayName: String, note: String, url: String
    init(filename: String, gameType: String, folder: String, tag: String, displayName: String, note: String, url: String) {
        self.filename = filename; self.gameType = gameType; self.folder = folder; self.tag = tag; self.displayName = displayName; self.note = note; self.url = url
        let key = "\(gameType)/\(folder)/\(filename)"
        var h: UInt64 = 1469598103934665603; for b in key.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        self.uid = String(h, radix: 16)
    }
}

struct ActivationInfo: Identifiable, Equatable {
    let id = UUID(); let patchName: String; let tag: String; let note: String; let success: Bool; let errorMessage: String?
}

enum PatchMetaStore {
    private static let key = "patch_meta_v86"
    static func all() -> [String: PatchMeta] { guard let d = UserDefaults.standard.data(forKey: key), let x = try? JSONDecoder().decode([String: PatchMeta].self, from: d) else { return [:] }; return x }
    static func save(_ d: [String: PatchMeta]) { if let x = try? JSONEncoder().encode(d) { UserDefaults.standard.set(x, forKey: key) } }
    static func set(_ m: PatchMeta, localName: String) { var d = all(); d[localName] = m; save(d) }
    static func get(localName: String) -> PatchMeta? { all()[localName] }
}

enum GameTypeHelper {
    static let allPrefixes = ["ffmax", "ffnormal", "silent_ffmax", "silent_ffnormal"]
    static func prefixOf(_ item: PatchLibraryItem) -> String {
        let name = item.packageURL.lastPathComponent
        for p in allPrefixes.sorted(by: { $0.count > $1.count }) where name.hasPrefix("\(p)_") { return p }
        if let m = PatchMetaStore.get(localName: name), !m.gameType.isEmpty { return m.gameType }
        let c = item.packageURL.pathComponents
        if c.contains("silent") { return c.contains("ffmax") ? "silent_ffmax" : "silent_ffnormal" }
        return c.contains("ffmax") ? "ffmax" : "ffnormal"
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - UI COMPONENTS
// ═══════════════════════════════════════════════════════════════
private struct GlowCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface).shadow(color: Color.blue.opacity(0.08), radius: 12, y: 5))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.borderDim, lineWidth: 1.2))
    }
}

enum AvatarShape { case circle, roundedSquare }
private struct AvatarShapeModifier: ViewModifier {
    let shape: AvatarShape; let corner: CGFloat
    func body(content: Content) -> some View {
        switch shape {
        case .circle: content.clipShape(Circle()).overlay(Circle().strokeBorder(Theme.neonBlue.opacity(0.6), lineWidth: 1.5))
        case .roundedSquare: content.clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous)).overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(Theme.neonBlue.opacity(0.6), lineWidth: 1.5))
        }
    }
}

private struct ServerAvatarView: View {
    let size: CGFloat; var shape: AvatarShape = .circle; var corner: CGFloat = 16
    var body: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/ipa/liii.jpg")) { p in
            switch p {
            case .empty: ZStack { fill; ProgressView().tint(.blue).scaleEffect(0.8) }
            case .success(let img): img.resizable().scaledToFill()
            case .failure: ZStack { fill; Image(systemName: "person.fill").font(.system(size: size*0.4)).foregroundStyle(Theme.neonBlue) }
            @unknown default: EmptyView()
            }
        }.frame(width: size, height: size).modifier(AvatarShapeModifier(shape: shape, corner: corner))
    }
    @ViewBuilder private var fill: some View { switch shape { case .circle: Circle().fill(Theme.surfaceHi); case .roundedSquare: RoundedRectangle(cornerRadius: corner, style: .continuous).fill(Theme.surfaceHi) } }
}

private struct AvatarView: View {
    @State private var rotate = false; @State private var pulse = false
    var body: some View {
        ZStack {
            Circle().fill(Theme.neonBlue.opacity(0.15)).frame(width: pulse ? 134 : 118, height: pulse ? 134 : 118).blur(radius: 20)
            Circle().strokeBorder(Theme.neonBlue.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 8])).frame(width: 124, height: 124).rotationEffect(.degrees(rotate ? 360 : 0))
            Circle().strokeBorder(Theme.neonBlue, lineWidth: 2).frame(width: 98, height: 98)
            ServerAvatarView(size: 84, shape: .circle)
        }
        .frame(width: 140, height: 140)
        .onAppear { withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) { rotate = true }; withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

private struct GameLogoView: View {
    let imageURL: String
    var body: some View {
        AsyncImage(url: URL(string: imageURL)) { p in
            switch p {
            case .empty: ZStack { RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceHi); ProgressView().tint(.blue).scaleEffect(0.8) }
            case .success(let img): img.resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            case .failure: ZStack { RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceHi); Image(systemName: "flame.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.neonBlue) }
            @unknown default: EmptyView()
            }
        }.frame(width: 62, height: 62).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.neonBlue.opacity(0.6), lineWidth: 1.5))
    }
}

private struct ChevronCircle: View {
    var body: some View { ZStack { Circle().fill(Theme.neonBlue).frame(width: 34, height: 34).shadow(color: Theme.neonBlue.opacity(0.5), radius: 8); Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy)).foregroundStyle(.black) } }
}

private struct TagPill: View {
    let tag: String; private var isVIP: Bool { tag == "VIP" }
    var body: some View {
        HStack(spacing: 4) { Image(systemName: isVIP ? "crown.fill" : "shield.fill").font(.system(size: 8, weight: .heavy)); Text(tag).font(.system(size: 9, weight: .heavy)).tracking(1.0) }
        .padding(.horizontal, 10).padding(.vertical, 4).foregroundStyle(isVIP ? .black : Theme.neonBlue).background(Capsule().fill(isVIP ? Color.yellow : Theme.neonBlue.opacity(0.15))).overlay(Capsule().strokeBorder(isVIP ? Color.yellow : Theme.neonBlue.opacity(0.5), lineWidth: 1))
    }
}

private struct PatchCard: View {
    let isApplied: Bool; let isWorking: Bool; let displayName: String; let tag: String; let note: String
    let onToggle: (Bool) -> Void; let onShowNote: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(isApplied ? Theme.neonBlue.opacity(0.2) : Theme.surfaceHi).frame(width: 54, height: 54)
                RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(isApplied ? Theme.neonBlue : Theme.borderDim, lineWidth: 1.5).frame(width: 54, height: 54)
                Image(systemName: isApplied ? "checkmark.shield.fill" : "shield.slash.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(isApplied ? Theme.neonBlue : .white.opacity(0.6))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(displayName).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                    TagPill(tag: tag)
                }
                if !note.isEmpty {
                    Button(action: onShowNote) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.neonBlue)
                            Text(note).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                        }
                    }.buttonStyle(.plain)
                }
            }
            Spacer(minLength: 4)
            
            if isWorking {
                ProgressView().tint(Theme.neonBlue).scaleEffect(0.9).frame(width: 58, height: 32)
            } else {
                CustomToggle(isOn: isApplied, disabled: false) { onToggle($0) }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isApplied ? Theme.surfaceHi.opacity(0.8) : Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(isApplied ? Theme.neonBlue.opacity(0.7) : Theme.borderDim, lineWidth: isApplied ? 1.5 : 1))
        .shadow(color: isApplied ? Theme.neonBlue.opacity(0.15) : .black.opacity(0.3), radius: isApplied ? 10 : 6, y: 3)
    }
}

private struct CustomToggle: View {
    let isOn: Bool; let disabled: Bool; let action: (Bool) -> Void
    var body: some View {
        Button { if !disabled { action(!isOn) } } label: {
            ZStack {
                Capsule().fill(isOn ? Theme.neonBlue : Color.white.opacity(0.1)).frame(width: 56, height: 30).overlay(Capsule().strokeBorder(isOn ? Theme.neonBlue : Color.white.opacity(0.2), lineWidth: 1.2))
                HStack { if isOn { Spacer(); Circle().fill(.black).frame(width: 22, height: 22).padding(.trailing, 4) } else { Circle().fill(.white).frame(width: 22, height: 22).padding(.leading, 4); Spacer() } }.frame(width: 56, height: 30)
            }.animation(.spring(response: 0.25, dampingFraction: 0.7), value: isOn).opacity(disabled ? 0.5 : 1.0)
        }.buttonStyle(.plain).disabled(disabled)
    }
}

private struct FolderPill: View {
    let title: String; let count: Int; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(isActive ? .black : Theme.neonBlue).frame(width: 6, height: 6)
                Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(isActive ? .black : .white)
                Text("\(count)").font(.system(size: 10, weight: .bold)).foregroundStyle(isActive ? .black.opacity(0.6) : .white.opacity(0.5)).padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(isActive ? .black.opacity(0.15) : Color.white.opacity(0.1)))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Capsule().fill(isActive ? Theme.neonBlue : Theme.surface))
            .overlay(Capsule().strokeBorder(isActive ? Theme.neonBlue : Theme.borderDim, lineWidth: 1.2))
        }.buttonStyle(.plain)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - POPUP GHI CHÚ
// ═══════════════════════════════════════════════════════════════
struct ActivationPopupView: View {
    let info: ActivationInfo; let onDismiss: () -> Void; @State private var copied = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea().onTapGesture { onDismiss() }
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Theme.neonBlue.opacity(0.2)).frame(width: 80, height: 80).blur(radius: 10)
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 36, weight: .heavy)).foregroundStyle(Theme.neonBlue)
                }
                VStack(spacing: 6) {
                    Text("KÍCH HOẠT THÀNH CÔNG").font(.system(size: 15, weight: .heavy)).tracking(2).foregroundStyle(Theme.neonBlue)
                    Text(info.patchName).font(.system(size: 14, weight: .bold)).foregroundStyle(.white).multilineTextAlignment(.center)
                }
                if !info.note.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("THÔNG TIN TÍNH NĂNG").font(.system(size: 10, weight: .heavy)).tracking(1.5).foregroundStyle(.white.opacity(0.5))
                        Text(info.note).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.9)).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(14).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surfaceHi)).padding(.horizontal, 16)
                    
                    Button { SoundFX.tap(); UIPasteboard.general.string = info.note; withAnimation { copied = true }; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { copied = false } } } label: {
                        HStack(spacing: 6) { Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 12, weight: .bold)); Text(copied ? "ĐÃ SAO CHÉP" : "SAO CHÉP GHI CHÚ").font(.system(size: 12, weight: .bold)) }.foregroundStyle(copied ? .black : .white).frame(maxWidth: .infinity).padding(.vertical, 14).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(copied ? Theme.neonBlue : Theme.surfaceHi))
                    }.buttonStyle(.plain).padding(.horizontal, 16)
                }
                Button(action: { SoundFX.tap(); onDismiss() }) { Text("XÁC NHẬN").font(.system(size: 13, weight: .heavy)).tracking(1.5).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 14).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.neonBlue)) }.buttonStyle(.plain).padding(.horizontal, 16).padding(.bottom, 10)
            }.padding(.top, 24).background(.ultraThinMaterial).background(Theme.surface.opacity(0.9)).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.neonBlue.opacity(0.5), lineWidth: 1.5)).shadow(color: .black.opacity(0.7), radius: 30, y: 10).padding(.horizontal, 24)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MAIN PROJECTS VIEW
// ═══════════════════════════════════════════════════════════════
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore
    @State private var actionAlert: PatchStoreAlert?
    @State private var selectedGame: GameSelection?
    @State private var showSilentSubmenu = false
    @State private var isSyncing = false
    @State private var syncGuard = false

    let onOpenSettings: () -> Void; let onOpenLogs: () -> Void
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    init(onOpenSettings: @escaping () -> Void = {}, onOpenLogs: @escaping () -> Void = {}) { self.onOpenSettings = onOpenSettings; self.onOpenLogs = onOpenLogs }

    var body: some View {
        NavigationStack {
            ZStack { NeonBackgroundView(); VStack(spacing: 0) { header; content } }
            .navigationBarHidden(true)
            .onAppear { store.reload(); triggerSync() }
            .onChange(of: scenePhase) { p in if p == .active { store.reload(); triggerSync() } }
            .onReceive(timer) { _ in triggerSync() }
            .sheet(item: $selectedGame) { g in PatchGameDetailView(game: g, store: store, actionAlert: $actionAlert, language: language) }
            .sheet(isPresented: $showSilentSubmenu) { SilentSubMenuSheet(onSelect: { prefix in showSilentSubmenu = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { selectedGame = GameSelection(title: prefix == "silent_ffmax" ? "Menu Silent · FF Max" : "Menu Silent · FF Thường", prefix: prefix) } }, onCancel: { showSilentSubmenu = false }) }
            .alert(item: $actionAlert) { a in Alert(title: Text(a.titleKey), message: Text(a.message(language: language)), dismissButton: .default(Text("OK"))) }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); syncPill }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 2)
            AvatarView().padding(.top, 4)
            Text("ZENITH CORE").font(.system(size: 22, weight: .black, design: .serif)).tracking(3.0).foregroundStyle(.white).shadow(color: Theme.neonBlue.opacity(0.6), radius: 10).padding(.top, 12)
            HStack(spacing: 10) { Rectangle().fill(Theme.neonBlue.opacity(0.4)).frame(width: 25, height: 1); Text("SECURE ENGINE").font(.system(size: 9, weight: .heavy)).tracking(3.0).foregroundStyle(Theme.neonBlue); Rectangle().fill(Theme.neonBlue.opacity(0.4)).frame(width: 25, height: 1) }.padding(.top, 6).padding(.bottom, 20)
        }
    }

    private var syncPill: some View {
        HStack(spacing: 6) {
            Circle().fill(isSyncing ? Color.yellow : Color.green).frame(width: 8, height: 8).shadow(color: isSyncing ? .yellow : .green, radius: 4)
            Text(isSyncing ? "SYNC..." : "ONLINE").font(.system(size: 9, weight: .heavy)).tracking(1.5).foregroundStyle(.white.opacity(0.7))
        }.padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(Theme.surface)).overlay(Capsule().strokeBorder(Theme.borderDim, lineWidth: 1))
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                gameCard("Free Fire Max", "PREMIUM EDITION", "ffmax", "https://solitudepremium.click/ipa/ipa/free.jpg")
                gameCard("Free Fire Thường", "CLASSIC EDITION", "ffnormal", "https://solitudepremium.click/ipa/ipa/free.jpg")
                silentCard()
            }.padding(.horizontal, 18).padding(.bottom, 40)
        }.refreshable { await syncNow() }
    }

    private func gameCard(_ t: String, _ s: String, _ p: String, _ u: String) -> some View {
        Button { SoundFX.menu(); selectedGame = GameSelection(title: t, prefix: p) } label: { GlowCard { HStack(spacing: 16) { GameLogoView(imageURL: u); VStack(alignment: .leading, spacing: 5) { Text(t).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white); Text(s).font(.system(size: 9, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.45)) }; Spacer(); ChevronCircle() }.padding(16) } }.buttonStyle(.plain)
    }

    private func silentCard() -> some View {
        Button { SoundFX.menu(); showSilentSubmenu = true } label: { GlowCard { HStack(spacing: 16) { ServerAvatarView(size: 62, shape: .roundedSquare, corner: 16); VStack(alignment: .leading, spacing: 5) { Text("Menu Silent").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white); Text("CHỌN PHIÊN BẢN").font(.system(size: 9, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.45)) }; Spacer(); ChevronCircle() }.padding(16) } }.buttonStyle(.plain)
    }

    private func triggerSync() { guard !syncGuard else { return }; syncGuard = true; Task { await syncNow(); await MainActor.run { syncGuard = false } } }
    @MainActor private func syncNow() async { isSyncing = true; await SyncEngine.shared.run(store: store); store.reload(); isSyncing = false }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SILENT SUB-MENU
// ═══════════════════════════════════════════════════════════════
struct SilentSubMenuSheet: View {
    let onSelect: (String) -> Void; let onCancel: () -> Void
    var body: some View {
        ZStack {
            NeonBackgroundView()
            VStack(spacing: 24) {
                Spacer(minLength: 20)
                VStack(spacing: 14) { ServerAvatarView(size: 90, shape: .roundedSquare, corner: 22); Text("MENU SILENT").font(.system(size: 22, weight: .heavy)).tracking(3).foregroundStyle(.white); Text("CHỌN PHIÊN BẢN GAME").font(.system(size: 10, weight: .heavy)).tracking(3).foregroundStyle(Theme.neonBlue) }.padding(.bottom, 10)
                VStack(spacing: 14) {
                    Button { SoundFX.menu(); onSelect("silent_ffmax") } label: { GlowCard { HStack(spacing: 16) { ServerAvatarView(size: 58, shape: .roundedSquare, corner: 14); VStack(alignment: .leading, spacing: 5) { Text("Free Fire Max").font(.system(size: 16, weight: .bold)).foregroundStyle(.white); Text("PREMIUM EDITION").font(.system(size: 9, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.45)) }; Spacer(); ChevronCircle() }.padding(16) } }.buttonStyle(.plain)
                    Button { SoundFX.menu(); onSelect("silent_ffnormal") } label: { GlowCard { HStack(spacing: 16) { ServerAvatarView(size: 58, shape: .roundedSquare, corner: 14); VStack(alignment: .leading, spacing: 5) { Text("Free Fire Thường").font(.system(size: 16, weight: .bold)).foregroundStyle(.white); Text("CLASSIC EDITION").font(.system(size: 9, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.45)) }; Spacer(); ChevronCircle() }.padding(16) } }.buttonStyle(.plain)
                }.padding(.horizontal, 20)
                Spacer()
                Button { SoundFX.tap(); onCancel() } label: { Text("ĐÓNG").font(.system(size: 13, weight: .heavy)).tracking(2).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 14).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.neonBlue)) }.buttonStyle(.plain).padding(.horizontal, 30).padding(.bottom, 40)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DETAIL VIEW
// ═══════════════════════════════════════════════════════════════
struct PatchGameDetailView: View {
    let game: GameSelection; @ObservedObject var store: PatchProjectStore; @Binding var actionAlert: PatchStoreAlert?; let language: AppLanguage
    @Environment(\.dismiss) private var dismiss; @Environment(\.scenePhase) private var scenePhase
    @State private var activationInfo: ActivationInfo?; @State private var selectedFolder: String? = nil; @State private var workingFileID: String? = nil; @State private var refreshTick: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) { topBar; folderBar; listContent }
                if let info = activationInfo { ActivationPopupView(info: info) { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { activationInfo = nil } }.transition(.scale(scale: 0.9).combined(with: .opacity)).zIndex(100) }
            }
            .navigationBarHidden(true)
            .onAppear { store.reload(); syncFolders() }
            .alert(item: $actionAlert) { a in Alert(title: Text(a.titleKey), message: Text(a.message(language: language)), dismissButton: .default(Text("OK"))) }
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { SoundFX.tap(); dismiss() } label: { ZStack { Circle().fill(Theme.surface).frame(width: 40, height: 40).overlay(Circle().strokeBorder(Theme.borderDim, lineWidth: 1.2)); Image(systemName: "arrow.left").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white) } }.buttonStyle(.plain)
            Text(game.title).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            Spacer()
        }.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 12)
    }

    @ViewBuilder private var folderBar: some View {
        if folders.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { ForEach(folders, id: \.self) { f in FolderPill(title: f, count: gameItems.filter { folderName(for: $0) == f }.count, isActive: selectedFolder == f) { SoundFX.tap(); withAnimation { selectedFolder = f } } } }.padding(.horizontal, 20)
            }.padding(.bottom, 14)
        }
    }

    private func syncFolders() { let c = folders; if c.isEmpty { selectedFolder = nil; return }; if let s = selectedFolder, c.contains(s) { return }; selectedFolder = c.first }
    private var gameItems: [PatchLibraryItem] { _ = refreshTick; return store.items.filter { GameTypeHelper.prefixOf($0) == game.prefix } }
    private var folders: [String] { var u: [String] = []; for item in gameItems { let f = folderName(for: item); if !f.isEmpty && !u.contains(f) { u.append(f) } }; return u.sorted() }
    private var displayedItems: [PatchLibraryItem] { if folders.count <= 1 { return gameItems }; guard let s = selectedFolder else { return gameItems }; return gameItems.filter { folderName(for: $0) == s } }
    
    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            if displayedItems.isEmpty {
                VStack(spacing: 16) { ZStack { Circle().strokeBorder(Theme.borderDim, style: StrokeStyle(lineWidth: 1.5, dash: [4, 6])).frame(width: 80, height: 80); Image(systemName: "tray.fill").font(.system(size: 30, weight: .light)).foregroundStyle(.white.opacity(0.3)) }; Text(folders.isEmpty ? "Đang đồng bộ dữ liệu..." : "Thư mục trống.").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.4)) }.padding(.top, 100).frame(maxWidth: .infinity)
            } else { LazyVStack(spacing: 12) { ForEach(displayedItems) { item in patchRow(item: item) } }.padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 40) }
        }
    }

    private func patchRow(item: PatchLibraryItem) -> some View {
        let r = DevicePatchService.latestReceipt(projectID: item.id); let applied = (r != nil); let n = displayName(for: item)
        return PatchCard(isApplied: applied, isWorking: workingFileID == item.id.uuidString, displayName: n, tag: currentTag(for: item), note: currentNote(for: item), onToggle: { nv in if nv { SoundFX.tingTing() } else { SoundFX.tap() }; togglePatch(item: item, activate: nv) }, onShowNote: { SoundFX.tap(); withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { activationInfo = ActivationInfo(patchName: n, tag: currentTag(for: item), note: currentNote(for: item), success: true, errorMessage: nil) } })
    }

    private func localKey(for i: PatchLibraryItem) -> String { i.packageURL.lastPathComponent }
    private func meta(for i: PatchLibraryItem) -> PatchMeta? { PatchMetaStore.get(localName: localKey(for: i)) }
    private func displayName(for i: PatchLibraryItem) -> String { if let m = meta(for: i), !m.displayName.isEmpty { return m.displayName }; if let n = i.project?.name, !n.isEmpty { return n }; return i.packageURL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_VIP", with: "").replacingOccurrences(of: "_FREE", with: "") }
    private func currentTag(for i: PatchLibraryItem) -> String { if let m = meta(for: i), !m.tag.isEmpty { return m.tag }; return i.packageURL.deletingPathExtension().lastPathComponent.hasSuffix("_VIP") ? "VIP" : "FREE" }
    private func currentNote(for i: PatchLibraryItem) -> String { meta(for: i)?.note ?? "" }
    private func folderName(for i: PatchLibraryItem) -> String { if let m = meta(for: i), !m.folder.isEmpty { return m.folder }; let c = i.packageURL.pathComponents; if let idx = c.firstIndex(where: { $0 == "ffmax" || $0 == "ffnormal" || $0 == "silent" }), idx + 1 < c.count { let n = c[idx + 1]; if n == "ffmax" || n == "ffnormal", idx + 2 < c.count { return c[idx + 2] }; if n != "ffmax" && n != "ffnormal" { return n } }; return "CHUNG" }

    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        workingFileID = item.id.uuidString; let nameSnap = displayName(for: item); let tagSnap = currentTag(for: item); let noteSnap = currentNote(for: item); let targetFolder = folderName(for: item); let gp = game.prefix
        let conflictIDs: [UUID] = activate ? store.items.compactMap { o in guard o.id != item.id, GameTypeHelper.prefixOf(o) == gp, folderName(for: o) == targetFolder, DevicePatchService.latestReceipt(projectID: o.id) != nil else { return nil }; return o.id } : []

        Task.detached(priority: .userInitiated) {
            for cid in conflictIDs { if let r = DevicePatchService.latestReceipt(projectID: cid) { try? DevicePatchService.restore(receipt: r) } }
            if !activate {
                do {
                    if let r = DevicePatchService.latestReceipt(projectID: item.id) { try DevicePatchService.restore(receipt: r) }
                    await MainActor.run { store.reload(); workingFileID = nil }
                } catch { await MainActor.run { workingFileID = nil } }
                return
            }
            
            AlertInterceptor.startNuking()
            await MainActor.run { MaxShield.shared.activate(duration: 8.0) }
            
            do {
                guard let p = item.project else { await MainActor.run { MaxShield.shared.deactivate(); workingFileID = nil }; return }
                _ = try DevicePatchService.apply(project: p); try? await Task.sleep(nanoseconds: 800_000_000)
                
                await MainActor.run {
                    MaxShield.shared.deactivate(); store.reload(); workingFileID = nil; SoundFX.success()
                    if !noteSnap.isEmpty {
                        withAnimation { activationInfo = ActivationInfo(patchName: nameSnap, tag: tagSnap, note: noteSnap, success: true, errorMessage: nil) }
                    }
                }
            } catch {
                await MainActor.run { MaxShield.shared.deactivate(); store.reload(); workingFileID = nil; SoundFX.error() }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SYNC ENGINE
// ═══════════════════════════════════════════════════════════════
final class SyncEngine {
    static let shared = SyncEngine()
    private let syncQueue = DispatchQueue(label: "com.zenith.syncQueue")
    private var isRunning = false; private init() {}

    func run(store: PatchProjectStore) async {
        guard !isRunning else { return }; isRunning = true; defer { isRunning = false }
        guard let remotes = await fetchRemotes() else { return }
        
        await MainActor.run { store.reload() }; let items = await MainActor.run { store.items }; let storeFiles = Set(items.map { $0.packageURL.lastPathComponent })
        for item in items { let ln = item.packageURL.lastPathComponent; if let r = remotes.first(where: { $0.filename == ln }) { syncQueue.sync { PatchMetaStore.set(makeMeta(r, localName: ln), localName: ln) } } }

        var missing: [RemoteFileLite] = []
        for r in remotes { if !storeFiles.contains(r.filename) { missing.append(r) } else { syncQueue.sync { PatchMetaStore.set(makeMeta(r, localName: r.filename), localName: r.filename) } } }
        guard !missing.isEmpty else { await MainActor.run { store.reload() }; return }
        for r in missing { _ = await downloadAndImport(remote: r, store: store) }; await MainActor.run { store.reload() }
    }

    private func makeMeta(_ r: RemoteFileLite, localName: String) -> PatchMeta { PatchMeta(uid: r.uid, localName: localName, remoteName: r.filename, gameType: r.gameType, folder: r.folder, tag: r.tag, displayName: r.displayName, note: r.note) }

    private func downloadAndImport(remote: RemoteFileLite, store: PatchProjectStore) async -> Bool {
        guard let url = URL(string: remote.url) else { return false }
        let before = await MainActor.run { Set(store.items.map { $0.packageURL.lastPathComponent }) }
        
        AlertInterceptor.startNuking()
        URLCache.shared.removeAllCachedResponses(); URLCache.shared.memoryCapacity = 0; URLCache.shared.diskCapacity = 0
        
        await MainActor.run { store.importPackage(from: .remote(url)) }

        for i in 0..<50 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if i % 2 == 0 { await MainActor.run { store.reload() } }
            let after = await MainActor.run { Set(store.items.map { $0.packageURL.lastPathComponent }) }
            let newFiles = after.subtracting(before)
            guard !newFiles.isEmpty else { continue }
            
            var chosen = newFiles.first(where: { $0 == remote.filename })
            if chosen == nil { chosen = newFiles.first(where: { $0.hasSuffix(remote.filename) || remote.filename.hasSuffix($0) }) }
            if chosen == nil && newFiles.count == 1 { chosen = newFiles.first }
            guard let local = chosen else { continue }

            syncQueue.sync { PatchMetaStore.set(makeMeta(remote, localName: local), localName: local) }
            await MainActor.run { store.reload() }
            return true
        }
        return false
    }

    private func fetchRemotes() async -> [RemoteFileLite]? {
        guard let url = URL(string: "https://solitudepremium.click/ipa/ipa/list.php?v=\(Date().timeIntervalSince1970)") else { return nil }
        do {
            var req = URLRequest(url: url); req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData; req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            let config = URLSessionConfiguration.ephemeral; config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let session = URLSession(configuration: config)
            let (data, _) = try await session.data(for: req)
            struct Wire: Decodable { let uid: String?; let filename: String; let gameType: String; let folder: String?; let displayName: String?; let tag: String?; let note: String?; let url: String }
            let wire = try JSONDecoder().decode([Wire].self, from: data)
            return wire.map { w in RemoteFileLite(filename: w.filename, gameType: w.gameType, folder: w.folder ?? "Chung", tag: w.tag ?? "FREE", displayName: w.displayName ?? "", note: w.note ?? "", url: w.url) }
        } catch { return nil }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - UNLOCK VIEW & PRESENTATION
// ═══════════════════════════════════════════════════════════════
struct PatchUnlockView: View {
    @Environment(\.appLanguage) private var language; @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore; let request: PatchPasswordRequest
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(language.text("patch.password"), text: $password).textContentType(.password).submitLabel(.done).onSubmit(unlock).onChange(of: password) { _ in store.clearUnlockError() }
                    if let k = store.unlockErrorKey { Text(errorText(k)).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle(language.text("patch.unlock")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(language.text("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(language.text("patch.unlock"), action: unlock).disabled(password.isEmpty || store.isBusy) }
            }
        }
    }
    private func errorText(_ k: String) -> String { if let a = store.unlockErrorArgument { return language.text(k, a) }; return language.text(k) }
    private func unlock() { guard !password.isEmpty else { return }; store.unlock(password: password) }
}

struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore
    func body(content: Content) -> some View { 
        content.sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { r in 
            PatchUnlockView(store: store, request: r) 
        } 
    }
}

extension View { 
    func patchStorePresentation(_ store: PatchProjectStore) -> some View { 
        modifier(PatchStorePresentationModifier(store: store)) 
    } 
}
