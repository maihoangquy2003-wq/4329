import SwiftUI
import UIKit
import AudioToolbox
import MachO
import Security
import Combine

// MARK: - CUSTOM IMAGE LOADER
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = true
    
    func load(urlStr: String) {
        guard let url = URL(string: urlStr) else { isLoading = false; return }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let data = data, let uiImage = UIImage(data: data) {
                    self.image = uiImage
                }
            }
        }.resume()
    }
}

struct CachedImageView: View {
    @StateObject private var loader = ImageLoader()
    let url: String
    let fallbackIcon: String
    
    var body: some View {
        ZStack {
            if let img = loader.image {
                Image(uiImage: img).resizable().scaledToFill()
            } else if loader.isLoading {
                ProgressView().tint(.white).scaleEffect(0.8)
            } else {
                Image(systemName: fallbackIcon).font(.title).foregroundColor(.white.opacity(0.5))
            }
        }
        .onAppear { loader.load(urlStr: url) }
    }
}

// MARK: - KEYCHAIN DEVICE ID MANAGER
struct DeviceIDManager {
    static let shared = DeviceIDManager()
    private let account = "solitude_secure_hwid"
    
    func getID() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data,
           let id = String(data: data, encoding: .utf8) {
            return id
        }
        
        let newID = "APEX-ZENITH-SOLITUDE-\(UUID().uuidString.prefix(8).uppercased())"
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: newID.data(using: .utf8)!
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
        return newID
    }
}

// MARK: - SYSTEM SECURITY GUARD
struct SecurityGuard {
    static var isCompromised: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return checkDebugger() || checkJailbreak() || checkInjectedDylibs()
        #endif
    }
    private static func checkDebugger() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        return (junk == 0 && (info.kp_proc.p_flag & P_TRACED) != 0)
    }
    private static func checkJailbreak() -> Bool {
        let paths = ["/Applications/Cydia.app", "/Library/MobileSubstrate/MobileSubstrate.dylib", "/bin/bash"]
        for path in paths { if FileManager.default.fileExists(atPath: path) { return true } }
        return false
    }
    private static func checkInjectedDylibs() -> Bool {
        let suspicious = ["frida", "cydia", "mobilesubstrate", "cycript"]
        let count = _dyld_image_count()
        for i in 0..<count {
            if let name = _dyld_get_image_name(i) {
                let dylibName = String(cString: name).lowercased()
                for sus in suspicious { if dylibName.contains(sus) { return true } }
            }
        }
        return false
    }
}

