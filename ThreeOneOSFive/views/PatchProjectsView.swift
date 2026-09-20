import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

// ═══════════════════════════════════════════════════════════════
// MARK: - THEME CHUẨN ĐEN / TRẮNG NEON
// ═══════════════════════════════════════════════════════════════
enum Theme {
    static let bg = Color.black
    static let surface = Color(white: 0.05)
    static let border = Color.white.opacity(0.2)
    static let glow = Color.white.opacity(0.4)
    static let text = Color.white
    static let textMuted = Color.white.opacity(0.5)
}

struct NeonBackgroundView: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.glow.opacity(0.15), .clear], center: .topLeading, startRadius: 50, endRadius: 500)
            RadialGradient(colors: [Theme.glow.opacity(0.1), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 400)
        }.ignoresSafeArea()
    }
}

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { AudioServicesPlaySystemSound(1057) }
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
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
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
                    Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 140, height: 140).scaleEffect(pulse ? 1.1 : 0.9)
                    ProgressView().tint(.white).scaleEffect(1.6)
                }
                VStack(spacing: 10) {
                    Text("ZENITH SYSTEM").font(.system(size: 11, weight: .heavy)).tracking(4).foregroundStyle(.white.opacity(0.6))
                    Text("ĐANG KÍCH HOẠT\(dots)").font(.system(size: 16, weight: .heavy)).tracking(2).foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { pulse = true }
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                dots = String(repeating: ".", count: (dots.count + 1) % 4)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MODELS & STORE
// ═══════════════════════════════════════════════════════════════
struct GameSelection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let prefix: String
}

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
// MARK: - REUSABLE UI
// ═══════════════════════════════════════════════════════════════
struct GlowCard<Content: View>: View {
    let isWorking: Bool
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(isWorking ? Theme.text : Theme.border, lineWidth: isWorking ? 1.5 : 1))
            .shadow(color: isWorking ? Theme.glow : .clear, radius: 10)
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
        .padding(.horizontal, 10).padding(.vertical, 5)
        .foregroundStyle(isVIP ? .black : .white)
        .background(Capsule().fill(isVIP ? .white : Color.white.opacity(0.1)))
        .overlay(Capsule().strokeBorder(.white, lineWidth: 1.5))
        .shadow(color: isVIP ? Theme.glow : .clear, radius: 8)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MAIN PROJECTS VIEW
