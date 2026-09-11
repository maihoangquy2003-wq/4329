import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

// ═══════════════════════════════════════════════════════════════
// MARK: - PARTICLE BACKGROUND (HẠT LI TI BAY LÊN)
// ═══════════════════════════════════════════════════════════════
struct FloatingParticlesView: View {
    var particleCount: Int = 55
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
                    let wobble = sin(t * 0.9 + p.phase) * 12
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
                        size:    CGFloat.random(in: 1.2...3.4),
                        speed:   CGFloat.random(in: 22...60),
                        opacity: Double.random(in: 0.25...0.85),
                        phase:   Double.random(in: 0...(2 * .pi))
                    )
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MODEL: GAME SELECTION
// ═══════════════════════════════════════════════════════════════
struct GameSelection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let prefix: String
    let icon: String
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MAIN VIEW
// ═══════════════════════════════════════════════════════════════
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore

    @State private var searchText = ""
    @State private var isAutoSyncing = false
    @State private var workingFileID: String? = nil
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
                FloatingParticlesView(particleCount: 60)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    ScrollView {
                        VStack(spacing: 18) {
                            gameCard(
                                title: "Free Fire Max",
                                prefix: "ffmax_",
                                icon: "flame.fill",
                                gradient: [Color(red: 1, green: 0.35, blue: 0.1),
                                           Color(red: 0.9, green: 0.1, blue: 0.3)]
                            )
                            gameCard(
                                title: "Free Fire Thường",
                                prefix: "ffnormal_",
                                icon: "gamecontroller.fill",
                                gradient: [Color(red: 0.1, green: 0.6, blue: 1),
                                           Color(red: 0.4, green: 0.2, blue: 0.9)]
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
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                switch phase {
                case .empty:
                    ProgressView().frame(width: 84, height: 84)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 84, height: 84)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .shadow(color: Color.white.opacity(0.25), radius: 12)
                case .failure(_):
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 84))
                        .foregroundStyle(.white.opacity(0.4))
                @unknown default:
                    EmptyView()
                }
            }

            Text("ZENITH SOLITUDE")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .tracking(2.5)

            Text("PREMIUM PATCH STORE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(3)
        }
        .padding(.top, 20)
        .padding(.bottom, 22)
    }

    // MARK: GAME CARD
    @ViewBuilder
    private func gameCard(title: String, prefix: String, icon: String, gradient: [Color]) -> some View {
        let matchedItems = store.items.filter { item in
            let name = item.packageURL.lastPathComponent
            let isMax    = name.hasPrefix("ffmax_")
            let isNormal = name.hasPrefix("ffnormal_")
            let isPlain  = !isMax && !isNormal
            return prefix == "ffmax_" ? isMax : (isNormal || isPlain)
        }

        Button {
            AudioServicesPlaySystemSound(1104)   // 🔊 "tích" iPhone
            selectedGame = GameSelection(title: title, prefix: prefix, icon: icon)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        LinearGradient(colors: gradient,
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)

                        Text(matchedItems.isEmpty
                             ? "Chưa có file patch"
                             : "\(matchedItems.count) gói patch khả dụng")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()

                    if isAutoSyncing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Divider().background(Color.white.opacity(0.15))

                HStack {
                    Text("MỞ DANH SÁCH")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.55))
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.03))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .white.opacity(0.05), radius: 12, y: 4)
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
                let localFilenames = store.items.map { $0.packageURL.lastPathComponent }

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
// MARK: - DETAIL VIEW (TAB THƯ MỤC + LIST PATCH)
// ═══════════════════════════════════════════════════════════════
struct PatchGameDetailView: View {
    let game: GameSelection
    @ObservedObject var store: PatchProjectStore
    @Binding var isAutoSyncing: Bool
    @Binding var actionAlert: PatchStoreAlert?
    let language: AppLanguage

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFolder: String = "Tất cả"
    @State private var workingFileID: String? = nil
    @State private var renamingItem: PatchLibraryItem? = nil
    @State private var newName: String = ""

    // Toàn bộ item thuộc game này
    private var gameItems: [PatchLibraryItem] {
        store.items.filter { item in
            let name = item.packageURL.lastPathComponent
            let isMax    = name.hasPrefix("ffmax_")
            let isNormal = name.hasPrefix("ffnormal_")
            let isPlain  = !isMax && !isNormal
            return game.prefix == "ffmax_" ? isMax : (isNormal || isPlain)
        }
    }

    private var folders: [String] {
        var set = Set(gameItems.map { folderName(for: $0) })
        set.insert("Tất cả")
        return Array(set).sorted()
    }

    private var displayedItems: [PatchLibraryItem] {
        if selectedFolder == "Tất cả" { return gameItems }
        return gameItems.filter { folderName(for: $0) == selectedFolder }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                FloatingParticlesView(particleCount: 40)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tabs thư mục
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(folders, id: \.self) { folder in
                                Button {
                                    AudioServicesPlaySystemSound(1104)
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedFolder = folder
                                    }
                                } label: {
                                    Text(folder.uppercased())
                                        .font(.system(size: 12, weight: .bold))
                                        .tracking(1)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(selectedFolder == folder
                                                      ? Color.white
                                                      : Color.white.opacity(0.06))
                                        )
                                        .foregroundStyle(selectedFolder == folder ? .black : .white)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 14)

