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
// MARK: - PARTICLE
// ═══════════════════════════════════════════════════════════════
struct FloatingParticlesView: View {
    var particleCount: Int = 60
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
                size:    CGFloat.random(in: 1.2...3.6),
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
// MARK: - PATCH METADATA (UserDefaults)
// ═══════════════════════════════════════════════════════════════
enum PatchMetadata {
    // Folder
    static func folder(for filename: String) -> String? {
        UserDefaults.standard.string(forKey: "patch_folder_\(filename)")
    }
    static func setFolder(_ v: String, for filename: String) {
        UserDefaults.standard.set(v, forKey: "patch_folder_\(filename)")
    }
    // Display name
    static func displayName(for filename: String) -> String? {
        UserDefaults.standard.string(forKey: "patch_dname_\(filename)")
    }
    static func setDisplayName(_ v: String, for filename: String) {
        UserDefaults.standard.set(v, forKey: "patch_dname_\(filename)")
    }
    // Tag
    static func tag(for filename: String) -> String? {
        UserDefaults.standard.string(forKey: "patch_tag_\(filename)")
    }
    static func setTag(_ v: String, for filename: String) {
        UserDefaults.standard.set(v, forKey: "patch_tag_\(filename)")
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SUB VIEWS
// ═══════════════════════════════════════════════════════════════

private struct TagBadge: View {
    let tag: String

    private var isVIP: Bool { tag == "VIP" }
    private var bg: Color { isVIP ? Color.yellow.opacity(0.22) : Color.white.opacity(0.10) }
    private var fg: Color { isVIP ? Color.yellow : Color.white.opacity(0.80) }
    private var bd: Color { isVIP ? Color.yellow.opacity(0.50) : Color.white.opacity(0.25) }

    var body: some View {
        Text(tag)
            .font(.system(size: 9, weight: .heavy))
            .tracking(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
            .overlay(Capsule().stroke(bd, lineWidth: 0.7))
    }
}

private struct PatchIconView: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    private var iconName: String { isVIP ? "crown.fill" : "shield.lefthalf.filled" }
    private var iconColor: Color { isVIP ? Color.yellow : Color.white.opacity(0.90) }
    private var borderColor: Color { isVIP ? Color.yellow.opacity(0.50) : Color.white.opacity(0.30) }
    private var gradient: LinearGradient {
        isVIP
            ? LinearGradient(colors: [Color.yellow.opacity(0.25), Color.orange.opacity(0.10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13).fill(gradient).frame(width: 48, height: 48)
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
    private var fg: Color { isActive ? Color.black : Color.white.opacity(0.85) }

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.2)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(bg))
                .foregroundStyle(fg)
                .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct FFLogo: View {
    var body: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/free.jpg")) { phase in
            switch phase {
            case .empty:
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05))
                    ProgressView().tint(.white)
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            case .failure:
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.orange)
                }
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 60, height: 60)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.4), lineWidth: 1))
    }
}

private struct AvatarView: View {
    var body: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
            switch phase {
            case .empty:
                ProgressView().frame(width: 88, height: 88).tint(.white)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 2))
            case .failure:
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(Color.white.opacity(0.35))
            @unknown default:
                EmptyView()
            }
        }
    }
}

private struct MenuButtonBar: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .heavy))
            Text("MỞ MENU")
                .font(.system(size: 13, weight: .heavy))
                .tracking(2.5)
        }
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
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

    private var rowBg: Color { isApplied ? Color.white.opacity(0.05) : Color.white.opacity(0.02) }
    private var rowBorder: Color { isApplied ? Color.green.opacity(0.55) : Color.white.opacity(0.22) }

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
                Color.black.ignoresSafeArea()
                FloatingParticlesView(particleCount: 70).ignoresSafeArea()

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
            Text("PREMIUM PATCH STORE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.45))
                .tracking(4)
        }
        .padding(.top, 20)
        .padding(.bottom, 22)
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                gameCard(
                    title: "Free Fire Max",
                    prefix: "ffmax_",
                    accent: Color(red: 1.0, green: 0.28, blue: 0.15)
                )
                gameCard(
                    title: "Free Fire Thường",
                    prefix: "ffnormal_",
                    accent: Color(red: 0.25, green: 0.65, blue: 1.0)
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func gameCard(title: String, prefix: String, accent: Color) -> some View {
        Button {
            SoundFX.menu()
            selectedGame = GameSelection(title: title, prefix: prefix)
        } label: {
            VStack(spacing: 0) {
                // NÚT MỞ MENU — TRÊN CÙNG
                MenuButtonBar()

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                // HEADER LOGO + TÊN
                HStack(spacing: 14) {
                    FFLogo()

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text("HEADLOCK ZENIS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .tracking(1.5)
                    }

                    Spacer()

                    if isAutoSyncing {
                        ProgressView().tint(.white)
                    }
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1.2)
            )
            .shadow(color: accent.opacity(0.20), radius: 20, y: 8)
        }
        .buttonStyle(.plain)
    }

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
                let fname = file.filename

                // LUÔN cập nhật folder metadata (nguồn sự thật từ web)
                PatchMetadata.setFolder(file.folder ?? "Khác", for: fname)

                // displayName / tag: chỉ set nếu user CHƯA sửa
                if PatchMetadata.displayName(for: fname) == nil,
                   let dn = file.displayName, !dn.isEmpty {
                    PatchMetadata.setDisplayName(dn, for: fname)
                }
                if PatchMetadata.tag(for: fname) == nil,
                   let t = file.tag, !t.isEmpty {
                    PatchMetadata.setTag(t, for: fname)
                }

                if local.contains(fname) { continue }
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
                Color.black.ignoresSafeArea()
                FloatingParticlesView(particleCount: 45).ignoresSafeArea()

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
            if game.prefix == "ffmax_" { return isMax || isPlain == false ? isMax : false }
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

    // MARK: Helpers
    private func displayName(for item: PatchLibraryItem) -> String {
        let fname = item.packageURL.lastPathComponent
        if let override = PatchMetadata.displayName(for: fname), !override.isEmpty {
            return override
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
        if let override = PatchMetadata.tag(for: fname), !override.isEmpty {
            return override
        }
        let base = item.packageURL.deletingPathExtension().lastPathComponent
        return base.hasSuffix("_VIP") ? "VIP" : "FREE"
    }

    private func folderName(for item: PatchLibraryItem) -> String {
        let fname = item.packageURL.lastPathComponent

        // 1. UserDefaults metadata (chính xác nhất)
        if let f = PatchMetadata.folder(for: fname), !f.isEmpty {
            return f
        }

        // 2. Fallback: parse từ path components
        let comps = item.packageURL.pathComponents.filter { $0 != "/" }
        if let idx = comps.firstIndex(where: { $0 == "ffmax" || $0 == "ffnormal" }),
           idx + 2 < comps.count {
            return comps[idx + 1]
        }

        // 3. Bỏ các folder hệ thống
        let parent = item.packageURL.deletingLastPathComponent().lastPathComponent
        let ignore: Set<String> = ["Documents", "tmp", "proxy", "PatchProjects", "PatchProjectStore", ""]
        if !ignore.contains(parent) { return parent }

        return "Khác"
    }

    private func commitRename() {
        guard let item = renameItem else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let fname = item.packageURL.lastPathComponent
            PatchMetadata.setDisplayName(trimmed, for: fname)
            store.reload()
        }
        renameItem = nil
    }

    private func commitTag(_ tag: String) {
        guard let item = tagPickerItem else { return }
        let fname = item.packageURL.lastPathComponent
        PatchMetadata.setTag(tag, for: fname)
        store.reload()
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