// ═══════════════════════════════════════════════════════════════
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: PatchProjectStore

    @State private var actionAlert: PatchStoreAlert?
    @State private var selectedGame: GameSelection?
    @State private var showSilentSubmenu = false
    @State private var isSyncing = false
    
    // Timer ngầm, vô cùng nhẹ nhàng, không gây lag
    let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) {
                    header
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            gameCard("FREE FIRE MAX", "PREMIUM EDITION", "ffmax")
                            gameCard("FREE FIRE THƯỜNG", "CLASSIC EDITION", "ffnormal")
                            silentCard()
                        }.padding(.horizontal, 20).padding(.bottom, 50)
                    }
                    .refreshable { await syncNow() }
                }
            }
            .navigationBarHidden(true)
            .onAppear { store.reload(); Task { await syncNow() } }
            .onChange(of: scenePhase) { p in if p == .active { Task { await syncNow() } } }
            .onReceive(timer) { _ in Task { await syncNow() } }
            .sheet(item: $selectedGame) { g in PatchGameDetailView(game: g, store: store, actionAlert: $actionAlert, language: language) }
            .sheet(isPresented: $showSilentSubmenu) {
                SilentSubMenuSheet(onSelect: { prefix in
                    showSilentSubmenu = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        selectedGame = GameSelection(title: prefix == "silent_ffmax" ? "Menu Silent · FF Max" : "Menu Silent · FF Thường", prefix: prefix)
                    }
                }, onCancel: { showSilentSubmenu = false })
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(isSyncing ? Color.white : Color.gray).frame(width: 8, height: 8)
                        .shadow(color: isSyncing ? Theme.glow : .clear, radius: 4)
                    Text(isSyncing ? "SYNCING..." : "CONNECTED").font(.system(size: 10, weight: .heavy)).tracking(1).foregroundColor(Theme.textMuted)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().strokeBorder(Theme.border, lineWidth: 1))
            }.padding(.horizontal, 20).padding(.top, 10)
            
            Text("ZENITH SOLITUDE")
                .font(.system(size: 26, weight: .black, design: .serif))
                .tracking(4).foregroundStyle(Theme.text)
                .shadow(color: Theme.glow, radius: 15)
            
            Text("PREMIUM HEADLOCK SYSTEM")
                .font(.system(size: 10, weight: .heavy)).tracking(5).foregroundStyle(Theme.textMuted)
                .padding(.bottom, 24)
        }
    }

    private func gameCard(_ t: String, _ s: String, _ p: String) -> some View {
        Button { SoundFX.menu(); selectedGame = GameSelection(title: t, prefix: p) } label: {
            GlowCard(isWorking: false) {
                HStack(spacing: 16) {
                    Image(systemName: "gamecontroller.fill").font(.system(size: 22)).foregroundColor(.black)
                        .frame(width: 50, height: 50).background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t).font(.system(size: 16, weight: .heavy)).foregroundColor(Theme.text)
                        Text(s).font(.system(size: 9.5, weight: .bold)).tracking(2).foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.textMuted)
                }.padding(16)
            }
        }.buttonStyle(.plain)
    }

    private func silentCard() -> some View {
        Button { SoundFX.menu(); showSilentSubmenu = true } label: {
            GlowCard(isWorking: false) {
                HStack(spacing: 16) {
                    Image(systemName: "speaker.slash.fill").font(.system(size: 22)).foregroundColor(.white)
                        .frame(width: 50, height: 50).background(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MENU SILENT").font(.system(size: 16, weight: .heavy)).foregroundColor(Theme.text)
                        Text("STEALTH MODE").font(.system(size: 9.5, weight: .bold)).tracking(2).foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.textMuted)
                }.padding(16)
            }
        }.buttonStyle(.plain)
    }

    @MainActor
    private func syncNow() async {
        guard !isSyncing else { return }; isSyncing = true
        await SyncEngine.shared.run(store: store)
        store.reload(); isSyncing = false
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SILENT SUB-MENU
// ═══════════════════════════════════════════════════════════════
struct SilentSubMenuSheet: View {
    let onSelect: (String) -> Void
    let onCancel: () -> Void
    var body: some View {
        ZStack {
            NeonBackgroundView()
            VStack(spacing: 24) {
                Spacer()
                Text("MENU SILENT").font(.system(size: 22, weight: .heavy)).tracking(3).foregroundStyle(.white)
                VStack(spacing: 16) {
                    optionCard("Free Fire Max", "PREMIUM", "silent_ffmax")
                    optionCard("Free Fire Thường", "CLASSIC", "silent_ffnormal")
                }.padding(.horizontal, 24)
                Spacer()
                Button(action: { SoundFX.tap(); onCancel() }) {
                    Text("HUỶ").font(.system(size: 14, weight: .heavy)).tracking(2)
                        .foregroundColor(Theme.text).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.border, lineWidth: 2))
                }.padding(.horizontal, 40).padding(.bottom, 40)
            }
        }
    }
    private func optionCard(_ t: String, _ s: String, _ p: String) -> some View {
        Button(action: { SoundFX.menu(); onSelect(p) }) {
            GlowCard(isWorking: false) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t).font(.system(size: 16, weight: .heavy)).foregroundColor(.white)
                        Text(s).font(.system(size: 10, weight: .bold)).tracking(2).foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(Theme.textMuted)
                }.padding(20)
            }
        }.buttonStyle(.plain)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DETAIL VIEW (QUẢN LÝ FOLDERS & PATCH)
