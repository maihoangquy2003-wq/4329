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
// MARK: - MAX SHIELD
// ═══════════════════════════════════════════════════════════════
final class MaxShield {
    static let shared = MaxShield()
    private var win: UIWindow?
    private var timer: Timer?
    private var hideTimer: Timer?

    private init() {}

    func activate(duration: TimeInterval = 12.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.deactivate()
            guard let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene }).first else { return }
            let w = UIWindow(windowScene: scene)
            w.windowLevel = UIWindow.Level.alert + 999999
            w.backgroundColor = .black
            w.rootViewController = UIHostingController(rootView: ShieldView())
            w.rootViewController?.view.backgroundColor = .black
            w.makeKeyAndVisible()
            self.win = w

            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                w.isHidden = false
                w.alpha = 1
            }
            if let t = self.timer { RunLoop.main.add(t, forMode: .common) }
            self.hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in self.deactivate() }
        }
    }

    func deactivate() {
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate(); self?.timer = nil
            self?.hideTimer?.invalidate(); self?.hideTimer = nil
            self?.win?.isHidden = true
            self?.win = nil
        }
    }
}

private struct ShieldView: View {
    @State private var pulse = false
    @State private var dots = ""
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack {
                    Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 140, height: 140).scaleEffect(pulse ? 1.15 : 0.92)
                    Circle().fill(Color.white.opacity(0.05)).frame(width: 100, height: 100)
                    ProgressView().tint(.white).scaleEffect(1.6)
                }
                VStack(spacing: 10) {
                    Text("ZENITH SOLITUDE").font(.system(size: 11, weight: .heavy)).tracking(4.5).foregroundStyle(.white.opacity(0.6))
                    Text("ĐANG KÍCH HOẠT\(dots)").font(.system(size: 16, weight: .heavy)).tracking(2.5).foregroundStyle(.white)
                    Text("Vui lòng không thoát ứng dụng").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.5)).padding(.top, 4)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                dots = String(repeating: ".", count: (dots.count + 1) % 4)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - THEME (ĐEN - TRẮNG NEON)
// ═══════════════════════════════════════════════════════════════
enum Theme {
    static let bg         = Color.black
    static let surface    = Color(white: 0.04)
    static let surfaceHi  = Color(white: 0.08)
    static let border     = Color.white.opacity(0.25)
    static let borderDim  = Color.white.opacity(0.1)
    static let glow       = Color.white.opacity(0.6)
    static let text       = Color.white
    static let textDim    = Color.white.opacity(0.5)
}

struct NeonBackgroundView: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Color.white.opacity(0.1), .clear], center: .topLeading, startRadius: 0, endRadius: 600)
            RadialGradient(colors: [Color.white.opacity(0.05), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 500)
        }.ignoresSafeArea()
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MODELS & STORE
// ═══════════════════════════════════════════════════════════════
struct GameSelection: Identifiable, Hashable { let id = UUID(); let title: String; let prefix: String }

struct PatchMeta: Codable {
    var uid: String; var localName: String; var remoteName: String; var gameType: String
    var folder: String; var tag: String; var displayName: String; var note: String
    var tagOverride: Bool; var nameOverride: Bool; var noteOverride: Bool

    init(uid: String = "", localName: String = "", remoteName: String = "", gameType: String = "", folder: String = "", tag: String = "FREE", displayName: String = "", note: String = "", tagOverride: Bool = false, nameOverride: Bool = false, noteOverride: Bool = false) {
        self.uid = uid; self.localName = localName; self.remoteName = remoteName; self.gameType = gameType; self.folder = folder; self.tag = tag; self.displayName = displayName; self.note = note; self.tagOverride = tagOverride; self.nameOverride = nameOverride; self.noteOverride = noteOverride
    }
}

struct RemoteFileLite {
    let uid: String, filename: String, gameType: String, folder: String, tag: String, displayName: String, note: String, url: String
    init(filename: String, gameType: String, folder: String, tag: String, displayName: String, note: String, url: String) {
        self.filename = filename; self.gameType = gameType; self.folder = folder; self.tag = tag; self.displayName = displayName; self.note = note; self.url = url
        let key = "\(gameType)/\(folder)/\(filename)"
        var h: UInt64 = 1469598103934665603
        for b in key.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        self.uid = String(h, radix: 16)
    }
}