// MARK: - SOUND & HAPTIC MANAGER
struct UXFeedback {
    static func click() { AudioServicesPlaySystemSound(1306); UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { AudioServicesPlaySystemSound(1407); UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { AudioServicesPlaySystemSound(1053); UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func typing() { AudioServicesPlaySystemSound(1057); UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
}

// MARK: - MAIN CONTENT VIEW
struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey) private var developerModeEnabled = false
     
    @AppStorage("solitude_is_unlocked") private var isUnlocked = false
    @AppStorage("solitude_key_expiry") private var keyExpiryDate: String = ""
    @AppStorage("solitude_active_key") private var activeKey: String = ""
    @AppStorage("mini_app_enabled") private var miniAppEnabled = false
    
    @State private var deviceID: String = DeviceIDManager.shared.getID()
    @State private var tabNavigation: AppTabNavigationState
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var securityBreach = false
    
    @State private var isMaintenance = false
    @State private var maintenanceMessage = ""
    @State private var timer: AnyCancellable?

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int = arguments.contains("--simulate-new-tab") ? 1 : 0
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
        if arguments.contains("--bypass-lock") { _isUnlocked = AppStorage(wrappedValue: true, "solitude_is_unlocked") }
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        ZStack {
            Group {
                if securityBreach {
                    SecurityLockdownView()
                } else if isMaintenance {
                    MaintenanceLockdownView(message: maintenanceMessage)
                } else if isUnlocked && !isKeyExpiredLocally() {
                    mainAppContent
                        .overlay(KeyTimerFloatingWidget(expiryDate: keyExpiryDate), alignment: .bottom)
                } else {
                    KeyLockView(isUnlocked: $isUnlocked, savedExpiry: $keyExpiryDate, activeKey: $activeKey, deviceID: deviceID)
                }
            }
            
            // Nút nổi Mini App toàn cục chứa giao diện Headlock trực tiếp
            if miniAppEnabled && isUnlocked && !isMaintenance && !securityBreach {
                FloatingHeadlockOverlayView(onOpenSettings: openSettings, onOpenLogs: openLogs)
            }
        }
        .onAppear {
            if SecurityGuard.isCompromised { securityBreach = true }
            checkServerStatusAndKey()
            startContinuousValidation()
        }
        .onDisappear {
            timer?.cancel()
        }
    }

    private func forceLogoutClean() {
        isUnlocked = false
        keyExpiryDate = ""
        activeKey = ""
    }

    private func checkServerStatusAndKey() {
        if keyExpiryDate.isEmpty || activeKey.isEmpty || isKeyExpiredLocally() {
            forceLogoutClean()
            return
        }
        checkMaintenanceAndKeyAPI()
    }

    private func startContinuousValidation() {
        timer?.cancel()
        timer = Timer.publish(every: 4.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                checkMaintenanceAndKeyAPI()
            }
    }

    private func checkMaintenanceAndKeyAPI() {
        let group = DispatchGroup()
        
        group.enter()
        let maintURL = URL(string: "https://solitudepremium.click/ipa/proxy/apibaotri.php")!
        URLSession.shared.dataTask(with: maintURL) { data, _, _ in
            defer { group.leave() }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DispatchQueue.main.async {
                    if let maint = json["maintenance"] as? Bool, maint {
                        isMaintenance = true
                        maintenanceMessage = json["message"] as? String ?? "Hệ thống đang bảo trì."
                    } else {
                        isMaintenance = false
                    }
                }
            }
        }.resume()
        
        if isUnlocked && !activeKey.isEmpty {
            group.enter()
            let endpoint = URL(string: "https://solitudepremium.click/ipa/proxy/api.php")!
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = "action=verify_app_key&key=\(activeKey)&device_id=\(deviceID)".data(using: .utf8)

            URLSession.shared.dataTask(with: request) { data, _, _ in
                defer { group.leave() }
                guard let data = data else { return }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String {
                    DispatchQueue.main.async {
                        if status != "success" {
                            forceLogoutClean()
                        } else if let newExpiry = json["expires_at"] as? String {
                            keyExpiryDate = newExpiry
                        }
                    }
                }
            }.resume()
        }
    }

    private var mainAppContent: some View {
        Group { if horizontalSizeClass == .regular { regularLayout } else { compactLayout } }
            .tint(AppTheme.accent)
            .imageScale(.small)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLogs) { LogView() }
            .patchStorePresentation(patchStore)
            .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections.filter { $0 == .home || $0 == .installed }) { section in
                sectionContent(section).tabItem { CompactTabLabel(title: section == .installed ? "HEADLOCK" : language.text(section.titleKey), systemImage: section.systemImage) }.tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections.filter { $0 == .home || $0 == .installed }) { section in
                    Button { withAnimation(.easeInOut(duration: 0.18)) { tabNavigation.select(section.rawValue) } } label: {
                        Label(section == .installed ? "HEADLOCK" : language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.navigationTitle("HEADLOCK")
        } detail: { sectionContent(selectedVisibleSection) }
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home: CustomZenithHomeView(onOpenSettings: openSettings, onOpenProfile: openLogs, onOpenApp: {
            tabNavigation.select(AppSection.installed.rawValue)
        })
        case .installed: PatchProjectsView(onOpenSettings: openSettings, onOpenLogs: openLogs)
        case .files: AppDataBrowserView(tabSession: filesTabSession, onOpenSettings: openSettings, onOpenLogs: openLogs)
        default: EmptyView()
        }
    }

    private var tabSelection: Binding<Int> { Binding(get: { tabNavigation.selectedTab }, set: { tabNavigation.select($0) }) }
    private var filesTabSession: Binding<FilesTabSession> { Binding(get: { tabNavigation.filesTabs }, set: { tabNavigation.setFilesTabs($0) }) }
    private var featureVisibility: FeatureVisibility { FeatureVisibility(developerModeEnabled: developerModeEnabled) }
    private var selectedVisibleSection: AppSection { AppSection(rawValue: tabNavigation.selectedTab) ?? .home }
    private func openSettings() { showSettings = true }
    private func openLogs() { showLogs = true }
    
    private func isKeyExpiredLocally() -> Bool {
        guard !keyExpiryDate.isEmpty else { return true }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        if let expDate = formatter.date(from: keyExpiryDate) { return Date() > expDate }
        return true
    }
}

// MARK: - NÚT NỔI HIỂN THỊ MỤC HEADLOCK TRỰC TIẾP
struct FloatingHeadlockOverlayView: View {
    var onOpenSettings: () -> Void
    var onOpenLogs: () -> Void
    