// ═══════════════════════════════════════════════════════════════
struct PatchGameDetailView: View {
    let game: GameSelection
    @ObservedObject var store: PatchProjectStore
    @Binding var actionAlert: PatchStoreAlert?
    let language: AppLanguage
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFolder: String? = nil
    @State private var workingFileID: String? = nil
    @State private var activationInfo: ActivationInfo?

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) { topBar; folderBar; listContent }
            }
            .navigationBarHidden(true)
            .onAppear { store.reload(); syncFolders() }
            .fullScreenCover(item: $activationInfo) { i in ActivationNoteSheet(info: i) { activationInfo = nil } }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { SoundFX.tap(); dismiss() }) {
                Image(systemName: "arrow.left").font(.system(size: 16, weight: .heavy)).foregroundColor(.white)
                    .frame(width: 44, height: 44).background(Circle().strokeBorder(Theme.border))
            }
            Spacer()
            Text(game.title).font(.system(size: 16, weight: .heavy)).tracking(1.5).foregroundColor(.white)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }.padding(20)
    }

    private var folderBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(folders, id: \.self) { f in
                    let isActive = selectedFolder == f
                    Button(action: { SoundFX.tap(); withAnimation { selectedFolder = f } }) {
                        Text(f).font(.system(size: 12, weight: .heavy)).tracking(1)
                            .foregroundColor(isActive ? .black : .white)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Capsule().fill(isActive ? Color.white : Color.clear))
                            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: isActive ? 0 : 1.5))
                            .shadow(color: isActive ? Theme.glow : .clear, radius: 8)
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 20)
        }.padding(.bottom, 16)
    }

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                if displayedItems.isEmpty {
                    Text("CHƯA CÓ DỮ LIỆU").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.textMuted).padding(.top, 50)
                } else {
                    ForEach(displayedItems) { item in
                        let r = DevicePatchService.latestReceipt(projectID: item.id)
                        let isApplied = (r != nil)
                        PatchCardUI(
                            isApplied: isApplied,
                            isWorking: workingFileID == item.id.uuidString,
                            name: displayName(for: item),
                            tag: currentTag(for: item),
                            note: currentNote(for: item),
                            onToggle: { nv in
                                if nv { SoundFX.tingTing() } else { SoundFX.tap() }
                                togglePatch(item: item, activate: nv)
                            }
                        )
                    }
                }
            }.padding(.horizontal, 20).padding(.bottom, 50)
        }
    }

    private var gameItems: [PatchLibraryItem] { store.items.filter { GameTypeHelper.prefixOf($0) == game.prefix } }
    private var folders: [String] {
        var u: [String] = []
        for i in gameItems { let f = folderName(for: i); if !f.isEmpty && !u.contains(f) { u.append(f) } }
        return u.sorted()
    }
    private var displayedItems: [PatchLibraryItem] {
        if folders.count <= 1 { return gameItems }
        guard let s = selectedFolder else { return [] }
        return gameItems.filter { folderName(for: $0) == s }
    }
    private func syncFolders() {
        let c = folders; if c.isEmpty { selectedFolder = nil; return }
        if let s = selectedFolder, c.contains(s) { return }
        selectedFolder = c.first
    }
    private func meta(for i: PatchLibraryItem) -> PatchMeta? { PatchMetaStore.get(localName: i.packageURL.lastPathComponent) }
    private func displayName(for i: PatchLibraryItem) -> String { meta(for: i)?.displayName ?? i.packageURL.deletingPathExtension().lastPathComponent }
    private func currentTag(for i: PatchLibraryItem) -> String { meta(for: i)?.tag ?? "FREE" }
    private func currentNote(for i: PatchLibraryItem) -> String { meta(for: i)?.note ?? "" }
    private func folderName(for i: PatchLibraryItem) -> String { meta(for: i)?.folder ?? "CHƯA PHÂN LOẠI" }

    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        workingFileID = item.id.uuidString
        let nameSnap = displayName(for: item); let tagSnap = currentTag(for: item); let noteSnap = currentNote(for: item)
        let gp = game.prefix; let targetFolder = folderName(for: item)
        let conflictIDs: [UUID] = activate ? store.items.compactMap { o in
            guard o.id != item.id, GameTypeHelper.prefixOf(o) == gp, folderName(for: o) == targetFolder, DevicePatchService.latestReceipt(projectID: o.id) != nil else { return nil }
            return o.id
        } : []

        Task.detached(priority: .userInitiated) {
            for cid in conflictIDs { if let r = DevicePatchService.latestReceipt(projectID: cid) { try? DevicePatchService.restore(receipt: r) } }
            if !activate {
                if let r = DevicePatchService.latestReceipt(projectID: item.id) { try? DevicePatchService.restore(receipt: r) }
                await MainActor.run { store.reload(); workingFileID = nil }
                return
            }
            await MainActor.run { MaxShield.shared.activate(duration: 12.0) }
            do {
                guard let p = item.project else { throw NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Project"]) }
                _ = try DevicePatchService.apply(project: p)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    MaxShield.shared.deactivate(); store.reload(); workingFileID = nil; SoundFX.success()
                    activationInfo = ActivationInfo(patchName: nameSnap, tag: tagSnap, note: noteSnap, success: true, errorMessage: nil)
                }
            } catch {
                await MainActor.run {
                    MaxShield.shared.deactivate(); store.reload(); workingFileID = nil; SoundFX.error()
                    activationInfo = ActivationInfo(patchName: nameSnap, tag: tagSnap, note: noteSnap, success: false, errorMessage: error.localizedDescription)
                }
            }
        }
    }
}

struct PatchCardUI: View {
    let isApplied: Bool
    let isWorking: Bool
    let name: String
    let tag: String
    let note: String
    let onToggle: (Bool) -> Void
    