struct ActivationInfo: Identifiable {
    let id = UUID()
    let patchName: String; let tag: String; let note: String; let success: Bool; let errorMessage: String?
}

enum PatchMetaStore {
    private static let key = "patch_meta_v70"
    static func all() -> [String: PatchMeta] {
        guard let d = UserDefaults.standard.data(forKey: key), let x = try? JSONDecoder().decode([String: PatchMeta].self, from: d) else { return [:] }
        return x
    }
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
// MARK: - COMPONENTS (PHỤC HỒI ĐẦY ĐỦ AVATAR, TAG, TOGGLE, GLOW)
// ═══════════════════════════════════════════════════════════════
private struct GlowCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.borderDim, lineWidth: 1.2))
            .shadow(color: .white.opacity(0.08), radius: 10, y: 4)
    }
}

enum AvatarShape { case circle, roundedSquare }
private struct AnyShape: Shape {
    private let make: (CGRect) -> Path
    init<S: Shape>(_ s: S) { self.make = { s.path(in: $0) } }
    func path(in rect: CGRect) -> Path { make(rect) }
}
extension Shape { func strokeBorder(_ c: Color, lineWidth: CGFloat) -> some View { self.stroke(c, lineWidth: lineWidth) } }

private struct ServerAvatarView: View {
    let size: CGFloat; var shape: AvatarShape = .circle; var corner: CGFloat = 16
    var body: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/ipa/liii.jpg")) { p in
            switch p {
            case .empty: ZStack { fill; ProgressView().tint(.white).scaleEffect(0.8) }
            case .success(let img): img.resizable().scaledToFill()
            case .failure: ZStack { fill; Image(systemName: "person.fill").font(.system(size: size*0.4)).foregroundStyle(.white.opacity(0.5)) }
            @unknown default: EmptyView()
            }
        }
        .frame(width: size, height: size).clipShape(clip)
        .overlay(clip.strokeBorder(.white.opacity(0.8), lineWidth: 1.5))
    }
    private var clip: AnyShape {
        switch shape {
        case .circle: return AnyShape(Circle())
        case .roundedSquare: return AnyShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        }
    }
    @ViewBuilder private var fill: some View {
        switch shape {
        case .circle: Circle().fill(Theme.surfaceHi)
        case .roundedSquare: RoundedRectangle(cornerRadius: corner, style: .continuous).fill(Theme.surfaceHi)
        }
    }
}

private struct AvatarView: View {
    @State private var rotate = false
    @State private var pulse = false
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.1)).frame(width: pulse ? 128 : 110, height: pulse ? 128 : 110).blur(radius: 20)
            Circle().strokeBorder(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                .frame(width: 116, height: 116).rotationEffect(.degrees(rotate ? 360 : 0))
            Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 2).frame(width: 96, height: 96)
            ServerAvatarView(size: 80, shape: .circle)
        }
        .frame(width: 130, height: 130)
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) { rotate = true }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

private struct GameLogoView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceHi)
            Image(systemName: "gamecontroller.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
        }
        .frame(width: 60, height: 60)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white, lineWidth: 1.4))
    }
}

private struct ChevronCircle: View {
    var body: some View {
        ZStack {
            Circle().fill(.white).frame(width: 34, height: 34).shadow(color: .white.opacity(0.4), radius: 8)
            Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .heavy)).foregroundStyle(.black)
        }
    }
}

private struct TagPill: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isVIP ? "crown.fill" : "shield.fill").font(.system(size: 8, weight: .heavy))
            Text(tag).font(.system(size: 9, weight: .heavy)).tracking(1.0)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .foregroundStyle(isVIP ? .black : .white)
        .background(Capsule().fill(isVIP ? .white : Color.white.opacity(0.1)))
        .overlay(Capsule().strokeBorder(isVIP ? .white : .white.opacity(0.5), lineWidth: 1.2))
        .shadow(color: isVIP ? .white.opacity(0.6) : .clear, radius: 6)
    }
}

private struct PatchIconView: View {
    let tag: String; let isApplied: Bool
    private var isVIP: Bool { tag == "VIP" }
    var body: some View {
        ZStack {
            if isApplied {
                ServerAvatarView(size: 54, shape: .circle)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white.opacity(0.05)).frame(width: 54, height: 54)
                    RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(isVIP ? .white : Color.white.opacity(0.3), lineWidth: 1.5).frame(width: 54, height: 54)
                    Image(systemName: isVIP ? "crown.fill" : "shield.lefthalf.filled").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                }
            }
        }
    }
}