    @State private var showMenu = false
    @State private var offset = CGSize(width: 120, height: 220)
    @State private var rotationAngle: Double = 0.0

    var body: some View {
        ZStack {
            if showMenu {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeInOut) { showMenu = false } }
                
                // Cửa sổ nổi chứa nội dung chức năng của HEADLOCK để chọn lựa
                VStack(spacing: 0) {
                    HStack {
                        Label("HEADLOCK CONTROL", systemImage: "tray.full.fill")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { withAnimation { showMenu = false } }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.white).font(.system(size: 18))
                        }
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.9))
                    
                    Divider().background(Color.white.opacity(0.3))
                    
                    // Nhúng trực tiếp giao diện PatchProjectsView (chức năng của tab Headlock) vào ô nổi
                    PatchProjectsView(onOpenSettings: onOpenSettings, onOpenLogs: onOpenLogs)
                        .frame(height: 340)
                }
                .frame(width: 330)
                .background(Color.black.opacity(0.95))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.5), lineWidth: 1.5).shadow(color: .white, radius: 10))
                .shadow(radius: 20)
                .zIndex(100)
            }

            // Nút tròn nổi kéo thả mượt mà kèm avatar xoay vòng
            Button(action: {
                UXFeedback.click()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showMenu.toggle() }
            }) {
                ZStack {
                    Circle()
                        .stroke(AngularGradient(gradient: Gradient(colors: [.clear, .white, .clear]), center: .center), lineWidth: 2.5)
                        .frame(width: 62, height: 62)
                        .rotationEffect(.degrees(rotationAngle))
                        .onAppear { withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { rotationAngle = 360 } }
                    
                    CachedImageView(url: "https://solitudepremium.click/ipa/proxy/li.jpg", fallbackIcon: "person.circle.fill")
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .shadow(color: .white.opacity(0.8), radius: 6)
                }
            }
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                    }
            )
            .animation(.interactiveSpring(), value: offset)
        }
        .ignoresSafeArea()
    }
}

// MARK: - GIAO DIỆN TRANG CHỦ CUSTOM
struct CustomZenithHomeView: View {
    var onOpenSettings: () -> Void
    var onOpenProfile: () -> Void
    var onOpenApp: () -> Void
    
    @AppStorage("has_scanned_mhac2") private var hasScanned = false
    @AppStorage("mini_app_enabled") private var miniAppEnabled = false
    
    @State private var isScanning = false
    @State private var scanStatus = "Workspace 3105"
    @State private var scanSubtext = "Đang khởi tạo tệp hệ thống..."
    @State private var avatarRotationAngle: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ParticleCanvasView()
            
            if isScanning {
                VStack(spacing: 25) {
                    ProgressView().tint(.white).scaleEffect(1.5).shadow(color: .white, radius: 5)
                    VStack(spacing: 8) {
                        Text(scanStatus).font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(.white)
                        Text(scanSubtext).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { scanStatus = "Đang quét MHA-C2..."; scanSubtext = "Tìm kiếm dữ liệu ứng dụng..." }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { scanStatus = "Hoàn tất!"; scanSubtext = "Đã tìm thấy: com.dts.freefireth" }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            hasScanned = true
                            isScanning = false
                        }
                    }
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        Spacer().frame(height: 10)
                        
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(AngularGradient(gradient: Gradient(colors: [.clear, .white, .clear]), center: .center), lineWidth: 3)
                                    .frame(width: 102, height: 102)
                                    .rotationEffect(.degrees(avatarRotationAngle))
                                    .onAppear { withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { avatarRotationAngle = 360 } }
                                    .shadow(color: .white, radius: 6)
                                
                                CachedImageView(url: "https://solitudepremium.click/ipa/proxy/li.jpg", fallbackIcon: "person.circle.fill")
                                    .frame(width: 90, height: 90)
                                    .clipShape(Circle())
                            }
                            
                            Text("ZENITH SOLITUDE")
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                                .shadow(color: .white, radius: 5)
                            
