import SwiftUI
import UIKit
import AudioToolbox

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false
     
    @State private var isUnlocked = false
    @State private var tabNavigation: AppTabNavigationState
    @State private var showSettings = false
    @State private var showLogs = false

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int = arguments.contains("--simulate-new-tab") ? 1 : 0
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
        if arguments.contains("--bypass-lock") {
            _isUnlocked = State(initialValue: true)
        }
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if isUnlocked {
                mainAppContent
            } else {
                KeyLockView(isUnlocked: $isUnlocked)
            }
        }
    }

    private var mainAppContent: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
        .patchStorePresentation(patchStore)
        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("3105")
        } detail: {
            sectionContent(selectedVisibleSection)
        }
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home: RepositoryHomeView(onOpenSettings: openSettings, onOpenLogs: openLogs)
        case .new: RepositoryNewView(onOpenSettings: openSettings, onOpenLogs: openLogs)
        case .sources: RepositorySourcesView(onOpenSettings: openSettings, onOpenLogs: openLogs)
        case .installed: PatchProjectsView(onOpenSettings: openSettings, onOpenLogs: openLogs)
        case .files: AppDataBrowserView(tabSession: filesTabSession, onOpenSettings: openSettings, onOpenLogs: openLogs)
        case .search: RepositorySearchView(onOpenSettings: openSettings, onOpenLogs: openLogs)
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(get: { tabNavigation.selectedTab }, set: { tabNavigation.select($0) })
    }
    private var filesTabSession: Binding<FilesTabSession> {
        Binding(get: { tabNavigation.filesTabs }, set: { tabNavigation.setFilesTabs($0) })
    }
    private var featureVisibility: FeatureVisibility { FeatureVisibility(developerModeEnabled: developerModeEnabled) }
    private var selectedVisibleSection: AppSection {
        AppSection(rawValue: tabNavigation.selectedTab) ?? .home
    }
    private func openSettings() { showSettings = true }
    private func openLogs() { showLogs = true }
}

// MARK: - Màn hình Khóa & Nhập Key Bảo Mật (Phiên bản 4.3.29)
private struct KeyLockView: View {
    @Binding var isUnlocked: Bool
    @State private var keyCode: String = ""
    @State private var deviceID: String = UIDevice.current.identifierForVendor?.uuidString ?? "SECURE-DEVICE-ID"
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var rotationAngle: Double = 0.0
    @State private var scanlineOffset: CGFloat = -100

