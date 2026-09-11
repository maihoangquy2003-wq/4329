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
// MARK: - BACKGROUND (STARFIELD + PARTICLES)
// ═══════════════════════════════════════════════════════════════
struct NeonBackgroundView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            StarfieldView()
            FloatingParticlesView(particleCount: 55)
        }
        .ignoresSafeArea()
    }
}

struct StarfieldView: View {
    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let phase: Double
    }
    @State private var stars: [Star] = []

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for s in stars {
                        let alpha = 0.35 + 0.35 * sin(t * 0.9 + s.phase)
                        let rect = CGRect(
                            x: s.x * size.width,
                            y: s.y * size.height,
                            width: s.size,
                            height: s.size
                        )
                        ctx.fill(Path(ellipseIn: rect),
                                 with: .color(Color.white.opacity(alpha)))
                    }
                }
            }
            .onAppear {
                if stars.isEmpty {
                    stars = (0..<90).map { _ in
                        Star(
                            x: CGFloat.random(in: 0...1),
                            y: CGFloat.random(in: 0...1),
                            size: CGFloat.random(in: 0.8...2.0),
                            phase: Double.random(in: 0...(2 * .pi))
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct FloatingParticlesView: View {
    var particleCount: Int = 55
    var color: Color = .white

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
                                 with: .color(color.opacity(p.opacity)))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: spawn)
    }

    private func spawn() {
        guard particles.isEmpty else { return }
        particles = (0..<particleCount).map { _ in
            Particle(
                baseX:   CGFloat.random(in: 0...1),
                size:    CGFloat.random(in: 1.2...3.4),
                speed:   CGFloat.random(in: 20...55),
                opacity: Double.random(in: 0.25...0.9),
                phase:   Double.random(in: 0...(2 * .pi))
            )
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
// MARK: - METADATA (keyed by UUID)
// ═══════════════════════════════════════════════════════════════
struct PatchMeta: Codable {
    var folder: String
    var tag: String
    var displayName: String
}

enum PatchMetaStore {
    private static let key = "patch_meta_map_v3"

    static func all() -> [String: PatchMeta] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: PatchMeta].self, from: data) else {
            return [:]
        }
        return dict
    }

    static func save(_ dict: [String: PatchMeta]) {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func set(_ meta: PatchMeta, forUUID uuid: String) {
        var d = all()
        d[uuid.uppercased()] = meta
        save(d)
    }

    static func get(uuid: String) -> PatchMeta? {
        return all()[uuid.uppercased()]
    }

    static func updateName(_ name: String, uuid: String) {
        guard var m = get(uuid: uuid) else { return }
        m.displayName = name
        set(m, forUUID: uuid)
    }

    static func updateTag(_ tag: String, uuid: String) {
        guard var m = get(uuid: uuid) else { return }
        m.tag = tag
        set(m, forUUID: uuid)
    }
}

/// Trích UUID từ tên file (VD: "ZENITH_aim_51067270_F5D3-....3105" → "F5D3-...")
func extractUUID(from filename: String) -> String? {
    let pattern = "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
    guard let match = regex.firstMatch(in: filename, range: range),
          let r = Range(match.range, in: filename) else { return nil }
    return String(filename[r]).uppercased()
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SUB VIEWS
// ═══════════════════════════════════════════════════════════════
private struct NeonCard<Content: View>: View {
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.black.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white,
                                accent.opacity(0.55),
                                Color.white.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.4
                    )
            )
            .shadow(color: accent.opacity(0.35), radius: 22)
            .shadow(color: Color.white.opacity(0.15), radius: 8)
    }
}

private struct MenuCapsuleButton: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("MỞ MENU")
                .font(.system(size: 12, weight: .heavy))
                .tracking(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .heavy))
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().stroke(Color.white, lineWidth: 1))
        .shadow(color: Color.white.opacity(0.55), radius: 12)
    }
}

private struct FFLogoView: View {
    var body: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/free.jpg")) { phase in
            switch phase {
            case .empty:
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06))
                    ProgressView().tint(.white)
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            case .failure:
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.orange)
                }
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 62, height: 62)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.white.opacity(0.35), radius: 10)
    }
}

private struct AvatarView: View {
    var body: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
            switch phase {
            case .empty:
                ProgressView().frame(width: 92, height: 92).tint(.white)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
                    .shadow(color: Color.white.opacity(0.45), radius: 16)
            case .failure:
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 92))
                    .foregroundStyle(Color.white.opacity(0.35))
            @unknown default:
                EmptyView()
            }
        }
    }
}

private struct GameCardContent: View {
    let title: String
    let accent: Color
    let isSyncing: Bool