                            HStack {
                                Circle().frame(width: 3, height: 3).foregroundColor(.white)
                                Text("HEADLOCK ZENIS")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                Circle().frame(width: 3, height: 3).foregroundColor(.white)
                            }
                        }
                        
                        VStack(spacing: 0) {
                            AppListItemView(
                                title: "Free Fire",
                                bundle: "com.dts.freefireth",
                                imageUrl: "https://solitudepremium.click/ipa/proxy/free.jpg",
                                onOpen: onOpenApp
                            )
                            
                            Divider().background(Color.white.opacity(0.2)).padding(.horizontal, 16)
                            
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(miniAppEnabled ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: miniAppEnabled ? "pip.fill" : "pip")
                                        .foregroundColor(miniAppEnabled ? .green : .white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Chế Độ Mini App").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                    Text(miniAppEnabled ? "Hiển thị nút nổi ngoài màn hình" : "Bật để tạo nút nổi thu nhỏ")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(miniAppEnabled ? .green : .white.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $miniAppEnabled)
                                    .labelsHidden()
                                    .tint(.green)
                                    .onChange(of: miniAppEnabled) { _ in UXFeedback.click() }
                            }
                            .padding(16)
                        }
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal, 20)
                        
                        Text("Headlock Center by Zenith Solitude")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .shadow(color: .white, radius: 2)
                            .padding(.top, 5)
                    }
                    .padding(.bottom, 120)
                }
            }
        }
        .onAppear { if !hasScanned { isScanning = true } }
    }
}

// MARK: - APP ITEM VIEW
struct AppListItemView: View {
    let title: String
    let bundle: String
    let imageUrl: String
    let onOpen: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            CachedImageView(url: imageUrl, fallbackIcon: "flame.fill")
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                Text(bundle).font(.system(size: 11, design: .monospaced)).foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Button(action: {
                UXFeedback.click()
                onOpen()
            }) {
                HStack(spacing: 4) {
                    Text("OPEN").font(.system(size: 12, weight: .bold, design: .monospaced))
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(16)
    }
}

// MARK: - MÀN HÌNH KHÓA KEY
private struct KeyLockView: View {
    @Binding var isUnlocked: Bool
    @Binding var savedExpiry: String
    @Binding var activeKey: String
    var deviceID: String
    
    @State private var keyCode: String = ""
    @State private var isKeyVisible: Bool = false
    @State private var isLoading: Bool = false
    @State private var isFinding: Bool = false
    @State private var inlineErrorMsg: String? = nil
    @State private var isSuccessMsg: Bool = false
    @State private var shakeOffset: CGFloat = 0
    @State private var rotationAngle: Double = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ParticleCanvasView()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    headerSection
                    controlPanelSection
                    footerSection
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isUnlocked = false
            savedExpiry = ""
            activeKey = ""
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(AngularGradient(gradient: Gradient(colors: [.clear, .white, .clear]), center: .center), lineWidth: 2.5)
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear { withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { rotationAngle = 360 } }
                    .shadow(color: .white, radius: 10)
                
