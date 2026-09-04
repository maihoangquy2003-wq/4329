import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - GIAO DIỆN QUẢN LÝ MOD MENU (CHUNG MỘT FILE)
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var store: PatchProjectStore
    
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void
    
    @AppStorage("selected_game_bundle") private var selectedGameBundle: String = "com.dts.freefiremax"
    @State private var remoteItems: [RemoteAimItem] = []
    @State private var selectedTab: String = "Aim"
    @State private var isFetching = false
    
    let menuTabs = ["Aim", "Guns", "Chams", "Outfits"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Thông Tin Game & Nút Làm Mới
                    HStack(spacing: 12) {
                        CachedImageView(url: "https://solitudepremium.click/ipa/proxy/free.jpg", fallbackIcon: "gamecontroller.fill")
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(gameTitleName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text(selectedGameBundle)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        
                        Button(action: fetchRemoteData) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        }
                        .disabled(isFetching)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Thanh Tabs Danh Mục (Aim, Guns, Chams, Outfits)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(menuTabs, id: \.self) { tab in
                                Button(action: { UXFeedback.click(); selectedTab = tab }) {
                                    Text(tab)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(selectedTab == tab ? Color.white : Color.black.opacity(0.6))
                                        .foregroundColor(selectedTab == tab ? .black : .white)
                                        .cornerRadius(20)
                                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    
                    // Danh Sách Tính Năng Tương Ứng Với Tab
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            let filtered = remoteItems.filter {
                                $0.target == selectedGameBundle && $0.category.lowercased() == selectedTab.lowercased()
                            }
                            
                            if filtered.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "folder.badge.questionmark").font(.system(size: 40)).foregroundColor(.white.opacity(0.3))
                                    Text("Chưa có tính năng nào trong mục này").font(.system(size: 12, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.top, 80)
                            } else {
                                ForEach(filtered) { item in
                                    let localMatch = store.items.first(where: { $0.project?.name == item.name })
                                    ModFunctionRow(remoteItem: item, localItem: localMatch, store: store)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 90)
                    }
                    
                    Spacer()
                }
                
                // Nút "VÀO GAME NGAY" Ở ĐÁY MÀN HÌNH
                VStack {
                    Spacer()
                    Button(action: {
                        UXFeedback.click()
                    }) {
                        HStack {
                            Image(systemName: "play.fill").font(.system(size: 12))
                            Text("VÀO GAME NGAY (\(gameTitleName))")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.white)
                        .cornerRadius(25)
                        .shadow(color: .white.opacity(0.3), radius: 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear { fetchRemoteData() }
    }
    
    private var gameTitleName: String {
        switch selectedGameBundle {
        case "com.dts.freefiremax": return "Free Fire Max"
        case "com.dts.freefireth": return "Free Fire"
        case "com.garena.game.kgvn": return "Liên Quân Mobile"
        default: return "Game Mobile"
        }
    }
    
    private func fetchRemoteData() {
        guard !isFetching else { return }
        isFetching = true
        guard let url = URL(string: "https://solitudepremium.click/ipa/proxy/4329.php?api=1") else { isFetching = false; return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            defer { DispatchQueue.main.async { self.isFetching = false } }
            guard let data = data else { return }
            if let decoded = try? JSONDecoder().decode([RemoteAimItem].self, from: data) {
                DispatchQueue.main.async {
                    self.remoteItems = decoded
                    for item in decoded {
                        if !self.store.items.contains(where: { $0.project?.name == item.name }) {
                            downloadAndCache(item: item)
                        }
                    }
                }
            }
        }.resume()
    }
    
    private func downloadAndCache(item: RemoteAimItem) {
        guard let url = URL(string: item.url) else { return }
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url) {
                let temp = FileManager.default.temporaryDirectory.appendingPathComponent("\(item.id).3105")
                try? data.write(to: temp)
                DispatchQueue.main.async { self.store.importPackage(at: temp) }
            }
        }
    }
}

// Hàng Chức Năng Gạt Bật/Tắt (Áp Dụng / Khôi Phục)
struct ModFunctionRow: View {
    let remoteItem: RemoteAimItem
    let localItem: PatchLibraryItem?
    @ObservedObject var store: PatchProjectStore
    
    @State private var isApplied = false
    @State private var isWorking = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)).frame(width: 40, height: 40)
                Image(systemName: isApplied ? "checkmark.shield.fill" : "shield.fill")
                    .foregroundColor(isApplied ? .green : .white)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(remoteItem.name).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    Text("FREE")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(4)
                        .foregroundColor(.white)
                }
                Text("cache").font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            
            if isWorking {
                ProgressView().tint(.white).scaleEffect(0.7)
            } else {
                Toggle("", isOn: Binding(
                    get: { isApplied },
                    set: { val in togglePatch(on: val) }
                ))
                .labelsHidden()
                .tint(.green)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.6))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .onAppear(perform: checkStatus)
    }
    
    private func checkStatus() {
        guard let local = localItem else { return }
        isApplied = DevicePatchService.latestReceipt(projectID: local.id) != nil
    }
    
    private func togglePatch(on: Bool) {
        guard let local = localItem, !isWorking else { UXFeedback.error(); return }
        isWorking = true
        UXFeedback.click()
        
        Task.detached(priority: .userInitiated) {
            do {
                if on {
                    guard let base = local.project else { throw NSError(domain: "", code: 0) }
                    let proj = local.summary.schemaVersion >= 2 && local.canInspectContents ? try PatchProjectLibrary.synchronizeWorkspace(item: local) : base
                    _ = try DevicePatchService.apply(project: proj)
                } else {
                    if let receipt = DevicePatchService.latestReceipt(projectID: local.id) {
                        try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                    }
                }
                await MainActor.run {
                    self.isApplied = on
                    self.isWorking = false
                    UXFeedback.success()
                }
            } catch {
                await MainActor.run {
                    self.isApplied = !on
                    self.isWorking = false
                    UXFeedback.error()
                }
            }
        }
    }
}

struct RemoteAimItem: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let target: String
    let url: String
}

// Các thành phần mở rộng tương thích hệ thống
private struct PatchUnlockView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    let request: PatchPasswordRequest
    var body: some View { Text("Unlock") }
}

private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore
    func body(content: Content) -> some View { content }
}

extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View { modifier(PatchStorePresentationModifier(store: store)) }
}
