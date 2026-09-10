import SwiftUI
import UIKit
import AudioToolbox
import UniformTypeIdentifiers

// MARK: - HIỆU ỨNG HẠT LITI BAY TỪ DƯỚI LÊN (SIÊU ĐẸP)
struct ParticleEffectView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<80 { // Tăng mật độ hạt
                    let seed = Double(i) * 17.5
                    // Tính toán x dao động nhẹ
                    let x = (sin(now * 0.4 + seed) * 0.3 + 0.5) * size.width
                    // Tính toán y đi lên (từ dưới lên trên)
                    let y = size.height - fmod(now * 50.0 + seed * 80.0, size.height + 50)
                    
                    let particleSize = CGFloat(fmod(seed, 2.5) + 1.5)
                    let rect = CGRect(x: x, y: y, width: particleSize, height: particleSize)
                    
                    // Làm mờ hạt khi lên cao
                    let opacity = Double(y / size.height) * 0.8
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - ÂM THANH & RUNG KHI KÍCH HOẠT
func playiPhoneTickSound() {
    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    AudioServicesPlaySystemSound(1104) // Âm thanh Tích đặc trưng
}

// MARK: - PATCH PROJECTS VIEW CHÍNH
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore
    
    @State private var remoteItems: [RemotePatchItem] = []
    @State private var isAutoSyncing = false
    @State private var actionAlert: PatchStoreAlert?
    
    @State private var navigateToMax = false
    @State private var navigateToNormal = false
    @State private var avatarRotation: Double = 0.0
    
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    init(onOpenSettings: @escaping () -> Void = {}, onOpenLogs: @escaping () -> Void = {}) {
        self.onOpenSettings = onOpenSettings
        self.onOpenLogs = onOpenLogs
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ParticleEffectView()
                
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 35) {
                            // HEADER AVATAR VIỀN TRẮNG NỀN ĐEN
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2.5)
                                        .frame(width: 110, height: 110)
                                        .rotationEffect(.degrees(avatarRotation))
                                    