                CachedImageView(url: "https://solitudepremium.click/ipa/proxy/li.jpg", fallbackIcon: "person.circle.fill")
                    .frame(width: 94, height: 94)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2).shadow(color: .white, radius: 5))
            }
            .padding(.top, 40)
            
            Text("ZENITH SOLITUDE")
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .tracking(6)
                .foregroundColor(.white)
                .shadow(color: .white, radius: 15)
        }
    }
    
    private var controlPanelSection: some View {
        VStack(spacing: 18) {
            hwidSection
            
            Text("Headlock Version 4.3.29")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .shadow(color: .white, radius: 8)
            
            inputFormSection
            actionButtonsSection
        }
        .padding(20)
        .background(Color.black.opacity(0.8))
        .cornerRadius(28)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.6), lineWidth: 1.5).shadow(color: .white.opacity(0.5), radius: 10))
        .shadow(color: .white.opacity(0.15), radius: 30, x: 0, y: 10)
        .padding(.horizontal, 16)
    }
    
    private var hwidSection: some View {
        HStack {
            Image(systemName: "cpu").foregroundColor(.white).font(.system(size: 11)).shadow(color: .white, radius: 5)
            Text("HWID: \(deviceID)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.5), radius: 2)
                .lineLimit(1)
            
            Spacer()
            
            if isFinding || isLoading {
                ProgressView().scaleEffect(0.7).tint(.white)
            } else {
                Button(action: {
                    UXFeedback.click()
                    findKeyByDeviceID()
                }) {
                    Text("TÌM KEY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white)
                        .cornerRadius(4)
                        .shadow(color: .white, radius: 4)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var inputFormSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)).frame(width: 42, height: 42)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.5), lineWidth: 1))
                    Image(systemName: "key.horizontal.fill").font(.system(size: 16)).foregroundColor(.white).rotationEffect(.degrees(-45)).shadow(color: .white, radius: 5)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Key:").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white).shadow(color: .white, radius: 2)
                        Group {
                            if isKeyVisible { TextField("Nhập Key...", text: $keyCode) }
                            else { SecureField("••••••••••••", text: $keyCode) }
                        }
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .onChange(of: keyCode) { _ in UXFeedback.typing() } 
                        
                        Button(action: { UXFeedback.click(); isKeyVisible.toggle() }) {
                            Image(systemName: isKeyVisible ? "eye.slash.fill" : "eye.fill").foregroundColor(.white).font(.system(size: 13)).shadow(color: .white, radius: 3)
                        }
                    }
                    .padding(.vertical, 8).padding(.horizontal, 12).background(Color.black.opacity(0.9)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1.5).shadow(color: .white, radius: 5))
                    
                    if let error = inlineErrorMsg {
                        Text(error)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(isSuccessMsg ? .green : .red)
                            .shadow(color: isSuccessMsg ? .green : .red, radius: 5)
                    } else {
                        Text("Trạng thái: Chờ xác thực mã...").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Button(action: {
                    UXFeedback.click()
                    if let pasted = UIPasteboard.general.string { keyCode = pasted.trimmingCharacters(in: .whitespacesAndNewlines) }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)).frame(width: 42, height: 42)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.5), lineWidth: 1))
                        Image(systemName: "doc.on.clipboard").font(.system(size: 15)).foregroundColor(.white).shadow(color: .white, radius: 5)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.6))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.4), lineWidth: 1.5).shadow(color: .white.opacity(0.5), radius: 8))
        .offset(x: shakeOffset)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: { UXFeedback.click(); verifyKeyWithServer() }) {
                Text("KÍCH HOẠT HỆ THỐNG")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .tracking(2).foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: .white, radius: 10)
            }.disabled(isLoading || isFinding)

            Button(action: {
                UXFeedback.click()
                if let url = URL(string: "https://solitudepremium.click/ipa/proxy/keyproxy.php") { UIApplication.shared.open(url) }
            }) {
                HStack {
                    Image(systemName: "globe.asia.australia.fill").shadow(color: .white, radius: 2)
                    Text("LẤY KEY BẢN QUYỀN MỚI").shadow(color: .white, radius: 2)
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.white).frame(maxWidth: .infinity)
                .padding(.vertical, 14).background(Color.black)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.8), lineWidth: 1.5).shadow(color: .white.opacity(0.5), radius: 5))
            }
        }
    }
    
    private var footerSection: some View {
        Text("Headlock Center By Zenith Solitude")
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundColor(.white.opacity(0.8))
            .shadow(color: .white.opacity(0.5), radius: 3)
            .padding(.top, 10)
    }

    private func findKeyByDeviceID() {
        isFinding = true; inlineErrorMsg = nil; isSuccessMsg = false
        
        let endpoint = URL(string: "https://solitudepremium.click/ipa/proxy/api.php")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "action=find_key&device_id=\(deviceID)".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                isFinding = false
                guard let data = data, error == nil else { triggerError(msg: "⚠️ Lỗi mạng!"); return }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let status = json["status"] as? String {
                        if status == "success" {
                            let foundKey = json["key"] as? String ?? ""
                            self.keyCode = foundKey
                            UXFeedback.success()
                            self.isSuccessMsg = true
                            self.inlineErrorMsg = "✅ Đã tìm thấy Key gắn với máy này!"
                        } else { triggerError(msg: "❌ " + (json["message"] as? String ?? "Không tìm thấy!")) }
                    } else { triggerError(msg: "⚠️ Phản hồi bất thường!") }
                } catch { triggerError(msg: "⚠️ Lỗi phân tích dữ liệu!") }
            }
        }.resume()
    }

    private func verifyKeyWithServer() {
        let trimmedKey = keyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { triggerError(msg: "⚠️ Vui lòng nhập mã Key!"); return }
        isLoading = true; inlineErrorMsg = nil; isSuccessMsg = false

        let endpoint = URL(string: "https://solitudepremium.click/ipa/proxy/api.php")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "action=verify_app_key&key=\(trimmedKey)&device_id=\(deviceID)".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data, error == nil else { triggerError(msg: "⚠️ Lỗi kết nối máy chủ!"); return }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let status = json["status"] as? String {
                        if status == "success" {
                            triggerSuccess(expiry: json["expires_at"] as? String ?? "", key: trimmedKey)
                        } else { triggerError(msg: "❌ " + (json["message"] as? String ?? "Key sai!")) }
                    } else { triggerError(msg: "⚠️ Phản hồi bất thường!") }
                } catch { triggerError(msg: "⚠️ Lỗi hệ thống mã hóa!") }
            }
        }.resume()
    }
    
    private func triggerError(msg: String) {
        UXFeedback.error(); isSuccessMsg = false; inlineErrorMsg = msg
        withAnimation(.spring(response: 0.2, dampingFraction: 0.2)) { shakeOffset = 10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { shakeOffset = -10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { shakeOffset = 0 }
    }
    
    private func triggerSuccess(expiry: String, key: String) {
        UXFeedback.success(); isSuccessMsg = true; inlineErrorMsg = "✅ Xác thực thành công!"
        savedExpiry = expiry
        activeKey = key
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.6)) { isUnlocked = true }
        }
    }
}

