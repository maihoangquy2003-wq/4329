import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var store: PatchProjectStore
    
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void
    
    // TRẠNG THÁI CHUYỂN MÀN HÌNH (Trang chủ <-> Mod Menu)
    @State private var showModMenu = false
    @AppStorage("selected_game_bundle") private var selectedGameBundle: String = "com.dts.freefiremax"
    
    // Dữ liệu Mod Menu
    @State private var remoteItems: [RemoteAimItem] = []
    @State private var selectedTab: String = "Aim"
    @State private var isFetching = false
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.06).ignoresSafeArea()
            
            if !showModMenu {
                homeScreen.transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                modMenuScreen.transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showModMenu)
        .onAppear { fetchRemoteData() }
    }
    
    // MARK: - 1. GIAO DIỆN TRANG CHỦ CHÍNH THỨC
    private var homeScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { AudioServicesPlaySystemSound(1306); onOpenSettings() }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .bold)).foregroundColor(.white).frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.08))).overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                Spacer()
                Button(action: { AudioServicesPlaySystemSound(1306); onOpenLogs() }) {
                    Image(systemName: "person")
                        .font(.system(size: 18, weight: .bold)).foregroundColor(.white).frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.08))).overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
            }
            .padding(.horizontal, 24).padding(.top, 10)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    Spacer().frame(height: 10)
                    
                    VStack(spacing: 10) {
                        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() }
                            else { Image(systemName: "person.circle.fill").resizable().foregroundColor(.white.opacity(0.5)) }
                        }
                        .frame(width: 85, height: 85).clipShape(Circle()).overlay(Circle().stroke(Color.white, lineWidth: 2)).shadow(color: .white.opacity(0.2), radius: 10)
                        
                        Text("VANDUYIOS VIP\nVANDUY")
                            .font(.system(size: 20, weight: .black, design: .monospaced)).multilineTextAlignment(.center).foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            Rectangle().fill(Color.white.opacity(0.3)).frame(width: 20, height: 1)
                            Text("MOD MENU ONLINE").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                            Rectangle().fill(Color.white.opacity(0.3)).frame(width: 20, height: 1)
                        }
                    }
                    
                    // CHỈ CHỨA 2 GAME (FF Max và FF Thường)
                    VStack(spacing: 0) {
                        homeGameRow(title: "Free Fire Max", bundle: "com.dts.freefiremax", icon: "https://solitudepremium.click/ipa/proxy/free.jpg")
                        Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 20)
                        homeGameRow(title: "Free Fire", bundle: "com.dts.freefireth", icon: "https://solitudepremium.click/ipa/proxy/free.jpg")
                    }
                    .background(Color.white.opacity(0.04)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 100)
            }
            
            // Thanh Key Đáy
            HStack(spacing: 15) {
                Image(systemName: "key.horizontal").font(.system(size: 18)).foregroundColor(.white)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Key: ••••••••").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        Image(systemName: "eye").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                    }
                    Text("Thời Hạn Còn Lại: Vĩnh Viễn").font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Button(action: { AudioServicesPlaySystemSound(1306) }) {
                    Image(systemName: "square.on.square").font(.system(size: 16)).foregroundColor(.white)
                        .padding(8).background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)))
                }
            }
            .padding(16).background(Color.white.opacity(0.05)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }
    
    private func homeGameRow(title: String, bundle: String, icon: String) -> some View {
        HStack(spacing: 15) {
            AsyncImage(url: URL(string: icon)) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else { Image(systemName: "gamecontroller.fill").foregroundColor(.white.opacity(0.3)) }
            }
            .frame(width: 45, height: 45).clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Text(bundle).font(.system(size: 11, design: .monospaced)).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            
            Button(action: {
                AudioServicesPlaySystemSound(1306)
                selectedGameBundle = bundle
                if !dynamicTabs.contains(selectedTab) { selectedTab = dynamicTabs.first ?? "Aim" }
                withAnimation { showModMenu = true }
            }) {
                HStack(spacing: 4) {
                    Text("OPEN").font(.system(size: 11, weight: .black))
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .black))
                }
                .foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.white.opacity(0.1)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(16)
    }
    
    // MARK: - 2. GIAO DIỆN MOD MENU BÊN TRONG
    private var modMenuScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: {
                    AudioServicesPlaySystemSound(1306)
                    withAnimation { showModMenu = false }
                }) {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        .frame(width: 40, height: 40).background(Circle().fill(Color.white.opacity(0.08)))
                }
                
                AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/free.jpg")) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                }.frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedGameBundle == "com.dts.freefiremax" ? "Free Fire Max" : "Free Fire").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    Text(selectedGameBundle).font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Button(action: fetchRemoteData) {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.white).padding(8).background(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }.disabled(isFetching)
            }
            .padding(.horizontal, 20).padding(.top, 15)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(dynamicTabs, id: \.self) { tab in
                        Button(action: { AudioServicesPlaySystemSound(1306); selectedTab = tab }) {
                            Text(tab)
                                .font(.system(size: 13, weight: .bold, design: .monospaced)).padding(.horizontal, 20).padding(.vertical, 10)
                                .background(selectedTab.lowercased() == tab.lowercased() ? Color.white : Color.white.opacity(0.05))
                                .foregroundColor(selectedTab.lowercased() == tab.lowercased() ? .black : .white)
                                .cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    let filtered = remoteItems.filter { $0.target == selectedGameBundle && $0.category.lowercased() == selectedTab.lowercased() }
                    if filtered.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.badge.questionmark").font(.system(size: 40)).foregroundColor(.white.opacity(0.2))
                            Text("Chưa có chức năng nào").font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
                        }.padding(.top, 80)
                    } else {
                        ForEach(filtered) { item in
                            ModFunctionRow(remoteItem: item, store: store)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 90)
            }
            Spacer()
            
            Button(action: { AudioServicesPlaySystemSound(1306) }) {
                HStack {
                    Image(systemName: "play.fill").font(.system(size: 12))
                    Text("VÀO GAME NGAY (\(selectedGameBundle == "com.dts.freefiremax" ? "FF Max" : "FF Thường"))")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                }
                .foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(Color.white).cornerRadius(25).shadow(color: .white.opacity(0.3), radius: 8)
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }
    
    // MARK: - DỮ LIỆU ĐỘNG TỪ WEB
    private var dynamicTabs: [String] {
        var tabs = ["Aim", "Guns", "Chams", "Outfits"]
        for item in remoteItems where item.target == selectedGameBundle {
            if !tabs.contains(where: { $0.caseInsensitiveCompare(item.category) == .orderedSame }) { tabs.append(item.category) }
        }
        return tabs
    }
    
    private func fetchRemoteData() {
        guard !isFetching else { return }
        isFetching = true
        guard let url = URL(string: "https://solitudepremium.click/ipa/proxy/4329.php?api=1") else { isFetching = false; return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            defer { DispatchQueue.main.async { self.isFetching = false } }
            guard let data = data else { return }
            if let decoded = try? JSONDecoder().decode([RemoteAimItem].self, from: data) {
                DispatchQueue.main.async { self.remoteItems = decoded }
            }
        }.resume()
    }
}

