import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - MÀN HÌNH QUẢN LÝ MOD MENU (PHÂN LOẠI THƯ MỤC)
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var store: PatchProjectStore
    
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void
    
    @State private var remoteItems: [RemoteAimItem] = []
    @State private var isFetchingRemote = false
    @State private var selectedGameTab: String = "com.dts.freefireth" // Mặc định FF Thường
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tiêu đề & Nút đồng bộ thủ công từ máy chủ
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TRUNG TÂM AIM & MOD")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                                .shadow(color: .white, radius: 5)
                            Text("Đồng bộ trực tuyến từ máy chủ")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        
                        Button(action: fetchRemoteAim) {
                            Image(systemName: isFetchingRemote ? "arrow.clockwise" : "arrow.triangle.2.circlepath")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(isFetchingRemote ? 360 : 0))
                                .animation(isFetchingRemote ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isFetchingRemote)
                                .padding(10)
                                .background(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        }
                        .disabled(isFetchingRemote)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    
                    // THANH CHỌN GAME (FF THƯỜNG / FF MAX) DÙNG CHUNG LOGO FREE FIRE
                    HStack(spacing: 15) {
                        GameTabButton(
                            title: "Free Fire Thường",
                            bundle: "com.dts.freefireth",
                            iconUrl: "https://solitudepremium.click/ipa/proxy/free.jpg",
                            isSelected: selectedGameTab == "com.dts.freefireth"
                        ) {
                            UXFeedback.click()
                            selectedGameTab = "com.dts.freefireth"
                        }
                        
                        GameTabButton(
                            title: "Free Fire Max",
                            bundle: "com.dts.freefiremax",
                            iconUrl: "https://solitudepremium.click/ipa/proxy/free.jpg",
                            isSelected: selectedGameTab == "com.dts.freefiremax"
                        ) {
                            UXFeedback.click()
                            selectedGameTab = "com.dts.freefiremax"
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    
                    // DANH SÁCH CHỨC NĂNG PHÂN THEO THƯ MỤC
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            let filteredRemoteItems = remoteItems.filter { $0.target == selectedGameTab }
                            let groupedItems = Dictionary(grouping: filteredRemoteItems, by: { $0.category })
                            
                            if groupedItems.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "folder.badge.questionmark")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white.opacity(0.3))
                                    Text("Chưa có tính năng nào cho phiên bản này")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 80)
                            } else {
                                ForEach(groupedItems.keys.sorted(), id: \.self) { category in
                                    VStack(alignment: .leading, spacing: 10) {
                                        // Tiêu đề Thư Mục (VD: AIM, MOD SKIN)
                                        HStack {
                                            Image(systemName: "folder.fill").foregroundColor(.orange)
                                            Text(category.uppercased())
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        .padding(.horizontal, 4)
                                        
                                        // Danh sách item trong thư mục
                                        VStack(spacing: 0) {
                                            ForEach(groupedItems[category] ?? [], id: \.id) { remoteItem in
                                                let localItem = store.items.first(where: { $0.project?.name == remoteItem.name })
                                                
                                                RemotePatchToggleRow(
                                                    remoteItem: remoteItem,
                                                    localItem: localItem,
                                                    store: store,
                                                    language: language
                                                )
                                                if remoteItem.id != groupedItems[category]?.last?.id {
                                                    Divider().background(Color.white.opacity(0.1))
                                                }
                                            }
                                        }
                                        .background(Color.black.opacity(0.7))
                                        .cornerRadius(16)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .onAppear {
            fetchRemoteAim()
        }
    }
    
    // Tải cấu hình tự động từ PHP Server
    private func fetchRemoteAim() {
        guard !isFetchingRemote else { return }
        isFetchingRemote = true
        
        guard let apiURL = URL(string: "https://solitudepremium.click/ipa/proxy/4329.php?api=1") else {
            isFetchingRemote = false
            return
        }
        
        URLSession.shared.dataTask(with: apiURL) { data, _, _ in
            defer { DispatchQueue.main.async { self.isFetchingRemote = false } }
            guard let data = data else { return }
            
            do {
                let decoded = try JSONDecoder().decode([RemoteAimItem].self, from: data)
                DispatchQueue.main.async {
                    self.remoteItems = decoded
                    for item in decoded {
                        if !self.store.items.contains(where: { $0.project?.name == item.name }) {
                            self.downloadAndImport(item: item)
                        }
                    }
                }
            } catch {
                print("Lỗi phân tích dữ liệu cấu hình từ server.")
            }
        }.resume()
    }
    
    private func downloadAndImport(item: RemoteAimItem) {
        guard let fileUrl = URL(string: item.url) else { return }
        DispatchQueue.global().async {
            if let fileData = try? Data(contentsOf: fileUrl) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(item.id).3105")
                try? fileData.write(to: tempURL)
                DispatchQueue.main.async {
                    self.store.importPackage(at: tempURL)
                }
            }
        }
    }
}

// Cấu trúc dữ liệu phản hồi từ API PHP
struct RemoteAimItem: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let target: String
    let url: String
}

