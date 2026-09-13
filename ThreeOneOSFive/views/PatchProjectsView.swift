import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

// ═══════════════════════════════════════════════════════════════
// MARK: - SOUND (GIỮ NGUYÊN)
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
// MARK: - BACKGROUND (TỐI ƯU MƯỢT MÀ, CHỐNG LAG)
// ═══════════════════════════════════════════════════════════════
struct NeonBackgroundView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black // Tông chủ đạo Đen
            AuroraView().drawingGroup() // Vẽ gộp bằng Metal để tăng FPS
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
                blob(cx: 0.3 + 0.1 * sin(phase), cy: 0.2 + 0.1 * cos(phase * 0.7), opacity: 0.08, r: geo.size.width * 0.8)
                blob(cx: 0.7 + 0.1 * cos(phase * 0.8), cy: 0.8 + 0.1 * sin(phase * 0.6), opacity: 0.06, r: geo.size.width * 0.9)
            }
            .blur(radius: 40) // Giảm blur để đỡ lag máy yếu
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
    private func blob(cx: Double, cy: Double, opacity: Double, r: CGFloat) -> some View {
        RadialGradient(
            colors: [Color.white.opacity(opacity), .clear],
            center: UnitPoint(x: cx, y: cy), startRadius: 0, endRadius: r
        )
    }
}

struct VignetteView: View {
    var body: some View {
        RadialGradient(colors: [.clear, Color.black.opacity(0.85)], center: .center, startRadius: 100, endRadius: 600)
            .allowsHitTesting(false)
    }
}

struct CosmicFieldView: View {
    var paused: Bool = false
    private struct Particle { let x, y, s, speed, opacity, phase: CGFloat }
    @State private var particles: [Particle] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: paused)) { timeline in
            Canvas { ctx, size in
                let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
                for p in particles {
                    let totalY = size.height + 100
                    let traveled = (t * p.speed).truncatingRemainder(dividingBy: totalY)
                    let y = size.height + 50 - traveled
                    let x = p.x * size.width + sin(t + p.phase) * 10
                    let rect = CGRect(x: x, y: y, width: p.s, height: p.s)
                    ctx.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(Double(p.opacity))))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: initField)
    }
    private func initField() {
        if particles.isEmpty {
            particles = (0..<45).map { _ in
                Particle(x: .random(in: 0...1), y: .random(in: 0...1), s: .random(in: 1...2), speed: .random(in: 15...35), opacity: .random(in: 0.1...0.6), phase: .random(in: 0...6))
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MODELS & META STORE (GIỮ NGUYÊN HOÀN TOÀN)
// ═══════════════════════════════════════════════════════════════
struct GameSelection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let prefix: String
}

struct PatchMeta: Codable {
    var remoteKey, remoteName, gameType, folder, tag, displayName, note: String
    var tagOverride, nameOverride, noteOverride, orphaned: Bool

    init(remoteKey: String, remoteName: String, gameType: String, folder: String, tag: String, displayName: String, note: String, tagOverride: Bool = false, nameOverride: Bool = false, noteOverride: Bool = false, orphaned: Bool = false) {
        self.remoteKey = remoteKey; self.remoteName = remoteName; self.gameType = gameType; self.folder = folder; self.tag = tag; self.displayName = displayName; self.note = note; self.tagOverride = tagOverride; self.nameOverride = nameOverride; self.noteOverride = noteOverride; self.orphaned = orphaned
    }
}

struct RemoteFileLite {
    let filename, gameType, folder, tag, displayName, note, url: String
    var compositeKey: String { "\(gameType)/\(folder)/\(filename)" }
}

struct ActivationInfo: Identifiable {
    let id = UUID()
    let patchName, note: String
    let success: Bool
    let errorMessage: String?
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
    static func set(_ meta: PatchMeta, forLocal local: String) { var d = all(); d[local] = meta; save(d) }
    static func get(forLocal local: String) -> PatchMeta? { return all()[local] }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SUB VIEWS (THIẾT KẾ MỚI SIÊU ĐẸP)
// ═══════════════════════════════════════════════════════════════
private struct NeonCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(Color.black.opacity(0.6))
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
            )
            .shadow(color: .white.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

private struct FFLogoView: View {
    var body: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/free.jpg")) { phase in
            switch phase {
            case .empty: ProgressView().tint(.white)
            case .success(let img): img.resizable().scaledToFill()
            case .failure: Image(systemName: "flame.fill").foregroundStyle(.white.opacity(0.8))
            @unknown default: EmptyView()
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white, lineWidth: 1))
    }
}

private struct AvatarView: View {
    var body: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
            switch phase {
            case .empty: ProgressView().tint(.white)
            case .success(let img): img.resizable().scaledToFill()
            case .failure: Image(systemName: "person.crop.circle.fill").foregroundStyle(.white.opacity(0.4))
            @unknown default: EmptyView()
            }
        }
        .frame(width: 70, height: 70)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
        .shadow(color: .white.opacity(0.3), radius: 8)
    }
}