                    // List
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if displayedItems.isEmpty {
                                emptyState
                            } else {
                                ForEach(displayedItems) { item in
                                    patchRow(item: item)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }

                // Nút "VÀO GAMENGAY" ở dưới cùng
                VStack {
                    Spacer()
                    Button {
                        AudioServicesPlaySystemSound(1104)
                        launchGame()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                            Text("VÀO GAMENGAY (\(game.title))")
                                .font(.system(size: 14, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundStyle(.black)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(Color.white)
                        )
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1)
                        )
                        .shadow(color: .white.opacity(0.2), radius: 14, y: 4)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(game.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .foregroundStyle(.white)
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
            .alert("Đổi tên hiển thị", isPresented: Binding(
                get: { renamingItem != nil },
                set: { if !$0 { renamingItem = nil } }
            )) {
                TextField("Tên mới", text: $newName)
                Button("Huỷ", role: .cancel) { renamingItem = nil }
                Button("Lưu") { commitRename() }
            }
        }
    }

    // MARK: ROW
    @ViewBuilder
    private func patchRow(item: PatchLibraryItem) -> some View {
        let receipt  = DevicePatchService.latestReceipt(projectID: item.id)
        let isApplied = receipt != nil
        let fileID   = item.id.uuidString
        let tag      = tagName(for: item)

        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 46, height: 46)
                Image(systemName: tag == "VIP" ? "crown.fill" : "shield.lefthalf.filled")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tag == "VIP" ? Color.yellow : Color.white.opacity(0.85))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(displayName(for: item))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(tag)
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.5)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(tag == "VIP"
                                           ? Color.yellow.opacity(0.2)
                                           : Color.white.opacity(0.12))
                        )
                        .foregroundStyle(tag == "VIP" ? Color.yellow : Color.white.opacity(0.75))
                }

                Text(isApplied ? "Đang kích hoạt" : "Chưa kích hoạt")
                    .font(.system(size: 11))
                    .foregroundStyle(isApplied ? Color.green : Color.white.opacity(0.4))
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isApplied },
                set: { newValue in
                    AudioServicesPlaySystemSound(1104)   // 🔊 "tích" iPhone
                    togglePatch(item: item, activate: newValue)
                }
            ))
            .labelsHidden()
            .tint(.green)
            .disabled(workingFileID == fileID)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(isApplied ? 0.06 : 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isApplied
                        ? Color.green.opacity(0.5)
                        : Color.white.opacity(0.25),
                        lineWidth: 1)
        )
        .contextMenu {
            Button {
                renamingItem = item
                newName = displayName(for: item)
            } label: {
                Label("Đổi tên hiển thị", systemImage: "pencil")
            }
            Button(role: .destructive) {
                AudioServicesPlaySystemSound(1104)
            } label: {
                Label("Xoá", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            Text("Chưa có gói patch nào trong mục này.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.top, 60)
    }

    // MARK: HELPERS
    private func displayName(for item: PatchLibraryItem) -> String {
        if let name = item.project?.name, !name.isEmpty { return name }
        let base = item.packageURL.deletingPathExtension().lastPathComponent
        return base
            .replacingOccurrences(of: "_VIP", with: "")
            .replacingOccurrences(of: "_FREE", with: "")
            .replacingOccurrences(of: "ffmax_", with: "")
            .replacingOccurrences(of: "ffnormal_", with: "")
    }

    private func tagName(for item: PatchLibraryItem) -> String {
        let base = item.packageURL.deletingPathExtension().lastPathComponent
        return base.hasSuffix("_VIP") ? "VIP" : "FREE"
    }

    private func folderName(for item: PatchLibraryItem) -> String {
        let comps = item.packageURL.pathComponents.filter { $0 != "/" }
        if let idx = comps.firstIndex(where: { $0 == "ffmax" || $0 == "ffnormal" }) {
            if idx + 2 < comps.count { return comps[idx + 1] }
        }
        let parent = item.packageURL.deletingLastPathComponent().lastPathComponent
        if !parent.isEmpty && parent != "Documents" && parent != "tmp" && parent != "proxy" {
            return parent
        }
        return "Khác"
    }

    private func launchGame() {
        let scheme = game.prefix == "ffmax_"
            ? "freefiremax://"
            : "freefire://"
        if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func commitRename() {
        // Vì PatchProjectStore không lộ API đổi tên, ta lưu mapping vào UserDefaults
        guard let item = renamingItem else { return }
        let key = "patch_display_\(item.id.uuidString)"
        UserDefaults.standard.set(newName, forKey: key)
        renamingItem = nil
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
                        actionAlert = PatchStoreAlert(titleKey: "Thành công",
                                                      messageKey: "Đã kích hoạt patch thành công!")
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
                        actionAlert = PatchStoreAlert(titleKey: "Thành công",
                                                      messageKey: "Đã tắt/khôi phục patch!")
                    }
                }
            } catch {
                await MainActor.run {
                    workingFileID = nil
                    actionAlert = PatchStoreAlert(titleKey: "Lỗi",
                                                  messageKey: "Thao tác thất bại: \(error.localizedDescription)")
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - UNLOCK VIEW (GIỮ NGUYÊN)
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

// ═══════════════════════════════════════════════════════════════
// MARK: - PRESENTATION MODIFIER (GIỮ NGUYÊN)
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