                                    AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                                .frame(width: 98, height: 98)
                                                .clipShape(Circle())
                                        default:
                                            Circle().fill(Color.gray.opacity(0.3)).frame(width: 98, height: 98)
                                        }
                                    }
                                }
                                
                                Text("ZENITH SOLITUDE")
                                    .font(.system(size: 24, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .shadow(color: .white.opacity(0.8), radius: 8)
                            }
                            .padding(.top, 40)
                            
                            // THẺ GAME CHÍNH (TỐI GIẢN)
                            VStack(spacing: 20) {
                                mainGameCard(title: "FREE FIRE MAX", icon: "https://solitudepremium.click/ipa/proxy/free.jpg") {
                                    playiPhoneTickSound()
                                    navigateToMax = true
                                }
                                mainGameCard(title: "FREE FIRE THƯỜNG", icon: "https://solitudepremium.click/ipa/proxy/free.jpg") {
                                    playiPhoneTickSound()
                                    navigateToNormal = true
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToMax) {
                GameDetailMenuView(gameType: .ffmax, remoteItems: remoteItems, store: store)
            }
            .navigationDestination(isPresented: $navigateToNormal) {
                GameDetailMenuView(gameType: .ffnormal, remoteItems: remoteItems, store: store)
            }
            .task {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    avatarRotation = 360
                }
                await startContinuousAutoSync()
            }
            .alert(item: $actionAlert) { alert in
                Alert(title: Text(alert.titleKey), message: Text(alert.message(language: language)), dismissButton: .default(Text("OK")))
            }
        }
    }

    @ViewBuilder
    private func mainGameCard(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: icon)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(width: 65, height: 65)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white, lineWidth: 1.5))
                    default:
                        RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.3)).frame(width: 65, height: 65)
                    }
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("MỞ")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(14)
            }
            .padding(20)
            .background(Color.black)
            .cornerRadius(22)
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // ĐỒNG BỘ NỀN
    private func startContinuousAutoSync() async {
        guard !isAutoSyncing else { return }
        isAutoSyncing = true
        
        while !Task.isCancelled {
            do {
                guard let url = URL(string: "https://solitudepremium.click/ipa/proxy/list.php") else { continue }
                let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
                let (data, _) = try await URLSession.shared.data(for: request)
                let decoded = try JSONDecoder().decode([RemotePatchItem].self, from: data)
                
                await MainActor.run { self.remoteItems = decoded }
                
                var hasNewFiles = false
                let localNames = store.items.map { $0.packageURL.lastPathComponent.lowercased().replacingOccurrences(of: "%20", with: "_") }
                
                for item in decoded {
                    let safeRemoteName = item.filename.lowercased().replacingOccurrences(of: "%20", with: "_")
                    let alreadyExists = localNames.contains { $0.contains((safeRemoteName as NSString).deletingPathExtension) }
                    
                    if !alreadyExists {
                        if let fileURL = URL(string: item.url) {
                            await MainActor.run { store.importPackage(from: .remote(fileURL)) }
                            hasNewFiles = true
                            try await Task.sleep(nanoseconds: 3_000_000_000)
                        }
                    }
                }
                
                if hasNewFiles {
                    await MainActor.run { store.reload() }
                }
                
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
        isAutoSyncing = false
    }
}

// MARK: - ENUM & MODEL (BỔ SUNG NOTE)
enum GameType: String, Hashable, Identifiable {
    case ffmax, ffnormal
    var id: String { self.rawValue }
    var title: String { self == .ffmax ? "FREE FIRE MAX" : "FREE FIRE THƯỜNG" }
    var bundleID: String { self == .ffmax ? "com.dts.freefiremax" : "com.dts.freefirethuong" }
}

struct RemotePatchItem: Codable, Identifiable {
    var id: String { filename }
    let filename: String
    let gameType: String
    let folder: String
    let displayName: String
    let url: String
    let note: String? // Thêm trường ghi chú
}

// MARK: - ITEM ROW VIEW (HIỂN THỊ GHI CHÚ, TIẾNG TÍCH)
struct PatchItemRowView: View {
    let rItem: RemotePatchItem
    let selectedTab: String
    
    @ObservedObject var store: PatchProjectStore
    @Binding var workingFilename: String?
    @Binding var menuAlert: PatchStoreAlert?
    
    var body: some View {
        let matchedStoreItem = store.items.first(where: {
            let local = $0.packageURL.lastPathComponent.lowercased().replacingOccurrences(of: "%20", with: "_").replacingOccurrences(of: " ", with: "_")
            let remote = rItem.filename.lowercased().replacingOccurrences(of: "%20", with: "_").replacingOccurrences(of: " ", with: "_")
            let localBase = (local as NSString).deletingPathExtension
            let remoteBase = (remote as NSString).deletingPathExtension
            
            return local == remote || localBase.contains(remoteBase) || remoteBase.contains(localBase) || $0.project?.name.lowercased() == remoteBase
        })
        
        let isApplied = matchedStoreItem != nil ? (DevicePatchService.latestReceipt(projectID: matchedStoreItem!.id) != nil) : false
        let isWorking = workingFilename == rItem.filename
        
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.1)).frame(width: 48, height: 48)
                Image(systemName: isApplied ? "checkmark.shield.fill" : "shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(rItem.displayName)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                
                if let note = rItem.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.gray)
                } else {
                    Text(selectedTab.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            if isWorking {
                ProgressView().tint(.white).scaleEffect(0.8)
            } else {
                Toggle("", isOn: Binding(
                    get: { isApplied },
                    set: { newValue in
                        playiPhoneTickSound() // Tiếng tích
                        if let item = matchedStoreItem {
                            togglePatch(item: item, activate: newValue, filename: rItem.filename)
                        } else {
                            downloadAndNotify(rItem: rItem)
                        }
                    }
                ))
                .labelsHidden()
                .tint(.white) // Gạt bật lên màu trắng
            }
        }
        .padding(18)
        .background(Color.black)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white, lineWidth: 1.5))
    }
    
    private func togglePatch(item: PatchLibraryItem, activate: Bool, filename: String) {
        workingFilename = filename
        Task.detached(priority: .userInitiated) {
            do {
                if activate {
                    guard let project = item.project else {
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu lỗi."])
                    }
                    _ = try DevicePatchService.apply(project: project)
                } else {
                    guard let receipt = DevicePatchService.latestReceipt(projectID: item.id) else {
                        await MainActor.run { workingFilename = nil }
                        return
                    }
                    try DevicePatchService.restore(receipt: receipt)
                }
                await MainActor.run {
                    store.reload()
                    workingFilename = nil
                }
            } catch {
                await MainActor.run {
                    workingFilename = nil
                    menuAlert = PatchStoreAlert(titleKey: "Thất bại", messageKey: error.localizedDescription)
                }
            }
        }
    }
    
    private func downloadAndNotify(rItem: RemotePatchItem) {
        workingFilename = rItem.filename
        Task.detached {
            guard let urlString = rItem.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let fileURL = URL(string: urlString) else {
                await MainActor.run {
                    menuAlert = PatchStoreAlert(titleKey: "Lỗi", messageKey: "Link tải file không hợp lệ.")
                    workingFilename = nil
                }
                return
            }
            
            await MainActor.run {
                store.importPackage(from: .remote(fileURL))
            }
            
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            
            await MainActor.run {
                store.reload()
                workingFilename = nil
                menuAlert = PatchStoreAlert(titleKey: "THÔNG BÁO", messageKey: "ĐÃ SẢY RA LỖI VUI LÒNG KÍCH HOẠT LẠI")
            }
        }
    }
}