private struct MenuCapsule: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("MỞ MENU").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1)
            Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.white)
        .clipShape(Capsule())
    }
}

private struct TagBadge: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    var body: some View {
        Text(tag)
            .font(.system(size: 9, weight: .black, design: .monospaced)) // Font monospaced ngầu hơn
            .tracking(1)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(isVIP ? Color.white : Color.clear)
            .foregroundStyle(isVIP ? .black : .white)
            .overlay(Capsule().stroke(Color.white, lineWidth: 1))
            .clipShape(Capsule())
    }
}

private struct PatchRow: View {
    let isApplied: Bool, isWorking: Bool, displayName: String, tag: String, note: String
    let onToggle: (Bool) -> Void, onTapTag: () -> Void, onRename: () -> Void, onEditNote: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle().stroke(Color.white.opacity(isApplied ? 1 : 0.3), lineWidth: 1)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(isApplied ? Color.white.opacity(0.15) : .clear))
                Image(systemName: tag == "VIP" ? "crown.fill" : "bolt.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(isApplied ? 1 : 0.6))
            }
            
            // Text Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Button(action: onTapTag) { TagBadge(tag: tag) }.buttonStyle(.plain)
                }
                if !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            Spacer()
            
            // Toggle
            Toggle("", isOn: Binding(get: { isApplied }, set: onToggle))
                .labelsHidden().tint(.white).disabled(isWorking)
        }
        .padding(14)
        .background(Color.black.opacity(isApplied ? 0.4 : 0.2))
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(isApplied ? 0.8 : 0.2), lineWidth: 1))
        .contextMenu {
            Button(action: onRename) { Label("Đổi tên", systemImage: "pencil") }
            Button(action: onTapTag) { Label("Đổi VIP/FREE", systemImage: "crown") }
            Button(action: onEditNote) { Label("Sửa ghi chú", systemImage: "note.text") }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ACTIVATION SHEET (BỐ CỤC ĐEN TRẮNG MỚI)
// ═══════════════════════════════════════════════════════════════
struct ActivationNoteSheet: View {
    let info: ActivationInfo
    let onDismiss: () -> Void
    @State private var copied = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VignetteView()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                Image(systemName: info.success ? "checkmark.seal.fill" : "xmark.octagon.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .nonRepeating)
                
                VStack(spacing: 8) {
                    Text("HEADLOCK ZENIS")
                        .font(.system(size: 12, weight: .black, design: .monospaced)).tracking(3)
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text(info.success ? "ĐÃ KÍCH HOẠT" : "KHÔNG KÍCH HOẠT ĐƯỢC")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text(info.patchName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                if let errMsg = info.errorMessage, !info.success {
                    errorBox(msg: errMsg)
                }
                
                if !info.note.trimmingCharacters(in: .whitespaces).isEmpty {
                    noteBox(note: info.note)
                }
                
                Spacer()
                
                Button(action: { SoundFX.tap(); onDismiss() }) {
                    Text("ĐÃ HIỂU")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).tracking(2)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(Capsule())
                }.padding(.horizontal, 30)
                
            }
            .padding(.bottom, 30)
        }
    }
    
    private func errorBox(msg: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LÝ DO").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            Text(msg).font(.system(size: 13)).foregroundStyle(.white)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.4), lineWidth: 1))
        .padding(.horizontal, 30)
    }
    
    private func noteBox(note: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GHI CHÚ").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            Text(note).font(.system(size: 13, design: .rounded)).foregroundStyle(.white)
            
            Button {
                SoundFX.tap(); UIPasteboard.general.string = note
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { copied = false } }
            } label: {
                HStack {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 12))
                    Text(copied ? "ĐÃ COPY" : "COPY GHI CHÚ").font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(copied ? .black : .white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(copied ? Color.white : .clear)
                .overlay(Capsule().stroke(Color.white, lineWidth: 1))
                .clipShape(Capsule())
            }.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.4), lineWidth: 1))
        .padding(.horizontal, 30)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MAIN VIEW (THAY ĐỔI BỐ CỤC)
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

    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    init(onOpenSettings: @escaping () -> Void = {}, onOpenLogs: @escaping () -> Void = {}) {
        self.onOpenSettings = onOpenSettings; self.onOpenLogs = onOpenLogs
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) {
                    header
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            gameCard(title: "Free Fire Max", prefix: "ffmax")
                            gameCard(title: "Free Fire Thường", prefix: "ffnormal")
                            
                            Text("By Zenith Solitude")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(2).foregroundStyle(.white.opacity(0.3))
                                .padding(.top, 20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 50)
                    }
                    .refreshable { await syncNow(force: true) }
                }
            }
            .navigationBarHidden(true)
            .onAppear { Task { await syncNow(force: true) } }
            .onChange(of: scenePhase) { p in if p == .active { Task { await syncNow(force: true) } } }
            .sheet(item: $selectedGame) { game in
                PatchGameDetailView(game: game, store: store, actionAlert: $actionAlert, language: language)
            }
        }
    }

    private var header: some View {
        HStack {
            AvatarView()
            VStack(alignment: .leading, spacing: 4) {
                Text("ZENITH SOLITUDE")
                    .font(.system(size: 20, weight: .black, design: .rounded)).tracking(1)
                    .foregroundStyle(.white)
                HStack {
                    Circle().fill(isSyncing ? Color.white : Color.green).frame(width: 6, height: 6)
                    Text(isSyncing ? "ĐANG CẬP NHẬT..." : "ĐÃ KẾT NỐI")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 30)
    }

    @ViewBuilder
    private func gameCard(title: String, prefix: String) -> some View {
        Button {
            SoundFX.menu(); selectedGame = GameSelection(title: title, prefix: prefix)
        } label: {
            NeonCard {
                HStack(spacing: 16) {
                    FFLogoView()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text("Headlock Zenis").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    MenuCapsule()
                }
                .padding(16)
            }
        }.buttonStyle(.plain)
    }

    private func syncNow(force: Bool) async {
        if !force && Date().timeIntervalSince(lastSyncDate) < 2 { return }
        await MainActor.run { isSyncing = true }
        await SyncEngine.shared.run(store: store)
        await MainActor.run { isSyncing = false; lastSyncDate = Date() }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SYNC ENGINE (TỐI ƯU NETWORK & TỐC ĐỘ TẢI)
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

        for remote in remotes {
            if existingKeys.contains(remote.compositeKey) { continue }
            guard let url = URL(string: remote.url) else { continue }
            await importAndTag(remote: remote, url: url, store: store)
        }
        await MainActor.run { store.reload() }
    }

    private func fetchRemotes() async -> [RemoteFileLite]? {
        let ts = Int(Date().timeIntervalSince1970)
        let urlString = "https://solitudepremium.click/ipa/proxy/list.php?t=\(ts)"
        guard let url = URL(string: urlString) else { return nil }
        
        // Tối ưu Session để tải nhanh hơn
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: config)

        for attempt in 0..<2 {
            do {
                var req = URLRequest(url: url)
                req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                let (data, _) = try await session.data(for: req)
                
                struct Wire: Decodable { let filename, gameType: String; let folder, displayName, tag, note: String?; let url: String }
                let wire = try JSONDecoder().decode([Wire].self, from: data)
                
                return wire.map { w in
                    RemoteFileLite(filename: w.filename, gameType: w.gameType, folder: w.folder ?? "Chung", tag: w.tag ?? "FREE", displayName: w.displayName ?? "", note: w.note ?? "", url: w.url)
                }
            } catch {
                if attempt == 0 { try? await Task.sleep(nanoseconds: 300_000_000) }
            }
        }
        return nil
    }

    private func importAndTag(remote: RemoteFileLite, url: URL, store: PatchProjectStore) async {
        let before = await MainActor.run { Set(store.items.map { $0.packageURL.lastPathComponent }) }
        await MainActor.run { store.importPackage(from: .remote(url)) }
        
        // Giảm thời gian sleep để UI cập nhật cực nhanh
        for _ in 0..<60 {
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            await MainActor.run { store.reload() }
            let after = await MainActor.run { Set(store.items.map { $0.packageURL.lastPathComponent }) }
            
            if let newFile = after.subtracting(before).first {
                metaLock.lock()
                PatchMetaStore.set(PatchMeta(remoteKey: remote.compositeKey, remoteName: remote.filename, gameType: remote.gameType, folder: remote.folder, tag: remote.tag, displayName: remote.displayName, note: remote.note), forLocal: newFile)
                metaLock.unlock()
                return
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DETAIL VIEW (SỬA LỖI THƯ MỤC ĐẦU TIÊN TỰ ĐỘNG CẬP NHẬT)
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
    @State private var workingFileID: String?
    @State private var renameItem: PatchLibraryItem?
    @State private var renameText = ""
    @State private var tagPickerItem: PatchLibraryItem?
    @State private var noteItem: PatchLibraryItem?
    @State private var noteText = ""
    @State private var refreshTick = 0

    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VignetteView()
                
                VStack(spacing: 0) {
                    if !folders.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(folders, id: \.self) { f in
                                    Button {
                                        SoundFX.tap(); withAnimation(.spring) { selectedFolder = f }
                                    } label: {
                                        Text(f.uppercased())
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 16).padding(.vertical, 8)
                                            .background(selectedFolder == f ? Color.white : .clear)
                                            .foregroundStyle(selectedFolder == f ? .black : .white)
                                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                            .clipShape(Capsule())
                                    }.buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20).padding(.vertical, 14)
                        }
                    }
                    
                    ScrollView(showsIndicators: false) {
                        if displayedItems.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(.white.opacity(0.2))
                                Text("Đang đồng bộ dữ liệu...").font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                            }.padding(.top, 80)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(displayedItems) { item in patchRow(item: item) }
                            }
                            .padding(.horizontal, 20).padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle(game.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { SoundFX.tap(); dismiss() }) { Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white) }
                }
            }
            .toolbarBackground(Color.black, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { Task { await SyncEngine.shared.run(store: store); await MainActor.run { store.reload(); syncFolders() } } }
            .onChange(of: scenePhase) { p in if p == .active { Task { await SyncEngine.shared.run(store: store) } } }
            .onReceive(refreshTimer) { _ in refreshTick &+= 1; store.reload(); syncFolders() }
            .alert("Đổi tên", isPresented: Binding(get: { renameItem != nil }, set: { if !$0 { renameItem = nil } })) { TextField("Tên", text: $renameText); Button("Huỷ", role: .cancel) {}; Button("Lưu") { commitRename() } }
            .alert("Ghi chú", isPresented: Binding(get: { noteItem != nil }, set: { if !$0 { noteItem = nil } })) { TextField("Note", text: $noteText); Button("Huỷ", role: .cancel) {}; Button("Lưu") { commitNote() } }
            .confirmationDialog("Tag", isPresented: Binding(get: { tagPickerItem != nil }, set: { if !$0 { tagPickerItem = nil } })) { Button("VIP") { commitTag("VIP") }; Button("FREE") { commitTag("FREE") }; Button("Huỷ", role: .cancel) {} }
            .fullScreenCover(item: $activationInfo) { info in ActivationNoteSheet(info: info) { activationInfo = nil } }
        }
    }

    // LUÔN CHỌN THƯ MỤC ĐẦU TIÊN (ĐÃ BỎ SẮP XẾP A-Z, GIỮ THEO NGUỒN JSON)
    private func syncFolders() {
        let curr = folders
        if curr.isEmpty { selectedFolder = nil; return }
        if let sel = selectedFolder, curr.contains(sel) { return }
        selectedFolder = curr.first
    }

    private var gameItems: [PatchLibraryItem] {
        _ = refreshTick
        return store.items.filter { item in
            let name = item.packageURL.lastPathComponent
            if let m = PatchMetaStore.get(forLocal: name), !m.gameType.isEmpty {
                return !m.orphaned && m.gameType == game.prefix
            }
            let isMax = name.hasPrefix("ffmax_"), isNorm = name.hasPrefix("ffnormal_")
            return game.prefix == "ffmax" ? isMax : (isNorm || (!isMax && !isNorm))
        }
    }

    private var folders: [String] {
        let names = gameItems.map { folderName(for: $0) }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var unique: [String] = []
        for n in names { if !unique.contains(n) { unique.append(n) } }
        return unique // Không dùng .sorted() nữa để giữ nguyên thứ tự ưu tiên từ JSON
    }

    private var displayedItems: [PatchLibraryItem] {
        guard let sel = selectedFolder else { return [] }
        return gameItems.filter { folderName(for: $0) == sel }
    }

    @ViewBuilder
    private func patchRow(item: PatchLibraryItem) -> some View {
        let name = displayName(for: item)
        PatchRow(
            isApplied: DevicePatchService.latestReceipt(projectID: item.id) != nil,
            isWorking: workingFileID == item.id.uuidString,
            displayName: name, tag: currentTag(for: item), note: currentNote(for: item),
            onToggle: { nv in if nv { SoundFX.tingTing() } else { SoundFX.tap() }; togglePatch(item: item, activate: nv) },
            onTapTag: { SoundFX.tap(); tagPickerItem = item },
            onRename: { SoundFX.tap(); renameItem = item; renameText = name },
            onEditNote: { SoundFX.tap(); noteItem = item; noteText = currentNote(for: item) }
        )
    }

    private func localKey(for item: PatchLibraryItem) -> String { item.packageURL.lastPathComponent }
    private func meta(for item: PatchLibraryItem) -> PatchMeta? { PatchMetaStore.get(forLocal: localKey(for: item)) }
    private func displayName(for item: PatchLibraryItem) -> String { meta(for: item)?.displayName.isEmpty == false ? meta(for: item)!.displayName : item.project?.name ?? item.packageURL.lastPathComponent }
    private func currentTag(for item: PatchLibraryItem) -> String { meta(for: item)?.tag.isEmpty == false ? meta(for: item)!.tag : (item.packageURL.lastPathComponent.hasSuffix("_VIP") ? "VIP" : "FREE") }
    private func currentNote(for item: PatchLibraryItem) -> String { meta(for: item)?.note ?? "" }
    private func folderName(for item: PatchLibraryItem) -> String { meta(for: item)?.folder.isEmpty == false ? meta(for: item)!.folder : "Chung" }

    private func commitRename() { guard let item = renameItem else { return }; let t = renameText.trimmingCharacters(in: .whitespaces); if !t.isEmpty, var m = meta(for: item) { m.displayName = t; m.nameOverride = true; PatchMetaStore.set(m, forLocal: localKey(for: item)) }; store.reload(); renameItem = nil }
    private func commitTag(_ tag: String) { guard let item = tagPickerItem, var m = meta(for: item) else { return }; m.tag = tag; m.tagOverride = true; PatchMetaStore.set(m, forLocal: localKey(for: item)); store.reload(); tagPickerItem = nil }
    private func commitNote() { guard let item = noteItem, var m = meta(for: item) else { return }; m.note = noteText.trimmingCharacters(in: .whitespaces); m.noteOverride = true; PatchMetaStore.set(m, forLocal: localKey(for: item)); store.reload(); noteItem = nil }

    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        workingFileID = item.id.uuidString; let snapName = displayName(for: item), snapNote = currentNote(for: item)
        Task.detached(priority: .userInitiated) {
            do {
                if !activate {
                    if let r = DevicePatchService.latestReceipt(projectID: item.id) { try DevicePatchService.restore(receipt: r) }
                    await MainActor.run { store.reload(); workingFileID = nil }
                } else {
                    guard let p = item.project else { await MainActor.run { workingFileID = nil }; return }
                    _ = try DevicePatchService.apply(project: p)
                    await MainActor.run { store.reload(); workingFileID = nil; activationInfo = ActivationInfo(patchName: snapName, note: snapNote, success: true, errorMessage: nil) }
                }
            } catch {
                await MainActor.run { store.reload(); workingFileID = nil; SoundFX.error(); activationInfo = ActivationInfo(patchName: snapName, note: snapNote, success: false, errorMessage: error.localizedDescription) }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - UNLOCK VIEW & PRESENTATION (GIỮ NGUYÊN)
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
                        .textContentType(.password).submitLabel(.done).onSubmit(unlock)
                        .onChange(of: password) { _ in store.clearUnlockError() }
                    if let err = store.unlockErrorKey { Text(errorText(err)).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle(language.text("patch.unlock")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(language.text("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(language.text("patch.unlock"), action: unlock).disabled(password.isEmpty || store.isBusy) }
            }
        }
    }
    private func errorText(_ key: String) -> String { store.unlockErrorArgument != nil ? language.text(key, store.unlockErrorArgument!) : language.text(key) }
    private func unlock() { if !password.isEmpty { store.unlock(password: password) } }
}

private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore
    func body(content: Content) -> some View {
        content.sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { req in PatchUnlockView(store: store, request: req) }
    }
}
extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View { modifier(PatchStorePresentationModifier(store: store)) }
}
