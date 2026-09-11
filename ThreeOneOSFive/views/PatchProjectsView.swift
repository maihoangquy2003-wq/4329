import SwiftUI
import UIKit
import AudioToolbox
import UniformTypeIdentifiers

// HIỆU ỨNG HẠT LITI BAY LÊN (NGÂN HÀ LUNG LINH)
struct ParticleEffectView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<60 {
                    let seed = Double(i) * 23.0
                    let x = (sin(now * 0.35 + seed) * 0.5 + 0.5) * size.width
                    let y = fmod(seed * 25.0 - now * 45.0 + size.height, size.height)
                    let particleSize = CGFloat(fmod(seed, 2.5) + 1.2)
                    let opacity = Double(sin(now * 1.5 + seed) * 0.4 + 0.6)
                    
                    let rect = CGRect(x: x, y: y, width: particleSize, height: particleSize)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// ÂM THANH "TING" + RUNG HAPTIC IPHONE
func playTingSound() {
    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    AudioServicesPlaySystemSound(1334)
}

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore
    
    @State private var remoteItems: [RemotePatchItem] = []
    @State private var isAutoSyncing = false
    @State private var actionAlert: PatchStoreAlert?
    
    @State private var navigateToMax = false
    @State private var navigateToNormal = false
    @State private var isAvatarPulsing = false
    
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
                    // HEADER AVATAR TO + HÀO QUANG TRẮNG SÁNG
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                                .frame(width: 140, height: 140)
                                .scaleEffect(isAvatarPulsing ? 1.3 : 1.0)
                                .opacity(isAvatarPulsing ? 0.0 : 1.0)
                            
                            AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                        .shadow(color: .white.opacity(0.6), radius: 15)
                                default:
                                    Circle().fill(Color.gray.opacity(0.3)).frame(width: 120, height: 120)
                                }
                            }
                        }
                        
                        Text("ZENITH SOLITUDE")
                            .font(.system(size: 26, weight: .black))
                            .tracking(3)
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.5), radius: 8)
                    }
                    .padding(.vertical, 30)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: false)) {
                            isAvatarPulsing = true
                        }
                    }
                    
                    // THẺ CHỌN GAME (NEON ĐEN VIỀN TRẮNG SẮC NÉT)
                    ScrollView {
                        VStack(spacing: 20) {
                            gameSelectionCard(title: "Free Fire Max") {
                                navigateToMax = true
                            }
                            gameSelectionCard(title: "Free Fire Thường") {
                                navigateToNormal = true
                            }
                        }
                        .padding(.horizontal, 20)
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
                await startContinuousAutoSync()
            }
            .alert(item: $actionAlert) { alert in
                Alert(title: Text(alert.titleKey), message: Text(alert.message(language: language)), dismissButton: .default(Text("Đã hiểu")))
            }
        }
    }

    @ViewBuilder
    private func gameSelectionCard(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/free.jpg")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.4), lineWidth: 1))
                    default:
                        RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.3)).frame(width: 60, height: 60)
                    }
                }
                
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text("MỞ MENU")
                        .font(.caption.weight(.heavy))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.black))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white, lineWidth: 1.5)
                    .shadow(color: .white.opacity(0.4), radius: 6, x: 0, y: 0)
            )
        }
        .buttonStyle(.plain)
    }

    // ĐỒNG BỘ NỀN MỖI 5 GIÂY CHỐNG LỖI CACHE
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
                            try await Task.sleep(nanoseconds: 2_000_000_000)
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

enum GameType: String, Hashable, Identifiable {
    case ffmax, ffnormal
    var id: String { self.rawValue }
    var title: String { self == .ffmax ? "Free Fire Max" : "Free Fire Thường" }
}

struct RemotePatchItem: Codable, Identifiable {
    var id: String { filename }
    let filename: String
    let gameType: String
    let folder: String
    let displayName: String
    let note: String?
    let url: String
}

