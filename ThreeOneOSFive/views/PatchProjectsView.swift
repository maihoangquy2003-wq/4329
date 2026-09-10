import SwiftUI
import UIKit
import AudioToolbox
import UniformTypeIdentifiers

// MARK: - HIỆU ỨNG HẠT LITI BAY LÊN
struct ParticleEffectView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<70 {
                    let seed = Double(i) * 19.0
                    let x = (sin(now * 0.5 + seed) * 0.5 + 0.5) * size.width
                    let y = fmod(seed * 35.0 - now * 65.0 + size.height, size.height)
                    let particleSize = CGFloat(fmod(seed, 2.5) + 2.0)
                    let rect = CGRect(x: x, y: y, width: particleSize, height: particleSize)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.7)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - ÂM THANH KHI KÍCH HOẠT
func playiPhoneTickSound() {
    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    AudioServicesPlaySystemSound(1104)
}

// MARK: - PATCH PROJECTS VIEW
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
                            // HEADER AVATAR
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2.5)
                                        .frame(width: 106, height: 106)
                                        .rotationEffect(.degrees(avatarRotation))
                                    
                                    AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                                .frame(width: 96, height: 96)
                                                .clipShape(Circle())
                                        default:
                                            Circle().fill(Color.gray.opacity(0.3)).frame(width: 96, height: 96)
                                        }
                                    }
                                }
                                
                                Text("ZENITH SOLITUDE")
                                    .font(.system(size: 22, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .shadow(color: .white, radius: 6)
                            }
                            .padding(.top, 30)
                            
                            // THẺ GAME CHÍNH
                            VStack(spacing: 18) {
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
    private func mainGameCard(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 18) {
                AsyncImage(url: URL(string: icon)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white, lineWidth: 1.5))
                    default:
                        RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.3)).frame(width: 60, height: 60)
                    }
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("MỞ")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(14)
            }
            .padding(18)
            .background(Color.black)
            .cornerRadius(22)
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

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
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
        isAutoSyncing = false
    }
}

enum GameType: String, Hashable, Identifiable {
    case ffmax, ffnormal
    var id: String { self.rawValue }
    var title: String { self == .ffmax ? "FREE FIRE MAX" : "FREE FIRE THƯỜNG" }
    var bundleID: String { self == .ffmax ? "com.dts.freefiremax" : "com.dts.freefirethuong" }
}

struct RemotePatchItem: Codable, Identifiable {
    var id: String { url }
    let filename: String
    let gameType: String
    let folder: String
    let displayName: String
    let url: String
    let note: String?
}

// MARK: - ITEM ROW VIEW (TỰ ĐỘNG TẢI VÀ KÍCH HOẠT NGAY KHI GẠT)
struct PatchItemRowView: View {
    let rItem: RemotePatchItem
    let selectedTab: String
    
    @ObservedObject var store: PatchProjectStore
    @Binding var workingItemURL: String?
    @Binding var menuAlert: PatchStoreAlert?
    
