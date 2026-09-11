import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

// ═══════════════════════════════════════════════════════════════
// MARK: - SOUND HELPER
// ═══════════════════════════════════════════════════════════════
enum SoundFX {
    /// "Tock" — tap nhẹ
    static func tap() {
        AudioServicesPlaySystemSound(1104)
    }

    /// "Tíng ting" — kích hoạt thành công (double Tink)
    static func tingTing() {
        AudioServicesPlaySystemSound(1057)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            AudioServicesPlaySystemSound(1057)
        }
    }

    /// "Tock" — menu mở
    static func menu() {
        AudioServicesPlaySystemSound(1105)
    }

    /// Cảnh báo
    static func error() {
        AudioServicesPlaySystemSound(1053)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - PARTICLE BACKGROUND
// ═══════════════════════════════════════════════════════════════
struct FloatingParticlesView: View {
    var particleCount: Int = 60
    var color: Color = .white

    private struct Particle {
        let id = UUID()
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
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(color.opacity(p.opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            if particles.isEmpty {
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
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MODEL
// ═══════════════════════════════════════════════════════════════
struct GameSelection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let prefix: String
    let logoURL: String
}

// ═══════════════════════════════════════════════════════════════
// MARK: - USER OVERRIDES (đổi tên / đổi tag)
// ═══════════════════════════════════════════════════════════════
enum PatchOverrides {
    static func displayName(for id: UUID) -> String? {
        UserDefaults.standard.string(forKey: "patch_display_\(id.uuidString)")
    }
    static func setDisplayName(_ name: String, for id: UUID) {
        UserDefaults.standard.set(name, forKey: "patch_display_\(id.uuidString)")
    }
    static func tag(for id: UUID) -> String? {
        UserDefaults.standard.string(forKey: "patch_tag_\(id.uuidString)")
    }
    static func setTag(_ tag: String, for id: UUID) {
        UserDefaults.standard.set(tag, forKey: "patch_tag_\(id.uuidString)")
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
    @State private var selectedGame: GameSelection? = nil

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
                FloatingParticlesView(particleCount: 70)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

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
            }
            .navigationBarHidden(true)
            .onAppear { syncRemotePatches() }
            .sheet(item: $selectedGame) { game in
                PatchGameDetailView(
                    game: game,
                    store: store,
                    isAutoSyncing: $isAutoSyncing,
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

    // MARK: HEADER
    private var header: some View {
        VStack(spacing: 10) {
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
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.25)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: .white.opacity(0.35), radius: 18)
                case .failure(_):
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 88))
                        .foregroundStyle(.white.opacity(0.35))
                @unknown default:
                    EmptyView()
                }
            }

            Text("ZENITH SOLITUDE")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .tracking(3)

            Text("PREMIUM PATCH STORE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(4)
        }
        .padding(.top, 20)
        .padding(.bottom, 22)
    }

    // MARK: GAME CARD
    @ViewBuilder
    private func gameCard(title: String, prefix: String, accent: Color) -> some View {
        Button {
            SoundFX.menu()
            selectedGame = GameSelection(
                title: title,
                prefix: prefix,
                logoURL: "https://solitudepremium.click/ipa/proxy/free.jpg"
            )
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // LOGO FREE FIRE
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 68, height: 68)

                        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/free.jpg")) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().tint(.white)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 68, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            case .failure(_):
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(accent)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [accent.opacity(0.8), accent.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: accent.opacity(0.4), radius: 12)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Zenith Solitude Store")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .tracking(0.5)
                    }

                    Spacer()

                    if isAutoSyncing {
                        ProgressView().tint(.white)
                    }
                }
                .padding(16)

                // ĐƯỜNG PHÂN CÁCH
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.25), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                // NÚT "MỞ MENU"
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12, weight: .heavy))
                    Text("MỞ MENU")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(2.5)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.65))
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.12),
                                    Color.black.opacity(0.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                accent.opacity(0.35),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: accent.opacity(0.2), radius: 20, y: 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: SYNC
    private func syncRemotePatches() {
        guard !isAutoSyncing else { return }
        isAutoSyncing = true

        Task {
            do {
                guard let listUrl = URL(string: "https://solitudepremium.click/ipa/proxy/list.php") else {
                    await MainActor.run { isAutoSyncing = false }
                    return
                }
                let (data, _) = try await URLSession.shared.data(from: listUrl)

                struct RemoteFile: Decodable {
                    let filename: String
                    let gameType: String
                    let folder: String?
                    let displayName: String?
                    let tag: String?
                    let url: String
                }

                let remoteFiles = try JSONDecoder().decode([RemoteFile].self, from: data)
                let localFilenames = Set(store.items.map { $0.packageURL.lastPathComponent })

                for file in remoteFiles {
                    if localFilenames.contains(file.filename) { continue }
                    if let fileURL = URL(string: file.url) {
                        await MainActor.run {
                            store.importPackage(from: .remote(fileURL))
                        }
                        try await Task.sleep(nanoseconds: 5_000_000_000)
                    }
                }
            } catch {
                print("Lỗi đồng bộ: \(error.localizedDescription)")
            }
            await MainActor.run { isAutoSyncing = false }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DETAIL VIEW
// ═══════════════════════════════════════════════════════════════
struct PatchGameDetailView: View {
    let game: GameSelection
    @ObservedObject var store: PatchProjectStore
    @Binding var isAutoSyncing: Bool
    @Binding var actionAlert: PatchStoreAlert?
    let language: AppLanguage

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFolder: String? = nil
    @State private var workingFileID: String? = nil
    @State private var renameItem: PatchLibraryItem? = nil
    @State private var renameText: String = ""
    @State private var tagPickerItem: PatchLibraryItem? = nil

    private var gameItems: [PatchLibraryItem] {
        store.items.filter { item in
            let name = item.packageURL.lastPathComponent
            let isMax    = name.hasPrefix("ffmax_")
            let isNormal = name.hasPrefix("ffnormal_")
            let isPlain  = !isMax && !isNormal
            return game.prefix == "ffmax_" ? isMax : (isNormal || isPlain)
        }
    }

    /// Chỉ các folder thật có trong file, KHÔNG có "Tất cả"
    private var folders: [String] {
        var set = Set(gameItems.map { folderName(for: $0) })
        set.remove("")
        return Array(set).sorted()
    }

    private var displayedItems: [PatchLibraryItem] {
        guard let selected = selectedFolder else { return gameItems }
        return gameItems.filter { folderName(for: $0) == selected }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                FloatingParticlesView(particleCount: 45)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // TAB FOLDER
                    if !folders.isEmpty {
                        folderTabs
                    }

                    // DANH SÁCH
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
            }
            .navigationTitle(game.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        SoundFX.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
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

            // Đổi tên
            .alert("Đổi tên hiển thị", isPresented: Binding(
                get: { renameItem != nil },
                set: { if !$0 { renameItem = nil } }
            )) {
                TextField("Tên mới", text: $renameText)
                Button("Huỷ", role: .cancel) { renameItem = nil }
                Button("Lưu") { commitRename() }
            }

            // Đổi VIP/FREE
            .confirmationDialog(
                "Chọn loại tag",
                isPresented: Binding(
                    get: { tagPickerItem != nil },
                    set: { if !$0 { tagPickerItem = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("VIP 👑") { commitTag("VIP") }
                Button("FREE 🛡") { commitTag("FREE") }
                Button("Huỷ", role: .cancel) { tagPickerItem = nil }
            }
        }
    }

    // MARK: TABS
    private var folderTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(folders, id: \.self) { folder in
                    let isActive = selectedFolder == folder
                    Button {
                        SoundFX.tap()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedFolder = isActive ? nil : folder
                        }
                    } label: {
                        Text(folder.uppercased())
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(1.2)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(isActive ? Color.white : Color.white.opacity(0.06))
                            )
                            .foregroundStyle(isActive ? .black : .white.opacity(0.85))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                            .shadow(color: .white.opacity(isActive ? 0.25 : 0), radius: 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 14)
    }

    // MARK: ROW
    @ViewBuilder
    private func patchRow(item: PatchLibraryItem) -> some View {
        let receipt  = DevicePatchService.latestReceipt(projectID: item.id)
        let isApplied = receipt != nil
        let fileID   = item.id.uuidString
        let tag      = currentTag(for: item)

        HStack(spacing: 14) {
            // ICON
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(
                        LinearGradient(
                            colors: tag == "VIP"
                                ? [Color.yellow.opacity(0.25), Color.orange.opacity(0.1)]
                                : [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: tag == "VIP" ? "crown.fill" : "shield.lefthalf.filled")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tag == "VIP" ? Color.yellow : Color.white.opacity(0.9))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(
                        tag == "VIP"
                            ? Color.yellow.opacity(0.5)
                            : Color.white.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .shadow(color: tag == "VIP" ? .yellow.opacity(0.25) : .clear, radius: 8)

            // TÊN + TAG
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName(for: item))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Button {
                    SoundFX.tap()
                    tagPickerItem = item
                } label: {
                    Text(tag)
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(
                                tag == "VIP"
                                    ? Color.yellow.opacity(0.22)
                                    : Color.white.opacity(0.1)
                            )
                        )
                        .foregroundStyle(tag == "VIP" ? Color.yellow : Color.white.opacity(0.8))
                        .overlay(
                            Capsule()
                                .stroke(
                                    tag == "VIP"
                                        ? Color.yellow.opacity(0.5)
                                        : Color.white.opacity(0.25),
                                    lineWidth: 0.7
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // TOGGLE
            Toggle("", isOn: Binding(
                get: { isApplied },
                set: { newValue in
                    if newValue { SoundFX.tingTing() } else { SoundFX.tap() }
                    togglePatch(item: item, activate: newValue)
                }
            ))
            .labelsHidden()
            .tint(.green)
            .disabled(workingFileID == fileID)
            .shadow(color: isApplied ? .green.opacity(0.5) : .clear, radius: 8)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isApplied ? 0.05 : 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isApplied
                        ? Color.green.opacity(0.55)
                        : Color.white.opacity(0.22),
                    lineWidth: 1
                )
        )
        .shadow(
            color: isApplied ? .green.opacity(0.15) : .clear,
            radius: 12
        )
        .contextMenu {
            Button {
                SoundFX.tap()
                renameItem = item
                renameText = displayName(for: item)
            } label: {
                Label("Đổi tên hiển thị", systemImage: "pencil")
            }
            Button {
                SoundFX.tap()
                tagPickerItem = item
            } label: {
                Label("Đổi VIP / FREE", systemImage: "crown")
            }
        }
    }

    // MARK: HELPERS
    private func displayName(for item: PatchLibraryItem) -> String {
        if let override = PatchOverrides.displayName(for: item.id), !override.isEmpty {
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
        if let override = PatchOverrides.tag(for: item.id) { return override }
        let base = item.packageURL.deletingPathExtension().lastPathComponent
        return base.hasSuffix("_VIP") ? "VIP" : "FREE"
    }

    private func folderName(for item: PatchLibraryItem) -> String {
        let comps = item.packageURL.pathComponents.filter { $0 != "/" }
        if let idx = comps.firstIndex(where: { $0 == "ffmax" || $0 == "ffnormal" }),
           idx + 2 < comps.count {
            return comps[idx + 1]
        }
        let parent = item.packageURL.deletingLastPathComponent().lastPathComponent
        let ignore: Set<String> = ["Documents", "tmp", "proxy", ""]
        if !ignore.contains(parent) { return parent }
        return "Khác"
    }

    private func commitRename() {
        guard let item = renameItem else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            PatchOverrides.setDisplayName(trimmed, for: item.id)
            store.reload()
        }
        renameItem = nil
    }

    private func commitTag(_ tag: String) {
        guard let item = tagPickerItem else { return }
        PatchOverrides.setTag(tag, for: item.id)
        store.reload()
        tagPickerItem = nil
    }

    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        let fileID = item.id.uuidString
        workingFileID = fileID

        Task.detached(priority: .userInitiated) {
            do {
                if activate {
                    guard let project = item.project else { return }
                    _ = try DevicePatchService.apply(project: project)
                    await MainActor.run {
                        store.reload()
                        workingFileID = nil
                        actionAlert = PatchStoreAlert(
                            titleKey: "Thành công",
                            messageKey: "Đã kích hoạt patch thành công!"
                        )
                    }
                } else {
                    guard let receipt = DevicePatchService.latestReceipt(projectID: item.id) else {
                        await MainActor.run { workingFileID = nil }
                        return
                    }
                    try DevicePatchService.restore(receipt: receipt)
                    await MainActor.run {
                        store.reload()
                        workingFileID = nil
                        actionAlert = PatchStoreAlert(
                            titleKey: "Thành công",
                            messageKey: "Đã tắt / khôi phục patch!"
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
}

// ═══════════════════════════════════════════════════════════════
// MARK: - UNLOCK VIEW (giữ nguyên)
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
                        Text(store.unlockErrorArgument.map { language.text(errorKey, $0) }
                             ?? language.text(errorKey))
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

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}


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
