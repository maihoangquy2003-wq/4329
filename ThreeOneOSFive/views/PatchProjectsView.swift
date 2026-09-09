import SwiftUI
import UIKit
import AudioToolbox
import UniformTypeIdentifiers

// HIỆU ỨNG HẠT LI TI BAY LÊN
struct ParticleEffectView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<35 {
                    let seed = Double(i) * 37.0
                    let x = (sin(now * 0.3 + seed) * 0.5 + 0.5) * size.width
                    let y = fmod(seed * 20.0 - now * 40.0 + size.height, size.height)
                    let rect = CGRect(x: x, y: y, width: 2.5, height: 2.5)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.4)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// HÀM PHÁT ÂM THANH & RUNG CHUẨN IPHONE KHI BẬT TOGGLE
func playiPhoneTickSound() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    AudioServicesPlaySystemSound(1104) // Âm thanh click chuẩn hệ thống iOS
}

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore
    
    @State private var remoteItems: [RemotePatchItem] = []
    @State private var isAutoSyncing = false
    @State private var selectedGame: GameType? = nil // Mở menu chi tiết khi chọn game
    @State private var actionAlert: PatchStoreAlert?
    
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
                ParticleEffectView() // Hiệu ứng hạt bay lên
                
                VStack(spacing: 0) {
                    // HEADER AVATAR TỪ LI.JPG
                    VStack(spacing: 10) {
                        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                                    .frame(width: 75, height: 75)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                    .shadow(color: .white.opacity(0.3), radius: 6)
                            default:
                                Circle().fill(Color.gray.opacity(0.3)).frame(width: 75, height: 75)
                            }
                        }
                        
                        Text("Zenith Solitude")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.vertical, 16)
                    
                    // THẺ GAME CHÍNH (SẠCH SẼ, KHÔNG HIỆN FILE RỜI BÊN NGOÀI)
                    ScrollView {
                        VStack(spacing: 16) {
                            mainGameCard(
                                title: "Free Fire Max",
                                bundleID: "com.dts.freefiremax",
                                type: .ffmax
                            )
                            
                            mainGameCard(
                                title: "Free Fire Thường",
                                bundleID: "com.dts.freefirethuong",
                                type: .ffnormal
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                syncRemoteMetadata()
            }
            .navigationDestination(item: $selectedGame) { game in
                GameDetailMenuView(gameType: game, remoteItems: remoteItems, store: store)
            }
            .alert(item: $actionAlert) { alert in
                Alert(title: Text(alert.titleKey), message: Text(alert.message(language: language)), dismissButton: .default(Text("OK")))
            }
        }
    }

    @ViewBuilder
    private func mainGameCard(title: String, bundleID: String, type: GameType) -> some View {
        Button {
            selectedGame = type
        } label: {
            HStack(spacing: 14) {
                AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/free.jpg")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    default:
                        RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.3)).frame(width: 50, height: 50)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(bundleID)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                Text("MỞ MENU")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.4), lineWidth: 1))
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.gray)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.8)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // ĐỒNG BỘ DANH SÁCH METADATA TỪ WEB
    private func syncRemoteMetadata() {
        guard !isAutoSyncing else { return }
        isAutoSyncing = true
        
        Task {
            do {
                guard let url = URL(string: "https://solitudepremium.click/ipa/proxy/list.php") else { return }
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode([RemotePatchItem].self, from: data)
                
                await MainActor.run {
                    self.remoteItems = decoded
                    isAutoSyncing = false
                }
                
                // Tự động tải ngầm các file chưa có về kho lưu trữ của App
                let localFilenames = store.items.map { $0.packageURL.lastPathComponent }
                for item in decoded {
                    if !localFilenames.contains(item.filename) {
                        if let fileURL = URL(string: item.url) {
                            await MainActor.run {
                                store.importPackage(from: .remote(fileURL))
                            }
                            try await Task.sleep(nanoseconds: 2_000_000_000)
                        }
                    }
                }
            } catch {
                await MainActor.run { isAutoSyncing = false }
            }
        }
    }
}

