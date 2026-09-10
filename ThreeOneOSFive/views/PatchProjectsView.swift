import SwiftUI
import UIKit
import AudioToolbox
import UniformTypeIdentifiers

// MARK: - HIỆU ỨNG HẠT NEON BAY LÊN
struct ParticleEffectView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<45 {
                    let seed = Double(i) * 37.0
                    let x = (sin(now * 0.25 + seed) * 0.5 + 0.5) * size.width
                    let y = fmod(seed * 20.0 - now * 45.0 + size.height, size.height)
                    let rect = CGRect(x: x, y: y, width: 2, height: 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.35)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - ÂM THANH & RUNG CHUẨN IPHONE
func playiPhoneTickSound() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    AudioServicesPlaySystemSound(1306)
}

// MARK: - PATCH PROJECTS VIEW (GIAO DIỆN CYBERPUNK CAO CẤP)
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
                        VStack(spacing: 28) {
                            // HEADER AVATAR XOAY VÒNG NEON
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .stroke(AngularGradient(gradient: Gradient(colors: [.white, .gray, .black, .white]), center: .center), lineWidth: 3)
                                        .frame(width: 104, height: 104)
                                        .rotationEffect(.degrees(avatarRotation))
                                        .shadow(color: .white.opacity(0.5), radius: 8)
                                    
                                    AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                                .frame(width: 90, height: 90)
                                                .clipShape(Circle())
                                        default:
                                            Circle().fill(Color.gray.opacity(0.3)).frame(width: 90, height: 90)
                                        }
                                    }
                                }
                                
                                Text("Zenith Solitude")
                                    .font(.system(size: 24, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .shadow(color: .white.opacity(0.7), radius: 6)
                            }
                            .padding(.top, 20)
                            
                            // THẺ GAME CHÍNH
                            VStack(spacing: 16) {
                                mainGameCard(title: "Free Fire Max", bundleID: "com.dts.freefiremax", icon: "https://solitudepremium.click/ipa/proxy/free.jpg") {
                                    navigateToMax = true
                                }
                                mainGameCard(title: "Free Fire Thường", bundleID: "com.dts.freefirethuong", icon: "https://solitudepremium.click/ipa/proxy/free.jpg") {
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
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
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
    private func mainGameCard(title: String, bundleID: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: icon)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    default:
                        RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.3)).frame(width: 52, height: 52)
                    }
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text(bundleID)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text("MỞ MENU")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .white.opacity(0.3), radius: 6)
            }
            .padding(16)
            .background(Color.black)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.25), lineWidth: 1.5))
            .shadow(color: .white.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // ĐỒNG BỘ NỀN (GIỮ NGUYÊN 100% LOGIC)
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

// MARK: - ENUM & MODEL (GIỮ NGUYÊN)
enum GameType: String, Hashable, Identifiable {
    case ffmax, ffnormal
    var id: String { self.rawValue }
    var title: String { self == .ffmax ? "Free Fire Max" : "Free Fire Thường" }
    var bundleID: String { self == .ffmax ? "com.dts.freefiremax" : "com.dts.freefirethuong" }
}

struct RemotePatchItem: Codable, Identifiable {
    var id: String { filename }
    let filename: String
    let gameType: String
    let folder: String
    let displayName: String
    let url: String
}

// MARK: - ITEM VIEW THÔNG MINH (CYBERPUNK ROW)
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
        
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)).frame(width: 42, height: 42)
                Image(systemName: isApplied ? "checkmark.shield.fill" : "shield.fill")
                    .foregroundStyle(isApplied ? .white : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rItem.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(selectedTab.lowercased())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            if isWorking {
                ProgressView().tint(.white).scaleEffect(0.7)
            } else {
                Toggle("", isOn: Binding(
                    get: { isApplied },
                    set: { newValue in
                        playiPhoneTickSound()
                        if let item = matchedStoreItem {
                            togglePatch(item: item, activate: newValue, filename: rItem.filename)
                        } else {
                            downloadAndNotify(rItem: rItem)
                        }
                    }
                ))
                .labelsHidden()
                .tint(.white)
            }
        }
        .padding(14)
        .background(Color.black)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(isApplied ? 0.6 : 0.2), lineWidth: isApplied ? 1.5 : 1))
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
                menuAlert = PatchStoreAlert(titleKey: "Tải hoàn tất", messageKey: "Đã tải xong file! Vui lòng gạt lại để kích hoạt.")
            }
        }
    }
}

// MARK: - GAME DETAIL MENU VIEW (GIAO DIỆN MOD MENU CYBERPUNK)
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
                // HEADER CHI TIẾT GAME
                HStack(spacing: 12) {
                    Button(action: { playiPhoneTickSound(); dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .white.opacity(0.4), radius: 4)
                    }
                    
                    Text(gameType.title)
                        .font(.system(size: 18, weight: .bold))
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
                    HStack(spacing: 10) {
                        ForEach(currentFolders, id: \.self) { folder in
                            let isSelected = selectedTab.lowercased() == folder.lowercased()
                            Button(action: {
                                playiPhoneTickSound()
                                selectedTab = folder
                            }) {
                                Text(folder)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? Color.white : Color.black)
                                    .foregroundStyle(isSelected ? Color.black : Color.white)
                                    .cornerRadius(20)
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(isSelected ? 1.0 : 0.3), lineWidth: 1.5))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                // DANH SÁCH ITEM
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        let activeItemsInFolder = gameItems.filter { $0.folder == selectedTab }
                        
                        if activeItemsInFolder.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "folder.badge.questionmark")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.2))
                                Text("Chưa có cấu hình nào trong thư mục này.")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.gray)
                            }
                            .padding(.top, 100)
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
                    .padding(.bottom, 40)
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

// MARK: - EXTENSION HỆ THỐNG GỐC (GIỮ NGUYÊN 100%)
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
