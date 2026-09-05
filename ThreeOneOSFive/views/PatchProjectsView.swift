import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

// MARK: - HIỆU ỨNG CHẠM NEON (BẤM NHÚN & PHÁT SÁNG)
struct NeonScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: configuration.isPressed ? .white.opacity(0.8) : .clear, radius: configuration.isPressed ? 10 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

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
            Spacer().frame(height: 40)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 35) {
                    
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(AngularGradient(gradient: Gradient(colors: [.clear, .white, .gray, .white, .clear]), center: .center), lineWidth: 3)
                                .frame(width: 106, height: 106)
                                .rotationEffect(.degrees(avatarRotation))
                                .shadow(color: .white.opacity(0.7), radius: 12)
                            
                            AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() }
                                else { Image(systemName: "person.circle.fill").resizable().foregroundColor(.white) }
                            }
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                        }
                        
                        VStack(spacing: 6) {
                            Text("ZENITH SOLITUDE")
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.8), radius: 6)
                            
                            HStack(spacing: 12) {
                                Rectangle().fill(LinearGradient(colors: [.clear, .white], startPoint: .leading, endPoint: .trailing)).frame(width: 30, height: 1)
                                Text("HEADLOCK ZENIS")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                Rectangle().fill(LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing)).frame(width: 30, height: 1)
                            }
                        }
                    }
                    
                    VStack(spacing: 16) {
                        homeGameCard(title: "Free Fire Max", icon: "https://solitudepremium.click/ipa/proxy/free.jpg", bundle: "com.dts.freefiremax")
                        homeGameCard(title: "Free Fire Thường", icon: "https://solitudepremium.click/ipa/proxy/free.jpg", bundle: "com.dts.freefireth")
                    }
                    .padding(.horizontal, 20)
                    
                    Text("Powered by Zenith Center")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 20)
                }
                .padding(.bottom, 60)
            }
        }
    }
    
    private func homeGameCard(title: String, icon: String, bundle: String) -> some View {
        Button(action: {
            AudioServicesPlaySystemSound(1306)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            selectedGameBundle = bundle
            if !dynamicTabs.contains(selectedTab), let first = dynamicTabs.first {
                selectedTab = first
            }
            withAnimation { showModMenu = true }
        }) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: icon)) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Image(systemName: "gamecontroller.fill").foregroundColor(.white) }
                }
                .frame(width: 55, height: 55)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.4), lineWidth: 1))
                .shadow(color: .white.opacity(0.2), radius: 5)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.5), radius: 2)
                    Text("Hệ thống sẵn sàng")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                HStack(spacing: 4) {
                    Text("MỞ").font(.system(size: 12, weight: .black, design: .monospaced))
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .black))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .white.opacity(0.4), radius: 5)
            }
            .padding(18)
            .background(Color.black)
            .cornerRadius(22)
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.3), lineWidth: 1.5))
            .shadow(color: .white.opacity(0.15), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(NeonScaleButtonStyle())
    }
    
    // MARK: - 2. GIAO DIỆN MOD MENU
    private var modMenuScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: {
                    AudioServicesPlaySystemSound(1306)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { showModMenu = false }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .white.opacity(0.5), radius: 5)
                }
                .buttonStyle(NeonScaleButtonStyle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedGameBundle == "com.dts.freefiremax" ? "Free Fire Max" : "Free Fire Thường")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.5), radius: 2)
                    Text("Workspace Active")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    fetchRemoteData()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                }
                .disabled(isFetching)
                .buttonStyle(NeonScaleButtonStyle())
            }
            .padding(.horizontal, 20).padding(.top, 15).padding(.bottom, 10)
            
            if !dynamicTabs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(dynamicTabs, id: \.self) { tab in
                            let isSelected = selectedTab.lowercased() == tab.lowercased()
                            Button(action: {
                                AudioServicesPlaySystemSound(1306)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                            }) {
                                Text(tab)
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .padding(.horizontal, 22).padding(.vertical, 12)
                                    .background(isSelected ? Color.white : Color.black)
                                    .foregroundColor(isSelected ? .black : .white)
                                    .cornerRadius(20)
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(isSelected ? 1.0 : 0.3), lineWidth: 1.5))
                                    .shadow(color: isSelected ? .white.opacity(0.6) : .clear, radius: 8)
                            }
                            .buttonStyle(NeonScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16)
                }
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    let filtered = remoteItems.filter { $0.target == selectedGameBundle && $0.category.lowercased() == selectedTab.lowercased() }
                    if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "cube.transparent").font(.system(size: 45)).foregroundColor(.white.opacity(0.3))
                            Text("Thư mục trống").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.5))
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
                    let glowRect = CGRect(x: x - 1, y: y - 1, width: 4, height: 4)
                    let rect = CGRect(x: x, y: y, width: 2, height: 2)
                    
                    ctx.fill(Path(ellipseIn: glowRect), with: .color(.white.opacity(0.15)))
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.6)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - HÀNG CHỨC NĂNG (ĐÃ SỬA LỖI KIỂU DỮ LIỆU SWIFT)
struct ModFunctionRow: View {
    let remoteItem: RemoteAimItem
    @ObservedObject var store: PatchProjectStore
    