    var body: some View {
        GlowCard(isWorking: isApplied || isWorking) {
            HStack(spacing: 14) {
                Circle()
                    .strokeBorder(isApplied ? Theme.text : Theme.border, lineWidth: 2)
                    .background(Circle().fill(isApplied ? Theme.text : Color.clear))
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundColor(.black).opacity(isApplied ? 1 : 0))
                    .shadow(color: isApplied ? Theme.glow : .clear, radius: 6)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(name).font(.system(size: 15, weight: .heavy)).foregroundColor(.white).lineLimit(1)
                    if !note.isEmpty { Text(note).font(.system(size: 11, weight: .medium)).foregroundColor(Theme.textMuted).lineLimit(1) }
                }
                Spacer()
                TagPill(tag: tag)
                
                if isWorking {
                    ProgressView().tint(.white).frame(width: 50, height: 30)
                } else {
                    Toggle("", isOn: Binding(get: { isApplied }, set: { onToggle($0) })).labelsHidden().tint(.white)
                }
            }.padding(16)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SHEET THÔNG BÁO BẬT TẮT
// ═══════════════════════════════════════════════════════════════
struct ActivationNoteSheet: View {
    let info: ActivationInfo
    let onDismiss: () -> Void
    var body: some View {
        ZStack {
            NeonBackgroundView()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: info.success ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 80)).foregroundColor(info.success ? .white : .red)
                    .shadow(color: info.success ? Theme.glow : .red.opacity(0.5), radius: 20)
                
                Text(info.success ? "KÍCH HOẠT THÀNH CÔNG" : "LỖI KÍCH HOẠT")
                    .font(.system(size: 20, weight: .heavy)).tracking(2).foregroundColor(info.success ? .white : .red)
                Text(info.patchName).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                
                if !info.success, let e = info.errorMessage { Text(e).font(.system(size: 12)).foregroundColor(.red).multilineTextAlignment(.center).padding(.horizontal, 20) }
                if !info.note.isEmpty { Text(info.note).font(.system(size: 13)).foregroundColor(Theme.textMuted).multilineTextAlignment(.center).padding(.horizontal, 20) }
                
                Spacer()
                Button(action: { SoundFX.tap(); onDismiss() }) {
                    Text("ĐÃ HIỂU").font(.system(size: 14, weight: .heavy)).tracking(2)
                        .foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                }.padding(.horizontal, 40).padding(.bottom, 40)
            }
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
        if isRunning { return }; isRunning = true; defer { isRunning = false }
        guard let remotes = await fetchRemotes() else { return }
        
        await MainActor.run { store.reload() }
        let items = await MainActor.run { store.items }
        let storeFiles = Set(items.map { $0.packageURL.lastPathComponent })

        for item in items {
            let ln = item.packageURL.lastPathComponent
            if PatchMetaStore.get(localName: ln) != nil { continue }
            if let r = remotes.first(where: { $0.filename == ln }) {
                lock.lock(); PatchMetaStore.set(makeMeta(r, localName: ln), localName: ln); lock.unlock()
            }
        }
        var missing: [RemoteFileLite] = []
        for r in remotes {
            if !storeFiles.contains(r.filename) { missing.append(r) }
            else if PatchMetaStore.get(localName: r.filename) == nil {
                lock.lock(); PatchMetaStore.set(makeMeta(r, localName: r.filename), localName: r.filename); lock.unlock()
            }
        }
        guard !missing.isEmpty else { await MainActor.run { store.reload() }; return }

        for r in missing {
            var ok = false
            for attempt in 1...3 {
                ok = await importOne(remote: r, store: store)
                if ok { break }
                if attempt < 3 { try? await Task.sleep(nanoseconds: 500_000_000) }
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

        for _ in 0..<15 { 
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run { store.reload() }
            let after = await MainActor.run { Set(store.items.map { $0.packageURL.lastPathComponent }) }
            let newFiles = after.subtracting(before)
            guard !newFiles.isEmpty else { continue }
            let chosen = newFiles.first(where: { $0 == remote.filename }) ?? newFiles.first(where: { $0.hasSuffix(remote.filename) || remote.filename.hasSuffix($0) }) ?? newFiles.first
            guard let local = chosen else { continue }
            
            lock.lock(); PatchMetaStore.set(makeMeta(remote, localName: local), localName: local); lock.unlock()
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
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // Xóa sạch bộ nhớ tạm
            req.timeoutInterval = 10
            req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            let (data, _) = try await URLSession.shared.data(for: req)
            
            struct Wire: Decodable { let uid: String?, filename: String, gameType: String, folder: String?, displayName: String?, tag: String?, note: String?, url: String }
            let wire = try JSONDecoder().decode([Wire].self, from: data)
            return wire.map { w in RemoteFileLite(filename: w.filename, gameType: w.gameType, folder: w.folder ?? "Chung", tag: w.tag ?? "FREE", displayName: w.displayName ?? "", note: w.note ?? "", url: w.url) }
        } catch { return nil }
    }
}
