import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var store: PatchProjectStore
    
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void
    
    @State private var showModMenu = false
    @AppStorage("selected_game_bundle") private var selectedGameBundle: String = "com.dts.freefiremax"
    
    @State private var remoteItems: [RemoteAimItem] = []
    @State private var selectedTab: String = ""
    @State private var isFetching = false
    @State private var avatarRotation: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            NeonParticleBackgroundView()
            
            if !showModMenu {
                homeScreen.transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                modMenuScreen.transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showModMenu)
        .onAppear {
            fetchRemoteData()
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                avatarRotation = 360
            }
        }
    }
    
    // MARK: - 1. TRANG CHỦ
    private var homeScreen: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(AngularGradient(gradient: Gradient(colors: [.white, .gray, .black, .white]), center: .center), lineWidth: 3)
                                .frame(width: 98, height: 98)
                                .rotationEffect(.degrees(avatarRotation))
                                .shadow(color: .white.opacity(0.4), radius: 8)
                            
                            AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() }
                                else { Image(systemName: "person.circle.fill").resizable().foregroundColor(.white) }
                            }
                            .frame(width: 86, height: 86)
                            .clipShape(Circle())
                        }
                        
                        Text("Zenith Solitude")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.6), radius: 5)
                        
                        HStack(spacing: 8) {
                            Rectangle().fill(LinearGradient(colors: [.clear, .white], startPoint: .leading, endPoint: .trailing)).frame(width: 25, height: 1)
                            Text("HEADLOCK ZENIS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Rectangle().fill(LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing)).frame(width: 25, height: 1)
                        }
                    }
                    
                    VStack(spacing: 14) {
                        homeGameCard(title: "Free Fire Max", icon: "https://solitudepremium.click/ipa/proxy/free.jpg", bundle: "com.dts.freefiremax")
                        homeGameCard(title: "Free Fire Thường", icon: "https://solitudepremium.click/ipa/proxy/free.jpg", bundle: "com.dts.freefireth")
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            
            HStack(spacing: 15) {
                Image(systemName: "key.horizontal").font(.system(size: 18)).foregroundColor(.white)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Key: ••••••••").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    Text("Trạng thái: Hoạt động vĩnh viễn").font(.system(size: 10)).foregroundColor(.gray)
                }
                Spacer()
                Button(action: {
                    AudioServicesPlaySystemSound(1306)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: "square.on.square").font(.system(size: 15)).foregroundColor(.white)
                        .padding(8).background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15)))
                }
            }
            .padding(16).background(Color.black).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }
    
    private func homeGameCard(title: String, icon: String, bundle: String) -> some View {
        HStack(spacing: 15) {
            AsyncImage(url: URL(string: icon)) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else { Image(systemName: "gamecontroller.fill").foregroundColor(.white) }
            }
            .frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                Text("Hệ thống sẵn sàng").font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
            }
            Spacer()
            
            Button(action: {
                AudioServicesPlaySystemSound(1306)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                selectedGameBundle = bundle
                if !dynamicTabs.contains(selectedTab), let first = dynamicTabs.first {
                    selectedTab = first
                }
                withAnimation { showModMenu = true }
            }) {
                HStack(spacing: 6) {
                    Text("MỞ MENU").font(.system(size: 11, weight: .black, design: .monospaced))
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.black).padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.white).cornerRadius(16)
                .shadow(color: .white.opacity(0.4), radius: 6)
            }
        }
        .padding(16)
        .background(Color.black)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
    
    // MARK: - 2. GIAO DIỆN MOD MENU
    private var modMenuScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: {
                    AudioServicesPlaySystemSound(1306)
                    withAnimation { showModMenu = false }
                }) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        .frame(width: 38, height: 38).background(Circle().fill(Color.white.opacity(0.1)))
                }
                
                Text(selectedGameBundle == "com.dts.freefiremax" ? "Free Fire Max" : "Free Fire Thường")
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                
                Spacer()
                
                Button(action: fetchRemoteData) {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.white).padding(8)
                        .background(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }.disabled(isFetching)
            }
            .padding(.horizontal, 20).padding(.top, 15)
            
            // Chỉ hiển thị thanh thư mục nào có dữ liệu thực tế
            if !dynamicTabs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(dynamicTabs, id: \.self) { tab in
                            Button(action: {
                                AudioServicesPlaySystemSound(1306)
                                selectedTab = tab
                            }) {
                                Text(tab)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(selectedTab.lowercased() == tab.lowercased() ? Color.white : Color.black)
                                    .foregroundColor(selectedTab.lowercased() == tab.lowercased() ? .black : .white)
                                    .cornerRadius(20)
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.4), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16)
                }
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    let filtered = remoteItems.filter { $0.target == selectedGameBundle && $0.category.lowercased() == selectedTab.lowercased() }
                    if filtered.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.badge.questionmark").font(.system(size: 40)).foregroundColor(.white.opacity(0.2))
                            Text("Chưa có tính năng nào trong mục này").font(.system(size: 12)).foregroundColor(.gray)
                        }.padding(.top, 100)
                    } else {
                        ForEach(filtered) { item in
                            ModFunctionRow(remoteItem: item, store: store)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 40)
            }
            Spacer()
        }
    }
    
    // Tự động quét chỉ hiển thị các thư mục có chứa dữ liệu tương ứng với game đang chọn
    private var dynamicTabs: [String] {
        var tabs: [String] = []
        for item in remoteItems where item.target == selectedGameBundle {
            if !tabs.contains(where: { $0.caseInsensitiveCompare(item.category) == .orderedSame }) {
                tabs.append(item.category)
            }
        }
        return tabs
    }
    
    private func fetchRemoteData() {
        guard !isFetching else { return }
        isFetching = true
        // Gọi qua file apiaim.php trung gian bảo mật
        guard let url = URL(string: "https://solitudepremium.click/ipa/proxy/apiaim.php") else { isFetching = false; return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            defer { DispatchQueue.main.async { self.isFetching = false } }
            guard let data = data else { return }
            if let decoded = try? JSONDecoder().decode([RemoteAimItem].self, from: data) {
                DispatchQueue.main.async {
                    self.remoteItems = decoded
                    if !self.dynamicTabs.contains(self.selectedTab), let first = self.dynamicTabs.first {
                        self.selectedTab = first
                    }
                }
            }
        }.resume()
    }
}