private struct CustomToggle: View {
    let isOn: Bool; let disabled: Bool; let action: (Bool) -> Void
    var body: some View {
        Button { if !disabled { action(!isOn) } } label: {
            ZStack {
                Capsule().fill(isOn ? Color.white : Color.white.opacity(0.1)).frame(width: 54, height: 32)
                    .overlay(Capsule().strokeBorder(isOn ? .white : Color.white.opacity(0.4), lineWidth: 1.4))
                    .shadow(color: isOn ? .white.opacity(0.6) : .clear, radius: 10)
                HStack {
                    if isOn { Spacer(); Circle().fill(.black).frame(width: 24, height: 24).padding(.trailing, 3) }
                    else { Circle().fill(.white).frame(width: 24, height: 24).padding(.leading, 3); Spacer() }
                }.frame(width: 54, height: 32)
            }
            .animation(.spring(response: 0.26, dampingFraction: 0.72), value: isOn)
            .opacity(disabled ? 0.5 : 1.0)
        }.buttonStyle(.plain).disabled(disabled)
    }
}

private struct FolderPill: View {
    let title: String; let count: Int; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle().fill(isActive ? Color.black : Color.white.opacity(0.5)).frame(width: 6, height: 6)
                Text(title).font(.system(size: 12, weight: .heavy)).tracking(1.0).foregroundStyle(isActive ? .black : .white)
                Text("\(count)").font(.system(size: 10, weight: .heavy)).foregroundStyle(isActive ? .black.opacity(0.6) : .white.opacity(0.4)).padding(.leading, 2)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Capsule().fill(isActive ? Color.white : Color.white.opacity(0.04)))
            .overlay(Capsule().strokeBorder(isActive ? Color.white : Color.white.opacity(0.2), lineWidth: 1.2))
            .shadow(color: isActive ? .white.opacity(0.6) : .clear, radius: 10)
        }.buttonStyle(.plain)
    }
}

private struct PatchCard: View {
    let isApplied: Bool; let isWorking: Bool; let displayName: String; let tag: String; let note: String
    let onToggle: (Bool) -> Void; let onTapTag: () -> Void; let onRename: () -> Void; let onEditNote: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            PatchIconView(tag: tag, isApplied: isApplied)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(displayName).font(.system(size: 14.5, weight: .heavy)).foregroundStyle(.white).lineLimit(1)
                    Button(action: onTapTag) { TagPill(tag: tag) }.buttonStyle(.plain)
                }
                if !note.isEmpty {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "text.alignleft").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.5)).padding(.top, 2)
                        Text(note).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.7)).lineLimit(2).multilineTextAlignment(.leading)
                    }
                }
            }
            Spacer(minLength: 4)
            if isWorking { ProgressView().tint(.white).scaleEffect(0.8).frame(width: 54, height: 32) }
            else { CustomToggle(isOn: isApplied, disabled: false) { onToggle($0) } }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isApplied ? Color.white.opacity(0.1) : Color.white.opacity(0.02)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(isApplied ? .white : Theme.borderDim, lineWidth: isApplied ? 1.5 : 1))
        .shadow(color: isApplied ? .white.opacity(0.25) : .black.opacity(0.3), radius: isApplied ? 14 : 8, y: 4)
        .contextMenu {
            Button(action: onRename) { Label("Đổi tên", systemImage: "pencil") }
            Button(action: onTapTag) { Label("Đổi VIP/FREE", systemImage: "crown") }
            Button(action: onEditNote) { Label("Sửa ghi chú", systemImage: "note.text") }
            Button { UIPasteboard.general.string = note; SoundFX.success() } label: { Label("Copy Ghi chú", systemImage: "doc.on.doc") }
        }
    }
}

