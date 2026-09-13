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
// MARK: - GPU ACCELERATED BACKGROUND (Tối ưu chống Lag)
// ═══════════════════════════════════════════════════════════════
struct NeonBackgroundView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.05).ignoresSafeArea() // Deep dark space
            AuroraView()
            CosmicFieldView(paused: scenePhase != .active)
            VignetteView()
        }
        .drawingGroup() // 🚀 Đẩy render sang GPU, mượt mà 60 FPS
        .ignoresSafeArea()
    }
}

struct AuroraView: View {
    @State private var phase: Double = 0
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                Circle()
                    .fill(Color(red: 0.2, green: 0.8, blue: 0.9).opacity(0.15))
                    .frame(width: width * 1.2)
                    .blur(radius: 60)
                    .offset(x: sin(phase) * 60, y: cos(phase * 0.7) * 80 - 150)
                
                Circle()
                    .fill(Color(red: 0.6, green: 0.2, blue: 0.9).opacity(0.12))
                    .frame(width: width * 1.5)
                    .blur(radius: 80)
                    .offset(x: cos(phase * 0.8) * 80, y: sin(phase * 0.6) * 100 + 150)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

struct VignetteView: View {
    var body: some View {
        RadialGradient(
            colors: [.clear, Color.black.opacity(0.85)],
            center: .center, startRadius: 100, endRadius: 600
        )
        .allowsHitTesting(false)
    }
}

struct CosmicFieldView: View {
    var paused: Bool = false
    private struct Particle: Hashable {
        let x: CGFloat, y: CGFloat, speed: CGFloat, scale: CGFloat, opacity: Double
    }
    
    @State private var particles: [Particle] = (0..<40).map { _ in
        Particle(x: .random(in: 0...1), y: .random(in: 0...1), speed: .random(in: 10...30), scale: .random(in: 0.5...2.5), opacity: .random(in: 0.2...0.8))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for p in particles {
                    let yOffset = CGFloat(t) * p.speed
                    let y = size.height - (yOffset.truncatingRemainder(dividingBy: size.height + 50))
                    let x = (p.x * size.width) + sin(t + Double(p.x)) * 10
                    let rect = CGRect(x: x, y: y, width: p.scale, height: p.scale)
                    ctx.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(p.opacity)))
                }
            }
        }
        .allowsHitTesting(false)
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

// (PatchMeta, RemoteFileLite, ActivationInfo, PatchMetaStore giữ nguyên logic gốc để không phá vỡ liên kết dữ liệu)
struct PatchMeta: Codable {
    var remoteKey: String; var remoteName: String; var gameType: String; var folder: String; var tag: String
    var displayName: String; var note: String; var tagOverride: Bool; var nameOverride: Bool; var noteOverride: Bool; var orphaned: Bool
    
    init(remoteKey: String, remoteName: String, gameType: String, folder: String, tag: String, displayName: String, note: String, tagOverride: Bool = false, nameOverride: Bool = false, noteOverride: Bool = false, orphaned: Bool = false) {
        self.remoteKey = remoteKey; self.remoteName = remoteName; self.gameType = gameType; self.folder = folder; self.tag = tag; self.displayName = displayName; self.note = note; self.tagOverride = tagOverride; self.nameOverride = nameOverride; self.noteOverride = noteOverride; self.orphaned = orphaned
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        remoteKey = (try? c.decode(String.self, forKey: .remoteKey)) ?? ""
        remoteName = (try? c.decode(String.self, forKey: .remoteName)) ?? ""
        gameType = (try? c.decode(String.self, forKey: .gameType)) ?? "ffnormal"
        folder = (try? c.decode(String.self, forKey: .folder)) ?? "Chung"
        tag = (try? c.decode(String.self, forKey: .tag)) ?? "FREE"
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        note = (try? c.decode(String.self, forKey: .note)) ?? ""
        tagOverride = (try? c.decode(Bool.self, forKey: .tagOverride)) ?? false
        nameOverride = (try? c.decode(Bool.self, forKey: .nameOverride)) ?? false
        noteOverride = (try? c.decode(Bool.self, forKey: .noteOverride)) ?? false
        orphaned = (try? c.decode(Bool.self, forKey: .orphaned)) ?? false
    }
}