struct NeonParticleBackgroundView: View {
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let time = context.date.timeIntervalSinceReferenceDate
                for i in 0..<60 {
                    let seed = Double(i) * 55.0
                    let x = (sin(time * 0.2 + seed) * 0.5 + 0.5) * size.width
                    let y = size.height - fmod(time * (50.0 + fmod(seed, 25.0)) + seed, size.height)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(0.35)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ModFunctionRow: View {
    let remoteItem: RemoteAimItem
    @ObservedObject var store: PatchProjectStore
    
    @State private var localItem: PatchLibraryItem?
    @State private var isApplied = false
    @State private var isWorking = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)).frame(width: 40, height: 40)
                Image(systemName: isApplied ? "checkmark.shield.fill" : "shield.fill")
                    .foregroundColor(isApplied ? .white : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(remoteItem.name).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    Text("VIP").font(.system(size: 8, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.white).cornerRadius(4).foregroundColor(.black)
                }
                
                if let note = remoteItem.note, !note.isEmpty {
                    Text("📌 Note: \(note)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            
            if isWorking {
                ProgressView().tint(.white).scaleEffect(0.7)
            } else {
                Toggle("", isOn: Binding(get: { isApplied }, set: { val in togglePatch(on: val) }))
                    .labelsHidden().tint(.white)
            }
        }
        .padding(12).background(Color.black).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Task.detached(priority: .userInitiated) {
            do {
                var targetItem = await MainActor.run { self.localItem }
                
                if on {
                    if targetItem == nil {
                        guard let url = URL(string: remoteItem.url) else { throw NSError(domain: "URL", code: 0) }
                        let data = try Data(contentsOf: url)
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(remoteItem.id).3105")
                        try data.write(to: tempURL)
                        
                        let beforeIds = await MainActor.run { store.items.map { $0.id } }
                        await MainActor.run { store.importPackage(at: tempURL) }
                        try await Task.sleep(nanoseconds: 1_500_000_000)
                        
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
    let id: String
    let name: String
    let category: String
    let target: String
    let note: String?
    let url: String
}

private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore
    func body(content: Content) -> some View { content }
}
extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View { modifier(PatchStorePresentationModifier(store: store)) }
}
