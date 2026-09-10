import SwiftUI
import UIKit
import AudioToolbox
import UniformTypeIdentifiers

// MARK: - HIỆU ỨNG HẠT BỤI & NGÂN HÀ NEON LUNG LINH
public struct GalaxyParticleCanvasView: View {
    public init() {}
    public var body: some View {
        TimelineView(.animation) { context in
            Canvas { graphicsContext, size in
                let time = context.date.timeIntervalSinceReferenceDate
                for i in 0..<200 {
                    let seed = Double(i) * 73.0
                    let x = (sin(time * 0.3 + seed) * 0.5 + 0.5) * size.width
                    let speed = 70.0 + fmod(seed, 120.0)
                    let y = size.height - fmod(time * speed + seed, size.height + 100)
                    let particleSize = CGFloat(fmod(seed, 3.0) + 1.2)
                    let opacity = Double(sin(time * 2.0 + seed) * 0.5 + 0.5)
                    
                    let rect = CGRect(x: x, y: y, width: particleSize, height: particleSize)
                    graphicsContext.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - ÂM THANH "TÍT/TÍCH" CHUẨN IPHONE + HAPTIC
struct iPhoneFeedback {
    static func tick() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AudioServicesPlaySystemSound(1104) // Âm thanh click/tích chuẩn hệ thống iOS
    }
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
                GalaxyParticleCanvasView()
                
                VStack(spacing: 0) {
                    // HEADER AVATAR THU NHỎ GỌN, SẮC SẢO + HÀO QUANG NEON
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .stroke(LinearGradient(colors: [.white, .clear, .white], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                                .frame(width: 105, height: 105)
                                .scaleEffect(isAvatarPulsing ? 1.25 : 1.0)
                                .opacity(isAvatarPulsing ? 0.0 : 1.0)
                            
                            CachedImageView(url: "https://solitudepremium.click/ipa/proxy/li.jpg", fallbackIcon: "person.circle.fill")
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(color: .white.opacity(0.8), radius: 10, x: 0, y: 0)
                        }
                        
                        Text("ZENITH SOLITUDE")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(.white)
                            .shadow(color: .white, radius: 8, x: 0, y: 0)
                    }
                    .padding(.vertical, 20)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                            isAvatarPulsing = true
                        }
                    }
                    
                    // THẺ CHỌN GAME THU NHỎ - NEON VIỀN TRẮNG PHÁT SÁNG
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            gameCard(title: "Free Fire Max") {
                                navigateToMax = true
                            }
                            gameCard(title: "Free Fire Thường") {
                                navigateToNormal = true
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
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
    private func gameCard(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            iPhoneFeedback.tick()
            action()
        }) {
            HStack(spacing: 14) {
                CachedImageView(url: "https://solitudepremium.click/ipa/proxy/free.jpg", fallbackIcon: "flame.fill")
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.6), lineWidth: 1.2))
                    .shadow(color: .white, radius: 4)
                
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .white, radius: 3)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("MỞ MENU")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: .white, radius: 5)
            }
            .padding(14)
            .background(Color.black)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white, lineWidth: 1.2)
                    .shadow(color: .white, radius: 6, x: 0, y: 0)
            )
        }
        .buttonStyle(NeonScaleButtonStyle())
    }

    // ĐỒNG BỘ TỪ THƯ MỤC CHUẨN ipa/proxy/4329/list.php
    private func startContinuousAutoSync() async {
        guard !isAutoSyncing else { return }
        isAutoSyncing = true
        
        while !Task.isCancelled {
            do {
                guard let url = URL(string: "https://solitudepremium.click/ipa/proxy/4329/list.php") else { continue }
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
    let folder: String // Phân loại gọn gàng theo: "Aim", "ModSkin", v.v. (được quy hoạch trong 4329/ hoặc 4329/modskin/)
    let displayName: String
    let note: String?
    let url: String
}

// MARK: - ROW HIỂN THỊ TÍNH NĂNG GỌN GÀNG, NEON SẮC SẢO
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
        
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.15)).frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                Image(systemName: rItem.folder.lowercased().contains("skin") ? "tshirt.fill" : "bolt.shield.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .shadow(color: .white, radius: 4)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(rItem.displayName)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.5), radius: 2)
                
                if let note = rItem.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            if isWorking {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.85)
                    .padding(.trailing, 6)
            } else {
                Toggle("", isOn: Binding(
                    get: { isApplied },
                    set: { newValue in
                        iPhoneFeedback.tick()
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
        .padding(12)
        .background(Color.black)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white, lineWidth: 1.2)
                .shadow(color: .white.opacity(0.6), radius: 5, x: 0, y: 0)
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
                menuAlert = PatchStoreAlert(titleKey: "Headlock Zenis", messageKey: "Hệ thống Headlock Zenis đã sẵn sàng, vui lòng kích hoạt lại lần nữa")
            }
        }
    }
}

// MARK: - MENU CHI TIẾT THEO DANH MỤC THƯ MỤC (AIM, MODSKIN,...)
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
            GalaxyParticleCanvasView()
            
            VStack(spacing: 0) {
                // HEADER THU GỌN
                HStack {
                    Text(gameType.title)
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .white, radius: 4)
                    
                    Spacer()
                    
                    Button {
                        iPhoneFeedback.tick()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(8)
                            .background(Circle().fill(Color.white))
                            .shadow(color: .white, radius: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                let gameItems = remoteItems.filter { $0.gameType == gameType.rawValue }
                let folders = Array(Set(gameItems.map { $0.folder })).sorted()
                let currentFolders = folders.isEmpty ? ["Aim", "ModSkin"] : folders
                
                // THANH TAB THƯ MỤC NGANG (Chia theo folder Aim, ModSkin gọn gàng)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(currentFolders, id: \.self) { folder in
                            Button {
                                iPhoneFeedback.tick()
                                withAnimation(.spring()) {
                                    selectedTab = folder
                                }
                            } label: {
                                Text(folder)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical: 7)
                                    .background(selectedTab == folder ? Color.white : Color.black)
                                    .foregroundColor(selectedTab == folder ? Color.black : Color.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.white, lineWidth: 1.2))
                                    .shadow(color: selectedTab == folder ? .white.opacity(0.8) : .clear, radius: 4)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                
                // DANH SÁCH FILE THEO THƯ MỤC
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        let activeItemsInFolder = gameItems.filter { $0.folder == selectedTab }
                        
                        if activeItemsInFolder.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "folder.badge.slash")
                                    .font(.system(size: 35))
                                    .foregroundColor(.white.opacity(0.5))
                                Text("Chưa có cấu hình nào trong thư mục này.")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.top, 60)
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
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