struct RemoteFileLite {
    let filename: String; let gameType: String; let folder: String; let tag: String; let displayName: String; let note: String; let url: String
    var compositeKey: String { "\(gameType)/\(folder)/\(filename)" }
}

struct ActivationInfo: Identifiable {
    let id = UUID()
    let patchName: String; let note: String; let success: Bool; let errorMessage: String?
}

enum PatchMetaStore {
    private static let key = "patch_meta_v15"
    static func all() -> [String: PatchMeta] {
        guard let data = UserDefaults.standard.data(forKey: key), let dict = try? JSONDecoder().decode([String: PatchMeta].self, from: data) else { return [:] }
        return dict
    }
    static func save(_ dict: [String: PatchMeta]) {
        if let data = try? JSONEncoder().encode(dict) { UserDefaults.standard.set(data, forKey: key) }
    }
    static func set(_ meta: PatchMeta, forLocal local: String) {
        var d = all(); d[local] = meta; save(d)
    }
    static func get(forLocal local: String) -> PatchMeta? { return all()[local] }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - GLASSMORPHISM COMPONENTS
// ═══════════════════════════════════════════════════════════════
private struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.05))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 10)
    }
}

private struct FFLogoView: View {
    var body: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/free.jpg")) { phase in
            if let img = phase.image {
                img.resizable().scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    ProgressView().tint(.white)
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.6), lineWidth: 1))
        .shadow(color: .cyan.opacity(0.4), radius: 10)
    }
}

private struct AvatarView: View {
    @State private var rotate = false
    var body: some View {
        ZStack {
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 8]))
                .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 104, height: 104)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .shadow(color: .cyan.opacity(0.5), radius: 10)
            
            AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                if let img = phase.image { img.resizable().scaledToFill() } 
                else { Color.black }
            }
            .frame(width: 86, height: 86)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 2))
        }
        .onAppear {
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) { rotate = true }
        }
    }
}

private struct TagBadge: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    var body: some View {
        Text(tag)
            .font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(
                Capsule().fill(isVIP ? Color.yellow.opacity(0.2) : Color.cyan.opacity(0.2))
            )
            .foregroundStyle(isVIP ? Color.yellow : Color.cyan)
            .overlay(Capsule().stroke(isVIP ? Color.yellow.opacity(0.8) : Color.cyan.opacity(0.8), lineWidth: 1))
            .shadow(color: isVIP ? .yellow.opacity(0.4) : .cyan.opacity(0.4), radius: 5)
    }
}