    var body: some View {
        HStack(spacing: 14) {
            FFLogoView()

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)

                Text("HEADLOCK ZENIS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            Spacer()

            if isSyncing {
                ProgressView().tint(.white)
            } else {
                MenuCapsuleButton()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

private struct TagBadge: View {
    let tag: String

    private var isVIP: Bool { tag == "VIP" }
    private var bg: Color { isVIP ? Color.yellow.opacity(0.22) : Color.white.opacity(0.10) }
    private var fg: Color { isVIP ? Color.yellow : Color.white.opacity(0.85) }
    private var bd: Color { isVIP ? Color.yellow.opacity(0.6) : Color.white.opacity(0.35) }

    var body: some View {
        Text(tag)
            .font(.system(size: 9, weight: .heavy))
            .tracking(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
            .overlay(Capsule().stroke(bd, lineWidth: 0.8))
    }
}

private struct PatchIconView: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    private var iconName: String { isVIP ? "crown.fill" : "shield.lefthalf.filled" }
    private var iconColor: Color { isVIP ? Color.yellow : Color.white.opacity(0.9) }
    private var borderColor: Color { isVIP ? Color.yellow.opacity(0.6) : Color.white.opacity(0.4) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.white.opacity(0.05))
                .frame(width: 48, height: 48)
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(iconColor)
        }
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(borderColor, lineWidth: 1))
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
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.2)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(bg))
                .foregroundStyle(fg)
                .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1))
                .shadow(color: isActive ? Color.white.opacity(0.5) : Color.clear, radius: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct PatchRowView: View {
    let isApplied: Bool
    let isWorking: Bool
    let displayName: String
    let tag: String
    let onToggle: (Bool) -> Void
    let onTapTag: () -> Void
    let onRename: () -> Void

    private var rowBg: Color {
        isApplied ? Color.white.opacity(0.06) : Color.white.opacity(0.02)
    }
    private var rowBorder: Color {
        isApplied ? Color.green.opacity(0.7) : Color.white.opacity(0.3)
    }

    var body: some View {
        HStack(spacing: 14) {
            PatchIconView(tag: tag)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                Button(action: onTapTag) {
                    TagBadge(tag: tag)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Toggle("", isOn: Binding(get: { isApplied }, set: { onToggle($0) }))
                .labelsHidden()
                .tint(Color.green)
                .disabled(isWorking)
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 16).fill(rowBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(rowBorder, lineWidth: 1))
        .shadow(color: isApplied ? Color.green.opacity(0.35) : Color.clear, radius: 12)
        .contextMenu {
            Button(action: onRename) {
                Label("Đổi tên hiển thị", systemImage: "pencil")
            }
            Button(action: onTapTag) {
                Label("Đổi VIP / FREE", systemImage: "crown")
            }
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
            .onReceive(autoTimer) { _ in
                syncRemotePatches()
                store.reload()
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
        VStack(spacing: 10) {
            AvatarView()
            Text("ZENITH SOLITUDE")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .tracking(3)
                .shadow(color: Color.white.opacity(0.5), radius: 12)
            Text("PREMIUM PATCH STORE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
                .tracking(4)
        }
        .padding(.top, 20)
        .padding(.bottom, 22)
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                cardMax
                cardNormal
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    private var cardMax: some View {
        gameCard(
            title: "Free Fire Max",
            prefix: "ffmax_",
            accent: Color(red: 1.0, green: 0.30, blue: 0.15)
        )
    }
    private var cardNormal: some View {
        gameCard(
            title: "Free Fire Thường",
            prefix: "ffnormal_",
            accent: Color(red: 0.30, green: 0.65, blue: 1.0)
        )
    }

    @ViewBuilder
    private func gameCard(title: String, prefix: String, accent: Color) -> some View {
        Button {
            SoundFX.menu()
            selectedGame = GameSelection(title: title, prefix: prefix)
        } label: {
            NeonCard(accent: accent) {
                GameCardContent(title: title, accent: accent, isSyncing: isAutoSyncing)
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
            let (data, _) = try await URLSession.shared.data(from: listUrl)
            let remoteFiles = try JSONDecoder().decode([RemoteFile].self, from: data)
            let local = Set(store.items.map { $0.packageURL.lastPathComponent })

            for file in remoteFiles {
                // Ghi metadata theo UUID (nguồn sự thật cho folder/tag/name)
                if let uuid = extractUUID(from: file.filename) {
                    let existing = PatchMetaStore.get(uuid: uuid)
                    let meta = PatchMeta(
                        folder:      file.folder ?? existing?.folder ?? "Khác",
                        tag:         existing?.tag ?? file.tag ?? "FREE",
                        displayName: existing?.displayName ?? file.displayName ?? file.filename
                    )
                    PatchMetaStore.set(meta, forUUID: uuid)
                }

                if local.contains(file.filename) { continue }
                guard let fileURL = URL(string: file.url) else { continue }
                await MainActor.run {
                    store.importPackage(from: .remote(fileURL))
                }
                try await Task.sleep(nanoseconds: 3_000_000_000)
            }
        } catch {
            print("Lỗi đồng bộ: \(error.localizedDescription)")
        }
        await MainActor.run { isAutoSyncing = false }
    }

    private struct RemoteFile: Decodable {
        let filename: String
        let gameType: String
        let folder: String?
        let displayName: String?
        let tag: String?
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

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()

                VStack(spacing: 0) {
                    if !folders.isEmpty {
                        folderTabs
                    }
                    listContent
                }
            }
            .navigationTitle(game.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { closeButton }
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
            .confirmationDialog("Chọn loại tag", isPresented: tagBinding, titleVisibility: .visible) {
                Button("VIP 👑") { commitTag("VIP") }
                Button("FREE 🛡") { commitTag("FREE") }
                Button("Huỷ", role: .cancel) { tagPickerItem = nil }
            }
        }
    }

    // MARK: Computed
    private var gameItems: [PatchLibraryItem] {
        store.items.filter { item in
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

    private var renameBinding: Binding<Bool> {
        Binding(get: { renameItem != nil }, set: { if !$0 { renameItem = nil } })
    }
    private var tagBinding: Binding<Bool> {
        Binding(get: { tagPickerItem != nil }, set: { if !$0 { tagPickerItem = nil } })
    }

    // MARK: Subviews
    private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                SoundFX.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
    }

    private var folderTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(folders, id: \.self) { folder in
                    FolderTabButton(
                        title: folder,
                        isActive: selectedFolder == folder,
                        action: { selectFolder(folder) }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 14)
    }

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(displayedItems) { item in
                    patchRow(item: item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func patchRow(item: PatchLibraryItem) -> some View {
        let receipt = DevicePatchService.latestReceipt(projectID: item.id)
        let isApplied = (receipt != nil)
        let fileID = item.id.uuidString
        let tag = currentTag(for: item)
        let name = displayName(for: item)

        PatchRowView(
            isApplied: isApplied,
            isWorking: (workingFileID == fileID),
            displayName: name,
            tag: tag,
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
            }
        )
    }

    // MARK: Actions
    private func selectFolder(_ folder: String) {
        SoundFX.tap()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selectedFolder = (selectedFolder == folder) ? nil : folder
        }
    }

    // MARK: Helpers (UUID-based lookup = FIX chính)
    private func displayName(for item: PatchLibraryItem) -> String {
        let fname = item.packageURL.lastPathComponent
        if let uuid = extractUUID(from: fname),
           let meta = PatchMetaStore.get(uuid: uuid),
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
        let fname = item.packageURL.lastPathComponent
        if let uuid = extractUUID(from: fname),
           let meta = PatchMetaStore.get(uuid: uuid),
           !meta.tag.isEmpty {
            return meta.tag
        }
        let base = item.packageURL.deletingPathExtension().lastPathComponent
        return base.hasSuffix("_VIP") ? "VIP" : "FREE"
    }

    private func folderName(for item: PatchLibraryItem) -> String {
        let fname = item.packageURL.lastPathComponent
        // 1. Metadata by UUID (nguồn chính)
        if let uuid = extractUUID(from: fname),
           let meta = PatchMetaStore.get(uuid: uuid),
           !meta.folder.isEmpty {
            return meta.folder
        }
        // 2. Fallback: parse path
        let comps = item.packageURL.pathComponents.filter { $0 != "/" }
        if let idx = comps.firstIndex(where: { $0 == "ffmax" || $0 == "ffnormal" }),
           idx + 2 < comps.count {
            return comps[idx + 1]
        }
        // 3. Fallback: parent folder nếu không phải system
        let parent = item.packageURL.deletingLastPathComponent().lastPathComponent
        let ignore: Set<String> = ["Documents", "tmp", "proxy", "PatchProjects", "PatchProjectStore", ""]
        if !ignore.contains(parent) { return parent }
        return "Khác"
    }

    private func commitRename() {
        guard let item = renameItem else { return }
        let fname = item.packageURL.lastPathComponent
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let uuid = extractUUID(from: fname) {
            PatchMetaStore.updateName(trimmed, uuid: uuid)
            store.reload()
        }
        renameItem = nil
    }

    private func commitTag(_ tag: String) {
        guard let item = tagPickerItem else { return }
        let fname = item.packageURL.lastPathComponent
        if let uuid = extractUUID(from: fname) {
            PatchMetaStore.updateTag(tag, uuid: uuid)
            store.reload()
        }
        tagPickerItem = nil
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
                    actionAlert = PatchStoreAlert(
                        titleKey: "Thành công",
                        messageKey: activate
                            ? "Đã kích hoạt patch thành công!"
                            : "Đã tắt / khôi phục patch!"
                    )
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