    private func playClickSound() {
        AudioServicesPlaySystemSound(1104) // Âm thanh click chuẩn hệ thống iOS
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ParticleCanvasView()
            
            // Hiệu ứng quét màn hình (Scanline)
            VStack {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(height: 80)
                    .offset(y: scanlineOffset)
                    .onAppear {
                        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                            scanlineOffset = 900
                        }
                    }
                Spacer()
            }
            .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    
                    // MARK: - AVATAR & TIÊU ĐỀ (Đã đổi đường dẫn sang ipa/proxy)
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(AngularGradient(gradient: Gradient(colors: [.clear, .white, .clear]), center: .center), lineWidth: 2.5)
                                .frame(width: 104, height: 104)
                                .rotationEffect(.degrees(rotationAngle))
                                .onAppear {
                                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                                        rotationAngle = 360
                                    }
                                }
                                .shadow(color: .white, radius: 10)
                            
                            AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView().tint(.white).frame(width: 90, height: 90)
                                case .success(let image):
                                    image.resizable().scaledToFill().frame(width: 90, height: 90).clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        .shadow(color: .white.opacity(0.6), radius: 15)
                                case .failure(_):
                                    Image(systemName: "bolt.fill").font(.system(size: 38)).foregroundColor(.white)
                                        .frame(width: 90, height: 90).background(Color.black).clipShape(Circle())
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        .padding(.top, 25)
                        
                        Text("ZENITH SOLITUDE")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .tracking(5)
                            .foregroundColor(.white)
                            .shadow(color: .white, radius: 12)
                        
                        HStack(spacing: 8) {
                            Circle().frame(width: 3, height: 3).foregroundColor(.white).shadow(color: .white, radius: 6)
                            Text("VERSION 4.3.29")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(3)
                                .foregroundColor(.white.opacity(0.8))
                            Circle().frame(width: 3, height: 3).foregroundColor(.white).shadow(color: .white, radius: 6)
                        }
                    }

                    // MARK: - KHUNG NHẬP KEY
                    VStack(spacing: 16) {
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Circle().fill(Color.white).frame(width: 6, height: 6).shadow(color: .white, radius: 6)
                                Text("SECURE AUTHENTICATION SYSTEM")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            Text("Hardware ID: \(deviceID.prefix(16))...")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 1))

                        // Ô NHẬP KEY
                        HStack(spacing: 10) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.system(size: 13))
                                .padding(.leading, 8)
                            
                            TextField("Nhập Key kích hoạt bản quyền...", text: $keyCode)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white)
                                .accentColor(.white)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                            
                            Button(action: {
                                playClickSound()
                                if let pasted = UIPasteboard.general.string {
                                    keyCode = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(8)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 4)
                        }
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.5), lineWidth: 1.5))

                        // NÚT LOGIN HỆ THỐNG
                        Button(action: {
                            playClickSound()
                            verifyKeyWithServer()
                        }) {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "arrow.right.square.fill")
                                    Text("XÁC THỰC HỆ THỐNG")
                                }
                            }
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(LinearGradient(colors: [.white, Color(white: 0.82)], startPoint: .top, endPoint: .bottom))
                            .cornerRadius(12)
                            .shadow(color: .white.opacity(0.7), radius: 15)
                        }
                        .disabled(isLoading)

                        // Nút lấy key mới
                        Button(action: {
                            playClickSound()
                            if let url = URL(string: "https://solitudepremium.click/ipa/proxy/key.php") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "key.horizontal")
                                Text("LẤY KEY BẢN QUYỀN MỚI")
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.35), lineWidth: 1))
                        }

                        Text("Solitude Core v4.3.29 • Protected License")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.top, 4)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.5), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.9), radius: 35, x: 0, y: 15)
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 30)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Trạng thái bảo mật"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    // Kết nối tới API Server PHP mới tại đường dẫn ipa/proxy/api.php
    private func verifyKeyWithServer() {
        let trimmedKey = keyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            alertMessage = "Vui lòng không để trống mã Key!"
            showAlert = true
            return
        }

        isLoading = true
        let endpoint = URL(string: "https://solitudepremium.click/ipa/proxy/api.php")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = "action=verify_app_key&key=\(trimmedKey)&device_id=\(deviceID)"
        request.httpBody = bodyParams.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data, error == nil else {
                    alertMessage = "Lỗi kết nối máy chủ bản quyền!"
                    showAlert = true
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let status = json["status"] as? String {
                        if status == "success" {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isUnlocked = true
                            }
                        } else {
                            alertMessage = json["message"] as? String ?? "Key không hợp lệ hoặc đã hết hạn!"
                            showAlert = true
                        }
                    } else {
                        alertMessage = "Phản hồi từ máy chủ không hợp lệ."
                        showAlert = true
                    }
                } catch {
                    alertMessage = "Lỗi giải mã dữ liệu an toàn."
                    showAlert = true
                }
            }
        }.resume()
    }
}

// MARK: - Hiệu ứng hạt nền
private struct ParticleCanvasView: View {
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { graphicsContext, size in
                let time = context.date.timeIntervalSinceReferenceDate
                for i in 0..<60 {
                    let seed = Double(i) * 35.0
                    let x = (sin(time * 0.3 + seed) * 0.5 + 0.5) * size.width
                    let y = size.height - fmod(seed * 18.0 + time * 30.0, size.height)
                    let particleSize = CGFloat(fmod(seed, 2.0) + 1.0)
                    let opacity = Double(fmod(seed, 0.6) + 0.2)
                    let rect = CGRect(x: x, y: y, width: particleSize, height: particleSize)
                    graphicsContext.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String
    var body: some View {
        Image(systemName: systemImage)
        Text(title)
    }
}