// MARK: - HÀNG CHỨC NĂNG (CÓ CHỨC NĂNG TẢI NGẦM TRÁNH LỖI)
struct ModFunctionRow: View {
    let remoteItem: RemoteAimItem
    @ObservedObject var store: PatchProjectStore
    
    @State private var localItem: PatchLibraryItem?
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
                    Text("VIP").font(.system(size: 8, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.white.opacity(0.15)).cornerRadius(4).foregroundColor(.white)
                }
                Text("cache").font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            
            if isWorking {
                ProgressView().tint(.white).scaleEffect(0.7)
            } else {
                Toggle("", isOn: Binding(get: { isApplied }, set: { val in togglePatch(on: val) }))
                    .labelsHidden().tint(.green)
            }
        }
        .padding(12).background(Color.white.opacity(0.04)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .onAppear(perform: checkStatus)
    }
    
    private func checkStatus() {
        if let savedId = UserDefaults.standard.string(forKey: "mod_\(remoteItem.id)"),
           let match = store.items.first(where: { $0.id.uuidString == savedId }) {
            self.localItem = match
        }
        if let local = localItem {
            isApplied = DevicePatchService.latestReceipt(projectID: local.id) != nil
        }
    }
    
    private func togglePatch(on: Bool) {
        guard !isWorking else { return }
        isWorking = true
        AudioServicesPlaySystemSound(1306)
        
        Task.detached(priority: .userInitiated) {
            do {
                var targetItem = await MainActor.run { self.localItem }
                
                if on {
                    // Nếu chưa cài (chưa gạt lần nào), App tự động tải file zip về máy và giải nén
                    if targetItem == nil {
                        guard let url = URL(string: remoteItem.url) else { throw NSError(domain: "URL", code: 0) }
                        let data = try Data(contentsOf: url)
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(remoteItem.id).3105")
                        try data.write(to: tempURL)
                        
                        let beforeIds = await MainActor.run { store.items.map { $0.id } }
                        await MainActor.run { store.importPackage(at: tempURL) }
                        try await Task.sleep(nanoseconds: 1_500_000_000) // Đợi 1.5s để import xong
                        
                        targetItem = await MainActor.run { store.items.first { !beforeIds.contains($0.id) } }
                        if let newLocal = targetItem {
                            await MainActor.run {
                                self.localItem = newLocal
                                UserDefaults.standard.set(newLocal.id.uuidString, forKey: "mod_\(remoteItem.id)")
                            }
                        } else {
                            throw NSError(domain: "ImportFail", code: 0)
                        }
                    }
                    
                    guard let local = targetItem, let base = local.project else { throw NSError(domain: "Proj", code: 0) }
                    let proj = local.summary.schemaVersion >= 2 && local.canInspectContents ? try PatchProjectLibrary.synchronizeWorkspace(item: local) : base
                    _ = try DevicePatchService.apply(project: proj)
                    
                    await MainActor.run { self.isApplied = true; self.isWorking = false; AudioServicesPlaySystemSound(1407) }
                } else {
                    if let local = targetItem, let receipt = DevicePatchService.latestReceipt(projectID: local.id) {
                        try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                    }
                    await MainActor.run { self.isApplied = false; self.isWorking = false; AudioServicesPlaySystemSound(1407) }
                }
            } catch {
                await MainActor.run { self.isApplied = !on; self.isWorking = false; AudioServicesPlaySystemSound(1053) }
            }
        }
    }
}

struct RemoteAimItem: Codable, Identifiable {
    let id, name, category, target, url: String
}

private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore
    func body(content: Content) -> some View { content }
}
extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View { modifier(PatchStorePresentationModifier(store: store)) }
}