// ROW HIỂN THỊ TÍNH NĂNG (VIỀN TRẮNG NEON SẮC NÉT)
struct PatchItemRowView: View {
    let rItem: RemotePatchItem
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
                Circle().fill(Color.white.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rItem.displayName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                
                if let note = rItem.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(Color.gray.opacity(0.9))
                }
            }
            
            Spacer()
            
            if isWorking {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.0)
                    .padding(.trailing, 8)
            } else {
                Toggle("", isOn: Binding(
                    get: { isApplied },
                    set: { newValue in
                        playTingSound() // Tiếng ting + haptic
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
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.black))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white, lineWidth: 1.5)
                .shadow(color: .white.opacity(0.4), radius: 5, x: 0, y: 0)
        )
    }
    
    private func togglePatch(item: PatchLibraryItem, activate: Bool, filename: String) {
        workingFilename = filename
        Task.detached(priority: .userInitiated) {
            do {
                if activate {
                    guard let project = item.project else {
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu chưa sẵn sàng hoặc file bị lỗi. Vui lòng thử lại sau vài giây."])
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
                    menuAlert = PatchStoreAlert(titleKey: "Lỗi", messageKey: "Đường dẫn tải file không hợp lệ.")
                    workingFilename = nil
                }
                return
            }
            
            await MainActor.run {
                store.importPackage(from: .remote(fileURL))
            }
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                store.reload()
                workingFilename = nil
                // ĐÃ ĐỔI THÔNG BÁO THEO YÊU CẦU CỦA BẠN
                menuAlert = PatchStoreAlert(titleKey: "Headlock Zenis", messageKey: "Hệ thống Headlock Zenis đã sẵn sàng, vui lòng kích hoạt lại lần nữa")
            }
        }
    }
}

// MENU CHI TIẾT THEO TAB THƯ MỤC
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
                HStack {
                    Text(gameType.title)
                        .font(.title2.weight(.black))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(10)
                            .background(Circle().fill(Color.white))
                    }
                }
                .padding(20)
                
                let gameItems = remoteItems.filter { $0.gameType == gameType.rawValue }
                let folders = Array(Set(gameItems.map { $0.folder })).sorted()
                let currentFolders = folders.isEmpty ? ["Aim", "Guns", "Chams", "Outfits"] : folders
                
                // THANH TAB THƯ MỤC NGANG
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(currentFolders, id: \.self) { folder in
                            Button {
                                withAnimation(.spring()) {
                                    selectedTab = folder
                                }
                            } label: {
                                Text(folder)
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 10)
                                    .background(selectedTab == folder ? Color.white : Color.black)
                                    .foregroundStyle(selectedTab == folder ? Color.black : Color.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.white, lineWidth: 1.5))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                
                // DANH SÁCH FILE
                ScrollView {
                    VStack(spacing: 16) {
                        let activeItemsInFolder = gameItems.filter { $0.folder == selectedTab }
                        
                        if activeItemsInFolder.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "folder.badge.slash")
                                    .font(.system(size: 45))
                                    .foregroundStyle(.gray)
                                Text("Chưa có cấu hình nào trong thư mục này.")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                            }
                            .padding(.top, 80)
                        } else {
                            ForEach(activeItemsInFolder) { rItem in
                                PatchItemRowView(
                                    rItem: rItem,
                                    store: store,
                                    workingFilename: $workingFilename,
                                    menuAlert: $menuAlert
                                )
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationBarHidden(true)
        .alert(item: $menuAlert) { alert in
            Alert(title: Text(alert.titleKey), message: Text(alert.message(language: language)), dismissButton: .default(Text("Đã hiểu")))
        }
        .onAppear {
            store.reload()
            if let firstFolder = Array(Set(remoteItems.filter { $0.gameType == gameType.rawValue }.map { $0.folder })).sorted().first {
                selectedTab = firstFolder
            }
        }
    }
}

// CÁC EXTENSION HỆ THỐNG GỐC CỦA DỰ ÁN
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