// Nút Tab chuyển đổi Game Thường / Max
struct GameTabButton: View {
    let title: String
    let bundle: String
    let iconUrl: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CachedImageView(url: iconUrl, fallbackIcon: "flame.fill")
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text(bundle)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(10)
            .background(isSelected ? Color.white.opacity(0.15) : Color.black.opacity(0.5))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: isSelected ? 1.5 : 1))
        }
    }
}

// Hàng tùy chỉnh tính năng kèm công tắc Áp dụng / Khôi phục
private struct RemotePatchToggleRow: View {
    let remoteItem: RemoteAimItem
    let localItem: PatchLibraryItem?
    @ObservedObject var store: PatchProjectStore
    let language: AppLanguage
    
    @State private var isApplied: Bool = false
    @State private var isWorking: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isApplied ? Color.green.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 36, height: 36)
                Image(systemName: isApplied ? "checkmark.shield.fill" : "shield")
                    .foregroundColor(isApplied ? .green : .white.opacity(0.5))
                    .font(.system(size: 14))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(remoteItem.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(isApplied ? "Đang hoạt động (Đã ghi đè)" : "Đã tắt (Bấm gạt để bật)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(isApplied ? .green : .white.opacity(0.5))
            }
            
            Spacer()
            
            if isWorking {
                ProgressView().tint(.white).scaleEffect(0.7)
            } else {
                Toggle("", isOn: Binding(
                    get: { isApplied },
                    set: { newValue in handleToggle(turnOn: newValue) }
                ))
                .labelsHidden()
                .tint(.green)
            }
        }
        .padding(14)
        .onAppear(perform: checkStatus)
    }
    
    private func checkStatus() {
        guard let local = localItem else { return }
        if DevicePatchService.latestReceipt(projectID: local.id) != nil {
            isApplied = true
        } else {
            isApplied = false
        }
    }
    
    private func handleToggle(turnOn: Bool) {
        guard let local = localItem, !isWorking else {
            UXFeedback.error()
            return
        }
        isWorking = true
        UXFeedback.click()
        
        Task.detached(priority: .userInitiated) {
            if turnOn {
                do {
                    guard let baseProject = local.project else {
                        throw NSError(domain: "ZenithSolitude", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid project"])
                    }
                    let project = local.summary.schemaVersion >= 2 && local.canInspectContents ? try PatchProjectLibrary.synchronizeWorkspace(item: local) : baseProject
                    _ = try DevicePatchService.apply(project: project)
                    
                    await MainActor.run {
                        self.isApplied = true
                        self.isWorking = false
                        UXFeedback.success()
                    }
                } catch {
                    await MainActor.run {
                        self.isApplied = false
                        self.isWorking = false
                        UXFeedback.error()
                    }
                }
            } else {
                do {
                    if let receipt = DevicePatchService.latestReceipt(projectID: local.id) {
                        try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                    }
                    await MainActor.run {
                        self.isApplied = false
                        self.isWorking = false
                        UXFeedback.success()
                    }
                } catch {
                    await MainActor.run {
                        self.isApplied = true
                        self.isWorking = false
                        UXFeedback.error()
                    }
                }
            }
        }
    }
}

// Các thành phần mở rộng tương thích hệ thống mã nguồn gốc
private struct PatchUnlockView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    let request: PatchPasswordRequest
    @State private var password = ""
    var body: some View {
        NavigationStack {
            Form {
                SecureField(language.text("patch.password"), text: $password)
                if let errorKey = store.unlockErrorKey { Text(language.text(errorKey)).foregroundColor(.red) }
            }
            .navigationTitle(language.text("patch.unlock"))
        }
    }
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