private struct CustomToggle: View {
    var isOn: Bool
    var body: some View {
        ZStack {
            Capsule()
                .fill(isOn ? Color.cyan.opacity(0.2) : Color.white.opacity(0.1))
                .frame(width: 50, height: 26)
                .overlay(Capsule().stroke(isOn ? Color.cyan : Color.white.opacity(0.2), lineWidth: 1.5))
            
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .shadow(color: isOn ? .cyan : .clear, radius: 5)
                .offset(x: isOn ? 12 : -12)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isOn)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ROW & TABS
// ═══════════════════════════════════════════════════════════════
private struct PatchRow: View {
    let isApplied: Bool; let isWorking: Bool; let displayName: String; let tag: String; let note: String
    let onToggle: (Bool) -> Void; let onTapTag: () -> Void; let onRename: () -> Void; let onEditNote: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)).frame(width: 44, height: 44)
                Image(systemName: tag == "VIP" ? "crown.fill" : "shield.lefthalf.filled")
                    .font(.system(size: 20))
                    .foregroundStyle(tag == "VIP" ? LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
            }
            .shadow(color: tag == "VIP" ? .yellow.opacity(0.3) : .cyan.opacity(0.3), radius: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isApplied ? Color.cyan : Color.white)
                        .lineLimit(1)
                    Button(action: onTapTag) { TagBadge(tag: tag) }.buttonStyle(.plain)
                }
                if !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(2)
                }
            }
            Spacer()
            
            if isWorking {
                ProgressView().tint(.cyan).padding(.trailing, 8)
            } else {
                Button(action: { onToggle(!isApplied) }) {
                    CustomToggle(isOn: isApplied)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isApplied ? Color.cyan.opacity(0.1) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isApplied ? Color.cyan.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
        )
        .contextMenu {
            Button(action: onRename) { Label("Đổi tên", systemImage: "pencil") }
            Button(action: onTapTag) { Label("Đổi VIP/FREE", systemImage: "crown") }
            Button(action: onEditNote) { Label("Sửa ghi chú", systemImage: "note.text") }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ACTIVATION SHEET (Giữ Copy)
// ═══════════════════════════════════════════════════════════════
struct ActivationNoteSheet: View {
    let info: ActivationInfo; let onDismiss: () -> Void
    @State private var copied = false

    private var accent: Color { info.success ? .cyan : .red }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            Circle().fill(accent.opacity(0.15)).blur(radius: 100).frame(width: 300)
            
            VStack(spacing: 24) {
                Image(systemName: info.success ? "checkmark.shield.fill" : "xmark.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.5), radius: 15)
                    .padding(.top, 40)
                
                VStack(spacing: 8) {
                    Text(info.success ? "KÍCH HOẠT THÀNH CÔNG" : "LỖI KÍCH HOẠT")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(accent)
                    
                    Text(info.patchName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                if !info.note.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "note.text"); Text("GHI CHÚ HƯỚNG DẪN")
                                .font(.system(size: 12, weight: .bold)).foregroundStyle(.gray)
                        }
                        Text(info.note).font(.system(size: 14)).foregroundStyle(.white)
                        
                        Button {
                            SoundFX.tap(); UIPasteboard.general.string = info.note
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { copied = false } }
                        } label: {
                            HStack {
                                Image(systemName: copied ? "checkmark" : "doc.on.clipboard")
                                Text(copied ? "ĐÃ COPY" : "COPY GHI CHÚ")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .padding(.vertical, 10).frame(maxWidth: .infinity)
                            .background(copied ? Color.cyan : Color.white.opacity(0.1))
                            .foregroundStyle(copied ? .black : .white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(16).background(Color.white.opacity(0.05)).cornerRadius(16)
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                Button(action: { SoundFX.tap(); onDismiss() }) {
                    Text("ĐÓNG")
                        .font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity).padding()
                        .background(accent).foregroundStyle(.black).cornerRadius(16)
                        .padding(.horizontal, 24).padding(.bottom, 30)
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MAIN VIEW (Home)
// ═══════════════════════════════════════════════════════════════
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore

    @State private var actionAlert: PatchStoreAlert?
    @State private var selectedGame: GameSelection?
    @State private var isSyncing = false
    @State private var lastSyncDate: Date = Date()
    private let autoTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) {
                    header
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            gameCard(title: "Free Fire Max", prefix: "ffmax", desc: "Phiên bản tối ưu đồ họa cao")
                            gameCard(title: "Free Fire Thường", prefix: "ffnormal", desc: "Phiên bản chuẩn")
                            Text("Coded by Zenith Solitude").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(.white.opacity(0.3)).padding(.top, 20)
                        }
                        .padding(.horizontal, 20).padding(.bottom, 40)
                    }
                    .refreshable { await syncNow(force: true) }
                }
            }
            .onAppear { Task { await syncNow(force: true) } }
            .onReceive(autoTimer) { _ in Task { await syncNow(force: false) } }
            .sheet(item: $selectedGame) { game in
                PatchGameDetailView(game: game, store: store, actionAlert: $actionAlert, language: language)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(isSyncing ? Color.yellow : Color.cyan).frame(width: 8, height: 8)
                        .shadow(color: isSyncing ? .yellow : .cyan, radius: 5)
                    Text(isSyncing ? "ĐANG TẢI DỮ LIỆU" : "TRỰC TUYẾN")
                        .font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 12).padding(.vertical, 6).background(.ultraThinMaterial).cornerRadius(20)
            }.padding(.horizontal, 20).padding(.top, 10)
            
            AvatarView()
            Text("ZENITH SOLITUDE")
                .font(.system(size: 24, weight: .heavy, design: .serif)).tracking(3).foregroundStyle(.white)
                .shadow(color: .cyan.opacity(0.6), radius: 15)
            Text("PREMIUM PATCH MANAGER")
                .font(.system(size: 10, weight: .bold)).tracking(5).foregroundStyle(.cyan.opacity(0.8))
        }
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func gameCard(title: String, prefix: String, desc: String) -> some View {
        Button {
            SoundFX.menu(); selectedGame = GameSelection(title: title, prefix: prefix)
        } label: {
            GlassCard {
                HStack(spacing: 16) {
                    FFLogoView()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text(desc).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold)).foregroundStyle(.cyan)
                }
                .padding(16)
            }
        }.buttonStyle(.plain)
    }

    private func syncNow(force: Bool) async {
        if !force && Date().timeIntervalSince(lastSyncDate) < 2.0 { return }
        await MainActor.run { isSyncing = true }
        await SyncEngine.shared.run(store: store)
        await MainActor.run { isSyncing = false; lastSyncDate = Date() }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SYNC ENGINE (🚀 PARALLEL DOWNLOAD - SIÊU NHANH)
// ═══════════════════════════════════════════════════════════════
final class SyncEngine {
    static let shared = SyncEngine()
    private let metaLock = NSLock()
    private init() {}

    func run(store: PatchProjectStore) async {
        guard let remotes = await fetchRemotes() else { return }
        var remoteByKey: [String: RemoteFileLite] = [:]
        for r in remotes { remoteByKey[r.compositeKey] = r }

        metaLock.lock()
        var metaDict = PatchMetaStore.all()
        for (localName, var meta) in metaDict {
            let key = meta.remoteKey.isEmpty ? "\(meta.gameType)/\(meta.folder)/\(meta.remoteName)" : meta.remoteKey
            if let remote = remoteByKey[key] {
                meta.orphaned = false; meta.remoteKey = remote.compositeKey; meta.gameType = remote.gameType; meta.folder = remote.folder
                if !meta.tagOverride { meta.tag = remote.tag }
                if !meta.nameOverride { meta.displayName = remote.displayName }
                if !meta.noteOverride { meta.note = remote.note }
            } else { meta.orphaned = true }
            metaDict[localName] = meta
        }
        PatchMetaStore.save(metaDict)
        metaLock.unlock()

        var existingKeys = Set<String>()
        for meta in metaDict.values where !meta.orphaned {
            existingKeys.insert(meta.remoteKey.isEmpty ? "\(meta.gameType)/\(meta.folder)/\(meta.remoteName)" : meta.remoteKey)
        }

        // 🚀 TẢI SONG SONG (PARALLEL) THAY VÌ TUẦN TỰ
        await withTaskGroup(of: Void.self) { group in
            for remote in remotes where !existingKeys.contains(remote.compositeKey) {
                if let url = URL(string: remote.url) {
                    group.addTask { await self.importAndTag(remote: remote, url: url, store: store) }
                }
            }
        }
        await MainActor.run { store.reload() }
    }

    private func fetchRemotes() async -> [RemoteFileLite]? {
        let urlString = "https://solitudepremium.click/ipa/proxy/list.php?t=\(Int(Date().timeIntervalSince1970))"
        guard let url = URL(string: urlString) else { return nil }
        do {
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData; req.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: req)
            struct Wire: Decodable { let filename, gameType: String; let folder, displayName, tag, note: String?; let url: String }
            let wire = try JSONDecoder().decode([Wire].self, from: data)
            return wire.map { w in RemoteFileLite(filename: w.filename, gameType: w.gameType, folder: w.folder ?? "Chung", tag: w.tag ?? "FREE", displayName: w.displayName ?? "", note: w.note ?? "", url: w.url) }
        } catch { return nil }
    }

    private func importAndTag(remote: RemoteFileLite, url: URL, store: PatchProjectStore) async {
        let before = await MainActor.run { Set(store.items.map { $0.packageURL.lastPathComponent }) }
        await MainActor.run { store.importPackage(from: .remote(url)) }
        for _ in 0..<30 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run { store.reload() }
            let after = await MainActor.run { Set(store.items.map { $0.packageURL.lastPathComponent }) }
            if let newFile = after.subtracting(before).first {
                metaLock.lock()
                let meta = PatchMeta(remoteKey: remote.compositeKey, remoteName: remote.filename, gameType: remote.gameType, folder: remote.folder, tag: remote.tag, displayName: remote.displayName, note: remote.note, orphaned: false)
                PatchMetaStore.set(meta, forLocal: newFile)
                metaLock.unlock()
                return
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DETAIL VIEW (Folder trượt mượt mà)
// ═══════════════════════════════════════════════════════════════
struct PatchGameDetailView: View {
    let game: GameSelection; @ObservedObject var store: PatchProjectStore; @Binding var actionAlert: PatchStoreAlert?; let language: AppLanguage
    @Environment(\.dismiss) private var dismiss; @Environment(\.scenePhase) private var scenePhase
    
    @Namespace private var namespace // 🚀 Phục vụ hiệu ứng trượt Tab Folder
    @State private var activationInfo: ActivationInfo?
    @State private var selectedFolder: String? = nil
    @State private var workingFileID: String?
    
    @State private var renameItem: PatchLibraryItem?; @State private var renameText: String = ""
    @State private var tagPickerItem: PatchLibraryItem?
    @State private var noteItem: PatchLibraryItem?; @State private var noteText: String = ""
    @State private var refreshTick: Int = 0
    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) {
                    if !folders.isEmpty { folderTabs }
                    listContent
                }
            }
            .navigationTitle(game.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { SoundFX.tap(); dismiss() }) { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.8), .white.opacity(0.2)).font(.title3) }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                Task {
                    await SyncEngine.shared.run(store: store)
                    await MainActor.run { store.reload(); syncFolders() }
                }
            }
            .onReceive(refreshTimer) { _ in refreshTick &+= 1; store.reload(); syncFolders() }
            .fullScreenCover(item: $activationInfo) { info in ActivationNoteSheet(info: info) { activationInfo = nil } }
            
            // CÁC POPUP GIỮ NGUYÊN CODE GỐC
            .alert("Đổi tên", isPresented: Binding(get: { renameItem != nil }, set: { if !$0 { renameItem = nil } })) { TextField("Tên mới", text: $renameText); Button("Huỷ", role: .cancel) { renameItem = nil }; Button("Lưu") { commitRename() } }
            .alert("Ghi chú", isPresented: Binding(get: { noteItem != nil }, set: { if !$0 { noteItem = nil } })) { TextField("Ghi chú", text: $noteText); Button("Huỷ", role: .cancel) { noteItem = nil }; Button("Lưu") { commitNote() } }
            .confirmationDialog("Chọn tag", isPresented: Binding(get: { tagPickerItem != nil }, set: { if !$0 { tagPickerItem = nil } }), titleVisibility: .visible) { Button("VIP 👑") { commitTag("VIP") }; Button("FREE 🛡") { commitTag("FREE") }; Button("Huỷ", role: .cancel) { tagPickerItem = nil } }
        }
    }

    // 🚀 LOGIC ƯU TIÊN FOLDER ĐẦU TIÊN TỪ API
    private func syncFolders() {
        let currentFolders = folders
        if currentFolders.isEmpty { selectedFolder = nil; return }
        if let sel = selectedFolder, currentFolders.contains(sel) { return }
        selectedFolder = currentFolders.first // Luôn chọn Folder đầu tiên có sẵn
    }

    private var folders: [String] {
        let names = gameItems.map { folderName(for: $0) }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var unique: [String] = []
        for n in names { if !unique.contains(n) { unique.append(n) } }
        // 🚀 Sắp xếp: Tên Folder A-Z, đẩy chữ "Chung" xuống cuối cùng
        return unique.sorted {
            if $0.lowercased() == "chung" { return false }
            if $1.lowercased() == "chung" { return true }
            return $0 < $1
        }
    }

    private var gameItems: [PatchLibraryItem] {
        _ = refreshTick
        return store.items.filter { item in
            let name = item.packageURL.lastPathComponent; let meta = PatchMetaStore.get(forLocal: name)
            if let m = meta, !m.gameType.isEmpty { return !m.orphaned && m.gameType == game.prefix }
            let isMax = name.hasPrefix("ffmax_"); let isNormal = name.hasPrefix("ffnormal_")
            return game.prefix == "ffmax" ? isMax : (isNormal || (!isMax && !isNormal))
        }
    }
    private var displayedItems: [PatchLibraryItem] { guard let sel = selectedFolder else { return [] }; return gameItems.filter { folderName(for: $0) == sel } }

    private var folderTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(folders, id: \.self) { f in
                    let isSelected = selectedFolder == f
                    Text(f.uppercased())
                        .font(.system(size: 11, weight: .bold)).tracking(1)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.7))
                        .background {
                            if isSelected {
                                Capsule().fill(Color.cyan)
                                    .matchedGeometryEffect(id: "TabHighlight", in: namespace) // 🚀 Hiệu ứng trượt thanh
                                    .shadow(color: .cyan.opacity(0.6), radius: 8)
                            } else {
                                Capsule().fill(Color.white.opacity(0.05))
                            }
                        }
                        .onTapGesture {
                            SoundFX.tap()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedFolder = f }
                        }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12).background(Color.black.opacity(0.3)) // Tách biệt header và list
    }

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            if displayedItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray.fill").font(.system(size: 40)).foregroundStyle(.white.opacity(0.2))
                    Text(folders.isEmpty ? "Đang đồng bộ dữ liệu siêu tốc..." : "Thư mục trống").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                }.padding(.top, 100)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(displayedItems) { item in patchRow(item: item) }
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 40)
            }
        }
    }

    private func patchRow(item: PatchLibraryItem) -> some View {
        PatchRow(
            isApplied: DevicePatchService.latestReceipt(projectID: item.id) != nil,
            isWorking: workingFileID == item.id.uuidString,
            displayName: displayName(for: item), tag: currentTag(for: item), note: currentNote(for: item),
            onToggle: { nv in if nv { SoundFX.tingTing() } else { SoundFX.tap() }; togglePatch(item: item, activate: nv) },
            onTapTag: { SoundFX.tap(); tagPickerItem = item },
            onRename: { SoundFX.tap(); renameItem = item; renameText = displayName(for: item) },
            onEditNote: { SoundFX.tap(); noteItem = item; noteText = currentNote(for: item) }
        )
    }

    // Các hàm Helper (Giữ nguyên logic của bạn)
    private func localKey(for item: PatchLibraryItem) -> String { item.packageURL.lastPathComponent }
    private func meta(for item: PatchLibraryItem) -> PatchMeta? { PatchMetaStore.get(forLocal: localKey(for: item)) }
    private func displayName(for item: PatchLibraryItem) -> String {
        if let m = meta(for: item), !m.displayName.isEmpty { return m.displayName }
        if let n = item.project?.name, !n.isEmpty { return n }
        return item.packageURL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_VIP", with: "").replacingOccurrences(of: "_FREE", with: "").replacingOccurrences(of: "ffmax_", with: "").replacingOccurrences(of: "ffnormal_", with: "")
    }
    private func currentTag(for item: PatchLibraryItem) -> String { meta(for: item)?.tag ?? (item.packageURL.deletingPathExtension().lastPathComponent.hasSuffix("_VIP") ? "VIP" : "FREE") }
    private func currentNote(for item: PatchLibraryItem) -> String { meta(for: item)?.note ?? "" }
    private func folderName(for item: PatchLibraryItem) -> String {
        if let m = meta(for: item), !m.folder.isEmpty { return m.folder }
        return "Chung"
    }

    private func commitRename() { guard let item = renameItem else { return }; let t = renameText.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { renameItem = nil; return }; let key = localKey(for: item); if var m = PatchMetaStore.get(forLocal: key) { m.displayName = t; m.nameOverride = true; PatchMetaStore.set(m, forLocal: key) }; store.reload(); renameItem = nil }
    private func commitTag(_ tag: String) { guard let item = tagPickerItem else { return }; let key = localKey(for: item); if var m = PatchMetaStore.get(forLocal: key) { m.tag = tag; m.tagOverride = true; PatchMetaStore.set(m, forLocal: key) }; store.reload(); tagPickerItem = nil }
    private func commitNote() { guard let item = noteItem else { return }; let t = noteText.trimmingCharacters(in: .whitespacesAndNewlines); let key = localKey(for: item); if var m = PatchMetaStore.get(forLocal: key) { m.note = t; m.noteOverride = true; PatchMetaStore.set(m, forLocal: key) }; store.reload(); noteItem = nil }

    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        workingFileID = item.id.uuidString; let nameSnap = displayName(for: item); let noteSnap = currentNote(for: item)
        Task.detached(priority: .userInitiated) {
            do {
                if !activate {
                    if let r = DevicePatchService.latestReceipt(projectID: item.id) { try DevicePatchService.restore(receipt: r) }
                    await MainActor.run { store.reload(); workingFileID = nil }
                } else {
                    guard let p = item.project else { await MainActor.run { workingFileID = nil }; return }
                    _ = try DevicePatchService.apply(project: p)
                    await MainActor.run { store.reload(); workingFileID = nil; activationInfo = ActivationInfo(patchName: nameSnap, note: noteSnap, success: true, errorMessage: nil) }
                }
            } catch {
                await MainActor.run { store.reload(); workingFileID = nil; SoundFX.error(); activationInfo = ActivationInfo(patchName: nameSnap, note: noteSnap, success: false, errorMessage: error.localizedDescription) }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - UNLOCK VIEW & MODIFIERS (Giữ nguyên)
// ═══════════════════════════════════════════════════════════════
struct PatchUnlockView: View {
    @Environment(\.appLanguage) private var language; @Environment(\.dismiss) private var dismiss; @ObservedObject var store: PatchProjectStore
    let request: PatchPasswordRequest; @State private var password = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(language.text("patch.password"), text: $password).textContentType(.password).submitLabel(.done).onSubmit(unlock).onChange(of: password) { _ in store.clearUnlockError() }
                    if let errorKey = store.unlockErrorKey { Text(errorText(errorKey)).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle(language.text("patch.unlock")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(language.text("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(language.text("patch.unlock"), action: unlock).disabled(password.isEmpty || store.isBusy) }
            }
        }
    }
    private func errorText(_ key: String) -> String { if let a = store.unlockErrorArgument { return language.text(key, a) }; return language.text(key) }
    private func unlock() { guard !password.isEmpty else { return }; store.unlock(password: password) }
}

private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore
    func body(content: Content) -> some View {
        content.sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { request in PatchUnlockView(store: store, request: request) }
    }
}

extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View { modifier(PatchStorePresentationModifier(store: store)) }
}