    var body: some View {
        let matchedStoreItem = store.items.first(where: {
            let local = $0.packageURL.lastPathComponent.lowercased().replacingOccurrences(of: "%20", with: "_").replacingOccurrences(of: " ", with: "_")
            let remote = rItem.filename.lowercased().replacingOccurrences(of: "%20", with: "_").replacingOccurrences(of: " ", with: "_")
            return local == remote
        })
        
        let isApplied = matchedStoreItem != nil ? (DevicePatchService.latestReceipt(projectID: matchedStoreItem!.id) != nil) : false
        let isWorking = workingItemURL == rItem.url
        
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
                        playiPhoneTickSound()
                        if let item = matchedStoreItem {
                            togglePatch(item: item, activate: newValue)
                        } else {
                            // NẾU CHƯA CÓ FILE TRÊN MÁY -> TỰ ĐỘNG TẢI NGAY VÀ KÍCH HOẠT LUÔN
                            downloadAndApply(rItem: rItem, activate: newValue)
                        }
                    }
                ))
                .labelsHidden()
                .tint(.white)
            }
        }
        .padding(18)
        .background(Color.black)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white, lineWidth: 1.5))
    }
    
    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        workingItemURL = rItem.url
        Task.detached(priority: .userInitiated) {
            do {
                if activate {
                    let currentItems = await MainActor.run { store.items }
                    for otherItem in currentItems where otherItem.id != item.id {
                        if let receipt = DevicePatchService.latestReceipt(projectID: otherItem.id) {
                            try? DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                        }
                    }
                    
                    let baseProject = await MainActor.run { item.project }
                    guard let baseProject else {
                        throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Dự án không tồn tại."])
                    }
                    
                    let schemaVersion = await MainActor.run { item.summary.schemaVersion }
                    let canInspect = await MainActor.run { item.canInspectContents }
                    let project = (schemaVersion >= 2 && canInspect)
                        ? ((try? PatchProjectLibrary.synchronizeWorkspace(item: item)) ?? baseProject)
                        : baseProject
                    
                    _ = try DevicePatchService.apply(project: project)
                } else {
                    if let receipt = DevicePatchService.latestReceipt(projectID: item.id) {
                        try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                    }
                }
                
                await MainActor.run {
                    store.reload()
                    workingItemURL = nil
                }
            } catch {
                await MainActor.run {
                    workingItemURL = nil
                    menuAlert = PatchStoreAlert(titleKey: "Thất bại", messageKey: error.localizedDescription)
                }
            }
        }
    }
    
    // HÀM TẢI VÀ TỰ ĐỘNG KÍCH HOẠT NGAY LẬP TỨC KHÔNG CẦN BẤM LẦN 2
    private func downloadAndApply(rItem: RemotePatchItem, activate: Bool) {
        workingItemURL = rItem.url
        Task.detached {
            guard let urlString = rItem.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let fileURL = URL(string: urlString) else {
                await MainActor.run {
                    menuAlert = PatchStoreAlert(titleKey: "Lỗi", messageKey: "Link tải file không hợp lệ.")
                    workingItemURL = nil
                }
                return
            }
            
            // 1. Tiến hành import file về store
            await MainActor.run {
                store.importPackage(from: .remote(fileURL))
                store.reload()
            }
            
            // 2. Chờ 1.5 giây để hệ thống ghi file hoàn tất vào bộ nhớ tạm
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            // 3. Tìm lại item vừa tải xong để apply tự động
            let newlyMatchedItem = await MainActor.run {
                store.items.first(where: {
                    let local = $0.packageURL.lastPathComponent.lowercased().replacingOccurrences(of: "%20", with: "_").replacingOccurrences(of: " ", with: "_")
                    let remote = rItem.filename.lowercased().replacingOccurrences(of: "%20", with: "_").replacingOccurrences(of: " ", with: "_")
                    return local == remote
                })
            }
            
            if let item = newlyMatchedItem, activate {
                do {
                    let currentItems = await MainActor.run { store.items }
                    for otherItem in currentItems where otherItem.id != item.id {
                        if let receipt = DevicePatchService.latestReceipt(projectID: otherItem.id) {
                            try? DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                        }
                    }
                    
                    let baseProject = await MainActor.run { item.project }
                    if let baseProject {
                        let schemaVersion = await MainActor.run { item.summary.schemaVersion }
                        let canInspect = await MainActor.run { item.canInspectContents }
                        let project = (schemaVersion >= 2 && canInspect)
                            ? ((try? PatchProjectLibrary.synchronizeWorkspace(item: item)) ?? baseProject)
                            : baseProject
                        
                        _ = try DevicePatchService.apply(project: project)
                    }
                } catch {
                    // Bỏ qua lỗi nhỏ nếu chưa kịp apply, store vẫn giữ file
                }
            }
            
            await MainActor.run {
                store.reload()
                workingItemURL = nil
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
    @State private var workingItemURL: String? = nil
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
                                playiPhoneTickSound()
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
                                    workingItemURL: $workingItemURL,
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