// MARK: - GAME DETAIL MENU VIEW
struct GameDetailMenuView: View {
    let gameType: GameType
    let remoteItems: [RemotePatchItem]
    @ObservedObject var store: PatchProjectStore
    
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: String = "Aim"
    @State private var workingFilename: String? = nil
    @State private var menuAlert: PatchStoreAlert?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ParticleEffectView()
            
            VStack(spacing: 0) {
                // HEADER
                HStack(spacing: 14) {
                    Button(action: { playiPhoneTickSound(); dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    
                    Text(gameType.title)
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 15)
                
                let gameItems = remoteItems.filter { $0.gameType == gameType.rawValue }
                let folders = Array(Set(gameItems.map { $0.folder })).sorted()
                let currentFolders = folders.isEmpty ? ["Aim", "Guns", "Chams", "Outfits"] : folders
                
                // TAB BAR NGANG
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(currentFolders, id: \.self) { folder in
                            let isSelected = selectedTab.lowercased() == folder.lowercased()
                            Button(action: {
                                playiPhoneTickSound() // Tiếng tích khi chuyển tab
                                selectedTab = folder
                            }) {
                                Text(folder.uppercased())
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 12)
                                    .background(isSelected ? Color.white : Color.black)
                                    .foregroundStyle(isSelected ? Color.black : Color.white)
                                    .cornerRadius(22)
                                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white, lineWidth: 1.5))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
                
                // DANH SÁCH ITEM
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        let activeItemsInFolder = gameItems.filter { $0.folder == selectedTab }
                        
                        if activeItemsInFolder.isEmpty {
                            VStack(spacing: 15) {
                                Image(systemName: "square.dashed")
                                    .font(.system(size: 45))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("TRỐNG")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.gray)
                            }
                            .padding(.top, 120)
                        } else {
                            ForEach(activeItemsInFolder) { rItem in
                                PatchItemRowView(
                                    rItem: rItem,
                                    selectedTab: selectedTab,
                                    store: store,
                                    workingFilename: $workingFilename,
                                    menuAlert: $menuAlert
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .alert(item: $menuAlert) { alert in
            Alert(title: Text(alert.titleKey), message: Text(alert.message(language: language)), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            store.reload()
            if let firstFolder = Array(Set(remoteItems.filter { $0.gameType == gameType.rawValue }.map { $0.folder })).sorted().first {
                selectedTab = firstFolder
            }
        }
    }
}

// MARK: - EXTENSION HỆ THỐNG GỐC CỦA ZENITH
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
                }
            }
            .navigationTitle(language.text("patch.unlock"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Mở khóa", action: unlock).disabled(password.isEmpty) }
            }
        }
    }
    private func unlock() { store.unlock(password: password) }
}

private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore
    func body(content: Content) -> some View {
        content.sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { request in
            PatchUnlockView(store: store, request: request)
        }
    }
}

extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View {
        modifier(PatchStorePresentationModifier(store: store))
    }
}
