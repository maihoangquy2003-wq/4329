import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore
    
    @State private var searchText = ""
    @State private var isAutoSyncing = false
    @State private var workingFileID: String? = nil
    @State private var actionAlert: PatchStoreAlert?
    
    // State điều hướng sang màn hình chi tiết theo game được chọn
    @State private var selectedGame: GameSelection? = nil

    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    enum GameSelection: Identifiable {
        case ffMax, ffNormal
        var id: Self { self }
        
        var title: String {
            switch self {
            case .ffMax: return "Free Fire Max"
            case .ffNormal: return "Free Fire Thường"
            }
        }
        
        var prefix: String {
            switch self {
            case .ffMax: return "ffmax_"
            case .ffNormal: return "ffnormal_"
            }
        }
        
        var bundleID: String {
            switch self {
            case .ffMax: return "com.dts.freefiremax"
            case .ffNormal: return "com.dts.freefireth"
            }
        }
    }

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
                
                VStack(spacing: 0) {
                    // HEADER VỚI AVATAR LẤY TỪ LI.JPG
                    VStack(spacing: 12) {
                        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 80, height: 80)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.yellow, lineWidth: 2))
                                    .shadow(color: Color.yellow.opacity(0.5), radius: 8)
                            case .failure(_):
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        
                        Text("Zenith Solitude")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.3), radius: 5)
                    }
                    .padding(.vertical, 20)
                    
                    // DANH SÁCH CHỌN GAME CARD (ẤN VÀO ĐỂ MỞ MÀN HÌNH CHI TIẾT GIỐNG ẢNH MẪU)
                    ScrollView {
                        VStack(spacing: 16) {
                            gameSelectionCard(
                                title: "Free Fire Max",
                                prefix: "ffmax_",
                                selection: .ffMax
                            )
                            
                            gameSelectionCard(
                                title: "Free Fire Thường",
                                prefix: "ffnormal_",
                                selection: .ffNormal
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                syncRemotePatches()
            }
            .sheet(item: $selectedGame) { game in
                GameDetailView(game: game, store: store, workingFileID: $workingFileID, actionAlert: $actionAlert)
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

    @ViewBuilder
    private func gameSelectionCard(title: String, prefix: String, selection: GameSelection) -> some View {
        let matchedItems = store.items.filter { item in
            let name = item.packageURL.lastPathComponent
            return name.hasPrefix(prefix) || (!name.hasPrefix("ffmax_") && !name.hasPrefix("ffnormal_") && prefix == "ffnormal_")
        }
        
        Button(action: {
            selectedGame = selection
        }) {
            HStack(spacing: 14) {
                AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/free.jpg")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 55, height: 55)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 55, height: 55)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(matchedItems.isEmpty ? "Chưa có file patch" : "Đã tải: \(matchedItems.count) file (Nhấn để mở)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                if isAutoSyncing {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.gray)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(#colorLiteral(red: 0.1176470588, green: 0.1607843137, blue: 0.231372549, alpha: 1))))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        }
    }

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
                    let category: String?
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
            
            await MainActor.run {
                isAutoSyncing = false
            }
        }
    }
}

// MÀN HÌNH CHI TIẾT GIAO DIỆN CHUẨN NHƯ ẢNH MẪU
struct GameDetailView: View {
    let game: PatchProjectsView.GameSelection
    @ObservedObject var store: PatchProjectStore
    @Binding var workingFileID: String?
    @Binding var actionAlert: PatchStoreAlert?
    @Environment(\.dismiss) private var dismiss

    // Các danh mục chuẩn
    let availableCategories = ["aim", "guns", "chams", "outfits"]
    @State private var selectedCategory: String = "aim"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // HEADER THÔNG TIN GAME & NÚT ĐÓNG (X)
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/free.jpg")) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill().frame(width: 45, height: 45).clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.3)).frame(width: 45, height: 45)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(game.bundleID)
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Circle().fill(Color.gray.opacity(0.3)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // TAB BAR CHỌN DANH MỤC (Aim, Guns, Chams, Outfits...) - ẨN NẾU KHÔNG CÓ FILE
                let gameItems = store.items.filter { item in
                    let name = item.packageURL.lastPathComponent
                    return name.hasPrefix(game.prefix) || (!name.hasPrefix("ffmax_") && !name.hasPrefix("ffnormal_") && game == .ffNormal)
                }
                
                let activeCategories = availableCategories.filter { cat in
                    gameItems.contains { item in
                        let name = item.packageURL.lastPathComponent
                        let parts = name.split(separator: "_")
                        let fileCat = parts.indices.contains(1) ? String(parts[1]) : "aim"
                        return fileCat.lowercased() == cat
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(activeCategories.isEmpty ? availableCategories : activeCategories, id: \.self) { cat in
                            Button(action: { selectedCategory = cat }) {
                                Text(cat.capitalized)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == cat ? Color.white : Color.clear)
                                    .foregroundStyle(selectedCategory == cat ? Color.black : Color.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                
                // DANH SÁCH FILE TRONG DANH MỤC ĐƯỢC CHỌN
                ScrollView {
                    VStack(spacing: 12) {
                        let filteredItems = gameItems.filter { item in
                            let name = item.packageURL.lastPathComponent
                            let parts = name.split(separator: "_")
                            let fileCat = parts.indices.contains(1) ? String(parts[1]) : "aim"
                            return fileCat.lowercased() == selectedCategory
                        }
                        
                        if filteredItems.isEmpty {
                            Text("Chưa có gói patch nào trong mục này.")
                                .font(.footnote)
                                .foregroundStyle(.gray)
                                .italic()
                                .padding(.top, 40)
                        } else {
                            ForEach(filteredItems) { item in
                                let receipt = DevicePatchService.latestReceipt(projectID: item.id)
                                let isApplied = receipt != nil
                                let fileID = item.id.uuidString
                                
                                HStack(spacing: 14) {
                                    Image(systemName: "shield.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.cyan)
                                        .frame(width: 36, height: 36)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(item.project?.name ?? item.packageURL.lastPathComponent)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            
                                            Text("FREE")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.4)))
                                                .foregroundStyle(.white)
                                        }
                                        
                                        Text(selectedCategory)
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { isApplied },
                                        set: { newValue in
                                            togglePatch(item: item, activate: newValue)
                                        }
                                    ))
                                    .labelsHidden()
                                    .tint(.green)
                                    .disabled(workingFileID == fileID)
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color(#colorLiteral(red: 0.1176470588, green: 0.1607843137, blue: 0.231372549, alpha: 1))))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                
                // NÚT BÊN DƯỚI: VÀO GAME NGAY
                Button(action: {
                    // Giữ nguyên logic vào game nếu cần
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("VÀO GAME NGAY (\(game.title))")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(16)
            }
        }
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
                        actionAlert = PatchStoreAlert(titleKey: "Thành công", messageKey: "Đã kích hoạt patch thành công!")
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
                        actionAlert = PatchStoreAlert(titleKey: "Thành công", messageKey: "Đã tắt/khôi phục patch!")
                    }
                }
            } catch {
                await MainActor.run {
                    workingFileID = nil
                    actionAlert = PatchStoreAlert(titleKey: "Lỗi", messageKey: "Thao tác thất bại: \(error.localizedDescription)")
                }
            }
        }
    }
}

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