// MARK: - WIDGET THỜI GIAN THU GỌN
private struct KeyTimerFloatingWidget: View {
    let expiryDate: String
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remaining = calculateRemaining(from: expiryDate, currentDate: context.date)
            HStack(spacing: 8) {
                Image(systemName: "key.radiowaves.forward").font(.system(size: 11)).foregroundColor(.white)
                Text("Hạn: \(remaining)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.85))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.6), lineWidth: 1))
            .shadow(color: .white.opacity(0.2), radius: 5)
            .padding(.bottom, 50)
        }
    }
    private func calculateRemaining(from dateStr: String, currentDate: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"; formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        guard let expDate = formatter.date(from: dateStr) else { return "Lỗi" }
        let diff = Int(expDate.timeIntervalSince(currentDate))
        if diff <= 0 { return "Hết Hạn" }
        let days = diff / 86400, hrs = (diff % 86400) / 3600, mins = (diff % 3600) / 60
        if days > 0 { return "\(days)N \(hrs)h\(mins)p" }
        return String(format: "%02d:%02d:%02d", hrs, mins, diff % 60)
    }
}

// MARK: - MÀN HÌNH BẢO TRÌ NHẬN TỪ SERVER
private struct MaintenanceLockdownView: View {
    var message: String
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 70)).foregroundColor(.yellow).shadow(color: .yellow, radius: 15)
                Text("HỆ THỐNG BẢO TRÌ").font(.system(size: 18, weight: .black, design: .monospaced)).foregroundColor(.white)
                Text(message).font(.system(size: 12, design: .monospaced)).multilineTextAlignment(.center).foregroundColor(.white.opacity(0.8)).padding(.horizontal, 30)
            }
        }
    }
}

// MARK: - MÀN HÌNH KHÓA KHẨN CẤP
private struct SecurityLockdownView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "shield.slash.fill").font(.system(size: 80)).foregroundColor(.white).shadow(color: .white, radius: 20)
                Text("SECURITY BREACH").font(.system(size: 20, weight: .black, design: .monospaced)).foregroundColor(.white).shadow(color: .white, radius: 10)
                Text("Phát hiện phần mềm can thiệp.\nỨng dụng đã bị khóa an toàn.").font(.system(size: 12, design: .monospaced)).multilineTextAlignment(.center).foregroundColor(.white)
            }
        }
    }
}

// MARK: - HIỆU ỨNG HẠT BỤI
private struct ParticleCanvasView: View {
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { graphicsContext, size in
                let time = context.date.timeIntervalSinceReferenceDate
                for i in 0..<120 {
                    let seed = Double(i) * 99.0
                    let x = (sin(time * 0.2 + seed) * 0.5 + 0.5) * size.width
                    let speed = 150.0 + fmod(seed, 100.0) 
                    let y = size.height - fmod(time * speed + seed, size.height + 100)
                    let particleSize = CGFloat(fmod(seed, 3.0) + 2.5) 
                    let opacity = Double(fmod(seed, 0.7) + 0.3) 
                    
                    let rect = CGRect(x: x, y: y, width: particleSize, height: particleSize)
                    graphicsContext.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CompactTabLabel: View {
    let title: String; let systemImage: String
    var body: some View { Image(systemName: systemImage); Text(title) }
}
private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"; case .new: return "tab.new"; case .sources: return "tab.sources"
        case .installed: return "tab.installed"; case .files: return "tab.files"; case .search: return "tab.search"
        }
    }
    var systemImage: String {
        switch self {
        case .home: return "house.fill"; case .new: return "clock.fill"; case .sources: return "shippingbox.fill"
        case .installed: return "tray.full.fill"; case .files: return "folder.fill"; case .search: return "magnifyingglass"
        }
    }
}