    @State private var localItem: PatchLibraryItem?
    @State private var isApplied = false
    @State private var isWorking = false
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isApplied ? Color.white : Color.white.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: isApplied ? "checkmark.shield.fill" : "shield.fill")
                    .foregroundColor(isApplied ? .black : .white.opacity(0.7))
                    .font(.system(size: 18))
            }
            .shadow(color: isApplied ? .white.opacity(0.6) : .clear, radius: 5)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(remoteItem.name)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(isApplied ? .white : .white.opacity(0.9))
                        .shadow(color: isApplied ? .white.opacity(0.5) : .clear, radius: 2)
                    
                    Text("VIP")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(isApplied ? Color.white : Color.white.opacity(0.2))
                        .cornerRadius(6)
                        .foregroundColor(isApplied ? .black : .white)
                }
                
                if let note = remoteItem.note, !note.isEmpty {
                    Text("📌 \(note)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(isApplied ? .white.opacity(0.8) : .gray)
                }
            }
            Spacer()
            
            if isWorking {
                ProgressView().tint(.white).scaleEffect(0.8).padding(.trailing, 5)
            } else {
                Toggle("", isOn: Binding(get: { isApplied }, set: { val in togglePatch(on: val) }))
                    .labelsHidden()
                    .tint(.white)
            }
        }
        .padding(14)
        .background(Color(white: 0.04))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(isApplied ? Color.white : Color.white.opacity(0.2), lineWidth: isApplied ? 1.5 : 1))
        .shadow(color: isApplied ? .white.opacity(0.25) : .clear, radius: 10)
        .onAppear(perform: checkStatus)
        .onChange(of: store.items.count) { _ in checkStatus() }
    }
    
    private func checkStatus() {
        if let savedId = UserDefaults.standard.string(forKey: "mod_\(remoteItem.id)") {
            if let match = store.items.first(where: { $0.id.uuidString == savedId }) {
                self.localItem = match
            }
        }
        if self.localItem == nil {
            if let match = store.items.first(where: { $0.summary.displayName == remoteItem.name }) {
                self.localItem = match
                UserDefaults.standard.set(match.id.uuidString, forKey: "mod_\(remoteItem.id)")
            }
        }
        
        if let local = localItem {
            isApplied = DevicePatchService.latestReceipt(projectID: local.id) != nil
        } else {
            isApplied = false
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
                    
                    await MainActor.run { 
                        withAnimation(.easeInOut(duration: 0.3)) { self.isApplied = true }
                        self.isWorking = false
                        AudioServicesPlaySystemSound(1407) 
                    }
                } else {
                    if let local = targetItem, let receipt = DevicePatchService.latestReceipt(projectID: local.id) {
                        try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                    }
                    await MainActor.run { 
                        withAnimation(.easeInOut(duration: 0.3)) { self.isApplied = false }
                        self.isWorking = false
                        AudioServicesPlaySystemSound(1407) 
                    }
                }
            } catch {
                await MainActor.run { 
                    self.isApplied = !on
                    self.isWorking = false
                    AudioServicesPlaySystemSound(1053) 
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