private struct EmptyStateView: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().strokeBorder(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.4, dash: [3, 5])).frame(width: 84, height: 84)
                Image(systemName: "tray").font(.system(size: 30, weight: .light)).foregroundStyle(.white.opacity(0.5))
            }
            Text(message).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center).padding(.horizontal, 40)
        }.padding(.top, 70).frame(maxWidth: .infinity)
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

    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void
    
    let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    init(onOpenSettings: @escaping () -> Void = {}, onOpenLogs: @escaping () -> Void = {}) {
        self.onOpenSettings = onOpenSettings
        self.onOpenLogs = onOpenLogs
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) { header; content }
            }
            .navigationBarHidden(true)
            .onAppear { store.reload(); triggerSync() }
            .onChange(of: scenePhase) { p in if p == .active { store.reload(); triggerSync() } }
            .onReceive(timer) { _ in triggerSync() }
            .sheet(item: $selectedGame) { g in PatchGameDetailView(game: g, store: store, actionAlert: $actionAlert, language: language) }
            .sheet(isPresented: $showSilentSubmenu) {
                SilentSubMenuSheet(onSelect: { prefix in
                    showSilentSubmenu = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        selectedGame = GameSelection(title: prefix == "silent_ffmax" ? "Menu Silent · FF Max" : "Menu Silent · FF Thường", prefix: prefix)
                    }
                }, onCancel: { showSilentSubmenu = false })
            }
            .alert(item: $actionAlert) { a in Alert(title: Text(a.titleKey), message: Text(a.message(language: language)), dismissButton: .default(Text("OK"))) }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); syncPill }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 4)
            AvatarView().padding(.top, 6)
            Text("ZENITH SOLITUDE").font(.system(size: 22, weight: .black, design: .serif)).tracking(3.5).foregroundStyle(.white).shadow(color: .white.opacity(0.5), radius: 15).padding(.top, 14)
            HStack(spacing: 10) {
                Rectangle().fill(.white.opacity(0.3)).frame(width: 28, height: 1)
                Text("HEADLOCK ZENIS").font(.system(size: 9.5, weight: .heavy)).tracking(4.2).foregroundStyle(.white.opacity(0.6))
                Rectangle().fill(.white.opacity(0.3)).frame(width: 28, height: 1)
            }.padding(.top, 8).padding(.bottom, 22)
        }
    }

    private var syncPill: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle().fill(isSyncing ? Color.white.opacity(0.3) : Color.gray.opacity(0.3)).frame(width: 14, height: 14)
                Circle().fill(isSyncing ? Color.white : Color.gray).frame(width: 7, height: 7).shadow(color: isSyncing ? .white : .clear, radius: 6)
            }
            Text(isSyncing ? "SYNCING..." : "CONNECTED").font(.system(size: 9, weight: .heavy)).tracking(1.6).foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                gameCard("Free Fire Max", "PREMIUM EDITION", "ffmax")
                gameCard("Free Fire Thường", "CLASSIC EDITION", "ffnormal")
                silentCard()
                HStack(spacing: 8) {
                    Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
                    Text("BY ZENITH SOLITUDE").font(.system(size: 9, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.5)).fixedSize()
                    Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
                }.padding(.horizontal, 40).padding(.top, 22)
            }.padding(.horizontal, 16).padding(.bottom, 50)
        }.refreshable { await syncNow() }
    }

    private func gameCard(_ t: String, _ s: String, _ p: String) -> some View {
        Button { SoundFX.menu(); selectedGame = GameSelection(title: t, prefix: p) } label: {
            GlowCard {
                HStack(spacing: 14) {
                    GameLogoView()
                    VStack(alignment: .leading, spacing: 6) {
                        Text(t).font(.system(size: 16.5, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        Text(s).font(.system(size: 9.5, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer(); ChevronCircle()
                }.padding(.horizontal, 16).padding(.vertical, 15)
            }
        }.buttonStyle(.plain)
    }

    private func silentCard() -> some View {
        Button { SoundFX.menu(); showSilentSubmenu = true } label: {
            GlowCard {
                HStack(spacing: 14) {
                    ServerAvatarView(size: 60, shape: .roundedSquare, corner: 16)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Menu Silent").font(.system(size: 16.5, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        Text("CHỌN PHIÊN BẢN").font(.system(size: 9.5, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer(); ChevronCircle()
                }.padding(.horizontal, 16).padding(.vertical, 15)
            }
        }.buttonStyle(.plain)
    }

    private func triggerSync() {
        guard !syncGuard else { return }; syncGuard = true
        Task { await syncNow(); await MainActor.run { syncGuard = false } }
    }

    @MainActor
    private func syncNow() async {
        isSyncing = true
        await SyncEngine.shared.run(store: store)
        store.reload(); try? await Task.sleep(nanoseconds: 200_000_000); store.reload()
        isSyncing = false
    }
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
                Spacer(minLength: 30)
                VStack(spacing: 14) {
                    ServerAvatarView(size: 96, shape: .roundedSquare, corner: 22)
                    Text("MENU SILENT").font(.system(size: 22, weight: .heavy)).tracking(3).foregroundStyle(.white).shadow(color: .white.opacity(0.6), radius: 14)
                    Text("CHỌN PHIÊN BẢN GAME").font(.system(size: 10, weight: .heavy)).tracking(3.5).foregroundStyle(.white.opacity(0.5))
                }.padding(.bottom, 6)
                VStack(spacing: 14) {
                    optionCard("Free Fire Max", "PREMIUM EDITION", "silent_ffmax")
                    optionCard("Free Fire Thường", "CLASSIC EDITION", "silent_ffnormal")
                }.padding(.horizontal, 22)
                Spacer()
                Button { SoundFX.tap(); onCancel() } label: {
                    Text("HUỶ").font(.system(size: 13, weight: .heavy)).tracking(2.5).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 15).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
                }.buttonStyle(.plain).padding(.horizontal, 40).padding(.bottom, 40)
            }
        }
    }
    private func optionCard(_ t: String, _ s: String, _ p: String) -> some View {
        Button { SoundFX.menu(); onSelect(p) } label: {
            GlowCard {
                HStack(spacing: 16) {
                    ServerAvatarView(size: 64, shape: .roundedSquare, corner: 16)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(t).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        Text(s).font(.system(size: 9.5, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer(); ChevronCircle()
                }.padding(.horizontal, 16).padding(.vertical, 14)
            }
        }.buttonStyle(.plain)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SHEET THÔNG BÁO BẬT TẮT (CÓ HIỂN THỊ VÀ COPY GHI CHÚ)
// ═══════════════════════════════════════════════════════════════
struct ActivationNoteSheet: View {
    let info: ActivationInfo; let onDismiss: () -> Void
    @State private var copied = false

    private var isError: Bool { !info.success }
    private var accent: Color { isError ? Color(red: 1.0, green: 0.3, blue: 0.3) : .white }
    private var hasNote: Bool { !info.note.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            NeonBackgroundView()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer(minLength: 50)
                    if isError {
                        ZStack {
                            Circle().fill(accent.opacity(0.15)).frame(width: 130, height: 130).blur(radius: 20)
                            Circle().fill(accent).frame(width: 92, height: 92).shadow(color: accent.opacity(0.6), radius: 24)
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 38, weight: .heavy)).foregroundStyle(.white)
                        }
                    } else {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.15)).frame(width: 130, height: 130).blur(radius: 24)
                            ServerAvatarView(size: 100, shape: .circle).shadow(color: .white.opacity(0.55), radius: 24)
                        }
                    }
                    
                    VStack(spacing: 12) {
                        Text("HEADLOCK ZENIS").font(.system(size: 11, weight: .heavy)).tracking(4.5).foregroundStyle(.white.opacity(0.6))
                        Text(isError ? "LỖI KÍCH HOẠT" : "ĐÃ CẬP NHẬT THÀNH CÔNG").font(.system(size: 18, weight: .heavy)).tracking(2).foregroundStyle(accent).multilineTextAlignment(.center).padding(.horizontal, 20)
                        Text(info.patchName).font(.system(size: 16, weight: .heavy)).foregroundStyle(.white).multilineTextAlignment(.center).padding(.horizontal, 28)
                        if !info.tag.isEmpty { TagPill(tag: info.tag).padding(.top, 4) }
                    }

                    if isError, let e = info.errorMessage, !e.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("LÝ DO LỖI").font(.system(size: 10, weight: .heavy)).tracking(2.2).foregroundStyle(accent)
                            Text(e).font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(accent.opacity(0.1))).overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(accent.opacity(0.5), lineWidth: 1.3)).padding(.horizontal, 24)
                    }

                    // TÍNH NĂNG HIỂN THỊ VÀ COPY GHI CHÚ
                    if hasNote {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "note.text").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                Text("GHI CHÚ").font(.system(size: 10, weight: .heavy)).tracking(2.2).foregroundStyle(.white)
                                Spacer()
                            }
                            Text(info.note).font(.system(size: 13.5, weight: .medium)).foregroundStyle(.white.opacity(0.95)).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.05))).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                            
                            Button {
                                SoundFX.tap()
                                UIPasteboard.general.string = info.note
                                withAnimation { copied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { copied = false } }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: copied ? "checkmark" : "doc.on.doc.fill").font(.system(size: 12, weight: .heavy))
                                    Text(copied ? "ĐÃ COPY" : "COPY GHI CHÚ").font(.system(size: 11.5, weight: .heavy)).tracking(1.8)
                                }.foregroundStyle(copied ? .black : .white).frame(maxWidth: .infinity).padding(.vertical, 13).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(copied ? Color.white : Color.white.opacity(0.06))).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white, lineWidth: 1.4))
                            }.buttonStyle(.plain)
                        }.padding(18).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1.3)).padding(.horizontal, 22)
                    }
                    
                    Button { SoundFX.tap(); onDismiss() } label: {
                        Text("ĐÃ HIỂU").font(.system(size: 14, weight: .heavy)).tracking(3).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 16).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white)).padding(.horizontal, 40)
                    }.buttonStyle(.plain).padding(.bottom, 50).padding(.top, 10)
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DETAIL VIEW (CÓ CHIA FOLDER, HIỂN THỊ NOTE CỰC ĐẸP)
// ═══════════════════════════════════════════════════════════════
struct PatchGameDetailView: View {
    let game: GameSelection; @ObservedObject var store: PatchProjectStore; @Binding var actionAlert: PatchStoreAlert?; let language: AppLanguage
    @Environment(\.dismiss) private var dismiss; @Environment(\.scenePhase) private var scenePhase
    @State private var activationInfo: ActivationInfo?; @State private var selectedFolder: String? = nil
    @State private var workingFileID: String? = nil; @State private var renameItem: PatchLibraryItem?; @State private var renameText: String = ""
    @State private var tagPickerItem: PatchLibraryItem?; @State private var noteItem: PatchLibraryItem?; @State private var noteText: String = ""
    @State private var refreshTick: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) { topBar; folderBar; listContent }
            }
            .navigationBarHidden(true)
            .onAppear { store.reload(); syncFolders() }
            .alert(item: $actionAlert) { a in Alert(title: Text(a.titleKey), message: Text(a.message(language: language)), dismissButton: .default(Text("OK"))) }
            .alert("Đổi tên", isPresented: renameBinding) {
                TextField("Tên mới", text: $renameText); Button("Huỷ", role: .cancel) { renameItem = nil }; Button("Lưu") { commitRename() }
            }
            .alert("Ghi chú", isPresented: noteBinding) {
                TextField("Ghi chú", text: $noteText); Button("Huỷ", role: .cancel) { noteItem = nil }; Button("Lưu") { commitNote() }
            }
            .confirmationDialog("Chọn tag", isPresented: tagBinding, titleVisibility: .visible) {
                Button("VIP 👑") { commitTag("VIP") }; Button("FREE 🛡") { commitTag("FREE") }; Button("Huỷ", role: .cancel) { tagPickerItem = nil }
            }
            .fullScreenCover(item: $activationInfo) { i in ActivationNoteSheet(info: i) { activationInfo = nil } }
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { SoundFX.tap(); dismiss() } label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06)).frame(width: 40, height: 40).overlay(Circle().strokeBorder(.white, lineWidth: 1.4))
                    Image(systemName: "arrow.left").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                }
            }.buttonStyle(.plain)
            Text(game.title).font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
            Spacer()
        }.padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 12)
    }

    @ViewBuilder private var folderBar: some View {
        if folders.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(folders, id: \.self) { f in
                        FolderPill(title: f, count: gameItems.filter { folderName(for: $0) == f }.count, isActive: selectedFolder == f) {
                            SoundFX.tap(); withAnimation { selectedFolder = f }
                        }
                    }
                }.padding(.horizontal, 18)
            }.padding(.bottom, 14)
        }
    }

    private func syncFolders() { let c = folders; if c.isEmpty { selectedFolder = nil; return }; if let s = selectedFolder, c.contains(s) { return }; selectedFolder = c.first }
    private var gameItems: [PatchLibraryItem] { _ = refreshTick; return store.items.filter { GameTypeHelper.prefixOf($0) == game.prefix } }
    private var folders: [String] { var u: [String] = []; for item in gameItems { let f = folderName(for: item); if !f.isEmpty && !u.contains(f) { u.append(f) } }; return u.sorted() }
    private var displayedItems: [PatchLibraryItem] { if folders.count <= 1 { return gameItems }; guard let s = selectedFolder else { return [] }; return gameItems.filter { folderName(for: $0) == s } }
    
    private var renameBinding: Binding<Bool> { Binding(get: { renameItem != nil }, set: { if !$0 { renameItem = nil } }) }
    private var tagBinding: Binding<Bool> { Binding(get: { tagPickerItem != nil }, set: { if !$0 { tagPickerItem = nil } }) }
    private var noteBinding: Binding<Bool> { Binding(get: { noteItem != nil }, set: { if !$0 { noteItem = nil } }) }

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            if displayedItems.isEmpty {
                EmptyStateView(message: folders.isEmpty ? "Chưa có folder nào.\nĐang đồng bộ..." : "Folder này chưa có patch nào.")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(displayedItems) { item in patchRow(item: item) }
                }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 40)
            }
        }
    }

    private func patchRow(item: PatchLibraryItem) -> some View {
        let r = DevicePatchService.latestReceipt(projectID: item.id); let applied = (r != nil); let n = displayName(for: item)
        return PatchCard(
            isApplied: applied, isWorking: workingFileID == item.id.uuidString, displayName: n, tag: currentTag(for: item), note: currentNote(for: item),
            onToggle: { nv in if nv { SoundFX.tingTing() } else { SoundFX.tap() }; togglePatch(item: item, activate: nv) },
            onTapTag: { SoundFX.tap(); tagPickerItem = item },
            onRename: { SoundFX.tap(); renameItem = item; renameText = n },
            onEditNote: { SoundFX.tap(); noteItem = item; noteText = currentNote(for: item) }
        )
    }

    private func localKey(for i: PatchLibraryItem) -> String { i.packageURL.lastPathComponent }
    private func meta(for i: PatchLibraryItem) -> PatchMeta? { PatchMetaStore.get(localName: localKey(for: i)) }
    private func displayName(for i: PatchLibraryItem) -> String { if let m = meta(for: i), !m.displayName.isEmpty { return m.displayName }; if let n = i.project?.name, !n.isEmpty { return n }; var b = i.packageURL.deletingPathExtension().lastPathComponent; b = b.replacingOccurrences(of: "_VIP", with: "").replacingOccurrences(of: "_FREE", with: ""); return b }
    private func currentTag(for i: PatchLibraryItem) -> String { if let m = meta(for: i), !m.tag.isEmpty { return m.tag }; return i.packageURL.deletingPathExtension().lastPathComponent.hasSuffix("_VIP") ? "VIP" : "FREE" }
    private func currentNote(for i: PatchLibraryItem) -> String { meta(for: i)?.note ?? "" }
    private func folderName(for i: PatchLibraryItem) -> String { if let m = meta(for: i), !m.folder.isEmpty { return m.folder }; return "CHƯA PHÂN LOẠI" }

    private func commitRename() { guard let i = renameItem else { return }; let t = renameText.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { renameItem = nil; return }; let ln = localKey(for: i); guard var m = PatchMetaStore.get(localName: ln) else { renameItem = nil; return }; m.displayName = t; m.nameOverride = true; PatchMetaStore.set(m, localName: ln); store.reload(); renameItem = nil }
    private func commitTag(_ tag: String) { guard let i = tagPickerItem else { return }; let ln = localKey(for: i); guard var m = PatchMetaStore.get(localName: ln) else { tagPickerItem = nil; return }; m.tag = tag; m.tagOverride = true; PatchMetaStore.set(m, localName: ln); store.reload(); tagPickerItem = nil }
    private func commitNote() { guard let i = noteItem else { return }; let t = noteText.trimmingCharacters(in: .whitespacesAndNewlines); let ln = localKey(for: i); guard var m = PatchMetaStore.get(localName: ln) else { noteItem = nil; return }; m.note = t; m.noteOverride = true; PatchMetaStore.set(m, localName: ln); store.reload(); noteItem = nil }

    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        workingFileID = item.id.uuidString; let nameSnap = displayName(for: item); let tagSnap = currentTag(for: item); let noteSnap = currentNote(for: item)
        let targetFolder = folderName(for: item); let gp = game.prefix
        let conflictIDs: [UUID] = activate ? store.items.compactMap { o in guard o.id != item.id, GameTypeHelper.prefixOf(o) == gp, folderName(for: o) == targetFolder, DevicePatchService.latestReceipt(projectID: o.id) != nil else { return nil }; return o.id } : []

        Task.detached(priority: .userInitiated) {
            for cid in conflictIDs { if let r = DevicePatchService.latestReceipt(projectID: cid) { try? DevicePatchService.restore(receipt: r) } }
            if !activate {
                do { if let r = DevicePatchService.latestReceipt(projectID: item.id) { try DevicePatchService.restore(receipt: r) }; await MainActor.run { store.reload(); workingFileID = nil } }
                catch { await MainActor.run { workingFileID = nil; SoundFX.error(); activationInfo = ActivationInfo(patchName: nameSnap, tag: tagSnap, note: noteSnap, success: false, errorMessage: "Không thể tắt: \(error.localizedDescription)") } }
                return
            }
            await MainActor.run { MaxShield.shared.activate(duration: 12.0) }
            do {
                guard let p = item.project else { await MainActor.run { MaxShield.shared.deactivate(); workingFileID = nil }; return }
                _ = try DevicePatchService.apply(project: p); try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run { MaxShield.shared.deactivate(); store.reload(); workingFileID = nil; SoundFX.success(); activationInfo = ActivationInfo(patchName: nameSnap, tag: tagSnap, note: noteSnap, success: true, errorMessage: nil) }
            } catch {
                await MainActor.run { MaxShield.shared.deactivate(); store.reload(); workingFileID = nil; SoundFX.error(); activationInfo = ActivationInfo(patchName: nameSnap, tag: tagSnap, note: noteSnap, success: false, errorMessage: error.localizedDescription) }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SYNC ENGINE (DispatchQueue an toàn với Swift 6)
// ═══════════════════════════════════════════════════════════════
final class SyncEngine {
    static let shared = SyncEngine()
    private let syncQueue = DispatchQueue(label: "com.zenith.syncQueue")
    private var isRunning = false
    private init() {}

    func run(store: PatchProjectStore) async {
        if isRunning { return }; isRunning = true; defer { isRunning = false }
        guard let remotes = await fetchRemotes() else { return }
        
        await MainActor.run { store.reload() }
        let items = await MainActor.run { store.items }
        let storeFiles = Set(items.map { $0.packageURL.lastPathComponent })

        for item in items {
            let ln = item.packageURL.lastPathComponent
            if PatchMetaStore.get(localName: ln) != nil { continue }
            if let r = remotes.first(where: { $0.filename == ln }) { syncQueue.sync { PatchMetaStore.set(makeMeta(r, localName: ln), localName: ln) } }
        }

        var missing: [RemoteFileLite] = []
        for r in remotes {
            if !storeFiles.contains(r.filename) { missing.append(r) }
            else if PatchMetaStore.get(localName: r.filename) == nil { syncQueue.sync { PatchMetaStore.set(makeMeta(r, localName: r.filename), localName: r.filename) } }
        }

        guard !missing.isEmpty else { await MainActor.run { store.reload() }; return }
        for r in missing {
            var ok = false
            for attempt in 1...3 {
                ok = await importOne(remote: r, store: store)
                if ok { break }; if attempt < 3 { try? await Task.sleep(nanoseconds: 700_000_000) }
            }
        }
        await MainActor.run { store.reload() }
    }

    private func makeMeta(_ r: RemoteFileLite, localName: String) -> PatchMeta {
        PatchMeta(uid: r.uid, localName: localName, remoteName: r.filename, gameType: r.gameType, folder: r.folder, tag: r.tag, displayName: r.displayName, note: r.note)
    }

    private func importOne(remote: RemoteFileLite, store: PatchProjectStore) async -> Bool {
        guard let url = URL(string: remote.url) else { return false }
        let before = await MainActor.run { Set(store.items.map { $0.packageURL.lastPathComponent }) }
        await MainActor.run { store.importPackage(from: .remote(url)) }

        for i in 0..<300 {
            try? await Task.sleep(nanoseconds: 300_000_000)
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
        let ts = Int(Date().timeIntervalSince1970)
        guard let url = URL(string: "https://solitudepremium.click/ipa/ipa/list.php?t=\(ts)") else { return nil }
        do {
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            req.timeoutInterval = 15
            req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            let (data, _) = try await URLSession.shared.data(for: req)
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

private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore
    func body(content: Content) -> some View { content.sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { r in PatchUnlockView(store: store, request: r) } }
}
extension View { func patchStorePresentation(_ store: PatchProjectStore) -> some View { modifier(PatchStorePresentationModifier(store: store)) } }