// CÁC MODEL VÀ MENU CHI TIẾT
enum GameType: String, Hashable, Identifiable {
    case ffmax, ffnormal
    var id: String { self.rawValue }
    
    var title: String {
        self == .ffmax ? "Free Fire Max" : "Free Fire Thường"
    }
    
    var bundleID: String {
        self == .ffmax ? "com.dts.freefiremax" : "com.dts.freefirethuong"
    }
}

struct RemotePatchItem: Codable, Identifiable {
    var id: String { filename }
    let filename: String
    let gameType: String
    let folder: String
    let displayName: String
    let url: String
}

struct GameDetailMenuView: View {
    let gameType: GameType
    let remoteItems: [RemotePatchItem]
    @ObservedObject var store: PatchProjectStore
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: String = "Aim"
    @State private var workingFilename: String? = nil
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ParticleEffectView()
            
            VStack(spacing: 0) {
                // TOP HEADER NÚT ĐÓNG & TÊN GAME
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gameType.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(gameType.bundleID)
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(16)
                
                // LẤY DANH SÁCH THƯ MỤC (TABS) TỪ DỮ LIỆU WEB HOẶC MẶC ĐỊNH
                let gameItems = remoteItems.filter { $0.gameType == gameType.rawValue }
                let folders = Array(Set(gameItems.map { $0.folder })).sorted()
                let currentFolders = folders.isEmpty ? ["Aim", "Guns", "Chams", "Outfits"] : folders
                
                // THANH TAB NGANG (AIM, GUNS, CHAMS, OUTFITS...)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(currentFolders, id: \.self) { folder in
                            Button {
                                selectedTab = folder
                            } label: {
                                Text(folder)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == folder ? Color.white : Color.black)
                                    .foregroundStyle(selectedTab == folder ? Color.black : Color.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                
                // DANH SÁCH PATCH TRONG THƯ MỤC ĐƯỢC CHỌN
                ScrollView {
                    VStack(spacing: 12) {
                        let activeItemsInFolder = gameItems.filter { $0.folder == selectedTab }
                        
                        if activeItemsInFolder.isEmpty {
                            Text("Chưa có cấu hình nào trong thư mục này.")
                                .font(.footnote)
                                .foregroundStyle(.gray)
                                .padding(.top, 40)
                        } else {
                            ForEach(activeItemsInFolder) { rItem in
                                let matchedStoreItem = store.items.first(where: { $0.packageURL.lastPathComponent == rItem.filename })
                                let receipt = matchedStoreItem != nil ? DevicePatchService.latestReceipt(projectID: matchedStoreItem!.id) : nil
                                let isApplied = receipt != nil
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "shield.checkerboard")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(rItem.displayName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text(selectedTab.lowercased())
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { isApplied },
                                        set: { newValue in
                                            playiPhoneTickSound() // Phát tiếng tích như iPhone
                                            if let item = matchedStoreItem {
                                                togglePatch(item: item, activate: newValue, filename: rItem.filename)
                                            }
                                        }
                                    ))
                                    .labelsHidden()
                                    .tint(.green)
                                    .disabled(workingFilename == rItem.filename || matchedStoreItem == nil)
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.8)))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
                            }
                        }
                    }
                    .padding(16)
                }
                
                // NÚT VÀO GAME NGAY Ở DƯỚI CÙNG
                Button {
                    // Xử lý mở game hoặc hoàn tất
                } label: {
                    Text("🎮 VÀO GAME NGAY (\(gameType.title))")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                }
                .padding(16)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let firstFolder = Array(Set(remoteItems.filter { $0.gameType == gameType.rawValue }.map { $0.folder })).sorted().first {
                selectedTab = firstFolder
            }
        }
    }

    private func togglePatch(item: PatchLibraryItem, activate: Bool, filename: String) {
        workingFilename = filename
        Task.detached(priority: .userInitiated) {
            do {
                if activate {
                    guard let project = item.project else { return }
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
                }
            }
        }
    }
}

// BỔ SUNG EXTENSION HỆ THỐNG CỦA DỰ ÁN
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
