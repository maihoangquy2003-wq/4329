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
                ZStack {
                    Color.white.opacity(0.05)
                    ProgressView().tint(.white).scaleEffect(0.8)
                }
            } else {
                ZStack {
                    Color.white.opacity(0.06)
                    Image(systemName: fallbackIcon).font(.title).foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .onAppear { loader.load(urlStr: url) }
    }
}

// MARK: - HAPTIC & SCALE BUTTON STYLE
struct NeonScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
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

// MARK: - LIGHT GLOW MODIFIER (thay cho NeonGlow nặng)
struct SoftGlow: ViewModifier {
    var radius: CGFloat = 4
    var opacity: Double = 0.5
    func body(content: Content) -> some View {
        content.shadow(color: Color.white.opacity(opacity), radius: radius)
    }
}

extension View {
    func softGlow(radius: CGFloat = 4, opacity: Double = 0.5) -> some View {
        modifier(SoftGlow(radius: radius, opacity: opacity))
    }
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
        let maintURL = URL(string: "https://solitudepremium.click/ipa/ipa/apibaotri.php")!
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
            let endpoint = URL(string: "https://solitudepremium.click/ipa/ipa/api.php")!
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
            .tint(.white)
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

// MARK: - FLOATING MINI APP
struct FloatingHeadlockOverlayView: View {
    var onOpenSettings: () -> Void
    var onOpenLogs: () -> Void
    
    @State private var showMenu = false
    @State private var offset = CGSize(width: 120, height: 220)
    @State private var rotationAngle: Double = 0.0

    var body: some View {
        ZStack {
            if showMenu {
                Color.black.opacity(0.7).ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeInOut) { showMenu = false } }
                
                VStack(spacing: 0) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Text("HEADLOCK CONTROL")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Button(action: { UXFeedback.click(); withAnimation { showMenu = false } }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 20))
                        }
                    }
                    .padding(14)
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    PatchProjectsView(onOpenSettings: onOpenSettings, onOpenLogs: onOpenLogs)
                        .frame(height: 340)
                }
                .frame(width: 330)
                .background(Color.black.opacity(0.96))
                .cornerRadius(18)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
                .zIndex(100)
                .transition(.scale.combined(with: .opacity))
            }

            Button(action: {
                UXFeedback.click()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showMenu.toggle() }
            }) {
                ZStack {
                    Circle()
                        .stroke(AngularGradient(gradient: Gradient(colors: [.clear, .white, .clear]), center: .center), lineWidth: 2)
                        .frame(width: 62, height: 62)
                        .rotationEffect(.degrees(rotationAngle))
                        .onAppear { withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { rotationAngle = 360 } }
                    
                    CachedImageView(url: "https://solitudepremium.click/ipa/ipa/liii.jpg", fallbackIcon: "person.circle.fill")
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.2))
                }
                .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
            }
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in offset = value.translation }
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
    
    @AppStorage("has_scanned_mhac2") private var hasScanned = true
    @State private var isScanning = false
    @State private var scanStatus = "Workspace 3105"
    @State private var scanSubtext = "Đang khởi tạo tệp hệ thống..."
    @State private var avatarRotationAngle: Double = 0.0
    @State private var titleTracking: CGFloat = 4
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Very subtle radial gradient
            RadialGradient(colors: [Color.white.opacity(0.04), .clear], center: .top, startRadius: 0, endRadius: 400)
                .ignoresSafeArea()
            
            if isScanning {
                VStack(spacing: 25) {
                    ProgressView().tint(.white).scaleEffect(1.3)
                    VStack(spacing: 8) {
                        Text(scanStatus).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        Text(scanSubtext).font(.system(size: 12, design: .monospaced)).foregroundColor(.white.opacity(0.7))
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { scanStatus = "Đang quét hệ thống..."; scanSubtext = "Tối ưu hóa dữ liệu ứng dụng..." }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { scanStatus = "Hoàn tất!"; scanSubtext = "Sẵn sàng hoạt động" }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            hasScanned = true
                            isScanning = false
                        }
                    }
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        Spacer().frame(height: 10)
                        
                        // HERO HEADER
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .stroke(AngularGradient(gradient: Gradient(colors: [.clear, .white, .clear]), center: .center), lineWidth: 2.5)
                                    .frame(width: 102, height: 102)
                                    .rotationEffect(.degrees(avatarRotationAngle))
                                    .onAppear { withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) { avatarRotationAngle = 360 } }
                                
                                CachedImageView(url: "https://solitudepremium.click/ipa/ipa/liii.jpg", fallbackIcon: "person.circle.fill")
                                    .frame(width: 88, height: 88)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.2))
                            }
                            
                            VStack(spacing: 6) {
                                Text("ZENITH SOLITUDE")
                                    .font(.system(size: 22, weight: .black, design: .monospaced))
                                    .tracking(titleTracking)
                                    .foregroundColor(.white)
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 1.0)) { titleTracking = 6 }
                                    }
                                
                                HStack(spacing: 8) {
                                    Circle().frame(width: 3, height: 3).foregroundColor(.white.opacity(0.6))
                                    Text("HEADLOCK ZENIS")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .tracking(2)
                                        .foregroundColor(.white.opacity(0.7))
                                    Circle().frame(width: 3, height: 3).foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }
                        
                        // MAIN CONTENT
                        VStack(spacing: 14) {
                            AppListItemView(
                                title: "Free Fire",
                                subtitle: "Trạng thái: Hoạt động ổn định",
                                imageUrl: "https://solitudepremium.click/ipa/ipa/free.jpg",
                                onOpen: onOpenApp
                            )
                            
                            // Section header
                            HStack(spacing: 10) {
                                Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                                Text("KẾT NỐI")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(3)
                                    .foregroundColor(.white.opacity(0.6))
                                Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 6)
                            
                            LinkBoxView(
                                icon: "network.badge.shield.half.filled",
                                title: "Tải DNS ANTIBAN",
                                subtitle: "Cài đặt cấu hình vượt tường lửa",
                                url: "https://solitudepremium.click/ipa/ipa/dns.mobileconfig"
                            )
                            
                            LinkBoxView(
                                icon: "paperplane.fill",
                                title: "Cộng Đồng Telegram",
                                subtitle: "Tham gia nhóm hỗ trợ Solitude",
                                url: "https://t.me/solitudeversion"
                            )
                            
                            LinkBoxView(
                                icon: "bubble.left.and.exclamationmark.bubble.right.fill",
                                title: "Cộng Đồng Discord",
                                subtitle: "Trao đổi & Nhận thông báo mới",
                                url: "https://discord.gg/SzSaFasQDk"
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        // FOOTER
                        VStack(spacing: 4) {
                            Text("HEADLOCK CENTER")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(2)
                                .foregroundColor(.white.opacity(0.4))
                            Text("by Zenith Solitude")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.top, 15)
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .onAppear {
            hasScanned = true
            isScanning = false
        }
    }
}

// MARK: - COMPONENT BOX LIÊN KẾT NGOÀI (đơn giản hóa)
struct LinkBoxView: View {
    let icon: String
    let title: String
    let subtitle: String
    let url: String
    
    var body: some View {
        Button(action: {
            UXFeedback.click()
            if let targetURL = URL(string: url) {
                UIApplication.shared.open(targetURL)
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(NeonScaleButtonStyle())
    }
}

// MARK: - APP ITEM VIEW (đơn giản hóa)
struct AppListItemView: View {
    let title: String
    let subtitle: String
    let imageUrl: String
    let onOpen: () -> Void
    
    var body: some View {
        Button(action: {
            UXFeedback.click()
            onOpen()
        }) {
            HStack(spacing: 14) {
                CachedImageView(url: imageUrl, fallbackIcon: "flame.fill")
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    HStack(spacing: 5) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text(subtitle)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("OPEN")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white)
                .cornerRadius(18)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(NeonScaleButtonStyle())
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
    @State private var titleTracking: CGFloat = 8

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [Color.white.opacity(0.05), .clear], center: .top, startRadius: 0, endRadius: 500)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
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
            withAnimation(.easeOut(duration: 1.0).delay(0.15)) {
                titleTracking = 6
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(AngularGradient(gradient: Gradient(colors: [.clear, .white, .clear]), center: .center), lineWidth: 2.5)
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear { withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) { rotationAngle = 360 } }
                
                CachedImageView(url: "https://solitudepremium.click/ipa/ipa/liii.jpg", fallbackIcon: "person.circle.fill")
                    .frame(width: 94, height: 94)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.2))
            }
            .padding(.top, 40)
            
            Text("ZENITH SOLITUDE")
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .tracking(titleTracking)
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                Rectangle().fill(Color.white.opacity(0.2)).frame(width: 40, height: 1)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                Rectangle().fill(Color.white.opacity(0.2)).frame(width: 40, height: 1)
            }
        }
    }
    
    private var controlPanelSection: some View {
        VStack(spacing: 18) {
            hwidSection
            
            // Version badge
            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 5, height: 5)
                Text("Headlock Version 4.3.29")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
            
            inputFormSection
            actionButtonsSection
        }
        .padding(20)
        .background(Color.white.opacity(0.04))
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
        .padding(.horizontal, 16)
    }
    
    private var hwidSection: some View {
        HStack {
            Image(systemName: "cpu")
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 11))
            Text("HWID: \(deviceID)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(1)
            
            Spacer()
            
            if isFinding || isLoading {
                ProgressView().scaleEffect(0.7).tint(.white)
            } else {
                Button(action: {
                    UXFeedback.click()
                    findKeyByDeviceID()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 8, weight: .bold))
                        Text("TÌM KEY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white)
                    .cornerRadius(6)
                }
                .buttonStyle(NeonScaleButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private var inputFormSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 42, height: 42)
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(-45))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Key:")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Group {
                            if isKeyVisible { TextField("Nhập Key...", text: $keyCode) }
                            else { SecureField("••••••••••••", text: $keyCode) }
                        }
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .onChange(of: keyCode) { _ in UXFeedback.typing() }
                        
                        Button(action: { UXFeedback.click(); isKeyVisible.toggle() }) {
                            Image(systemName: isKeyVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 13))
                        }
                    }
                    .padding(.vertical, 9).padding(.horizontal, 12)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isSuccessMsg ? Color.green : (inlineErrorMsg != nil ? Color.red : Color.white.opacity(0.4)))
                            .frame(width: 5, height: 5)
                        
                        if let error = inlineErrorMsg {
                            Text(error)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(isSuccessMsg ? .green : .red)
                        } else {
                            Text("Trạng thái: Chờ xác thực mã...")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                
                Button(action: {
                    UXFeedback.click()
                    if let pasted = UIPasteboard.general.string { keyCode = pasted.trimmingCharacters(in: .whitespacesAndNewlines) }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 42, height: 42)
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(NeonScaleButtonStyle())
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .offset(x: shakeOffset)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 10) {
            Button(action: { UXFeedback.click(); verifyKeyWithServer() }) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("KÍCH HOẠT HỆ THỐNG")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.white)
                .cornerRadius(12)
            }
            .buttonStyle(NeonScaleButtonStyle())
            .disabled(isLoading || isFinding)

            Button(action: {
                UXFeedback.click()
                if let url = URL(string: "https://solitudepremium.click/ipa/key/index.php") { UIApplication.shared.open(url) }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "globe.asia.australia.fill")
                        .foregroundColor(.white.opacity(0.9))
                    Text("LẤY KEY BẢN QUYỀN MỚI")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(NeonScaleButtonStyle())
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 3) {
            Text("Headlock Center")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.5))
            Text("by Zenith Solitude")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(.top, 10)
    }

    private func findKeyByDeviceID() {
        isFinding = true; inlineErrorMsg = nil; isSuccessMsg = false
        
        let endpoint = URL(string: "https://solitudepremium.click/ipa/ipa/api.php")!
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

        let endpoint = URL(string: "https://solitudepremium.click/ipa/ipa/api.php")!
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
            HStack(spacing: 7) {
                Image(systemName: "key.radiowaves.forward")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.85))
                Text("Hạn: \(remaining)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.85))
            .cornerRadius(16)
            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
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
    @State private var rotate: Double = 0
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(AngularGradient(gradient: Gradient(colors: [.clear, .white, .clear]), center: .center), lineWidth: 2)
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(rotate))
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 55))
                        .foregroundColor(.white)
                }
                .onAppear {
                    withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { rotate = 360 }
                }
                
                Text("HỆ THỐNG BẢO TRÌ")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 12, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 30)
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
                Image(systemName: "shield.slash.fill")
                    .font(.system(size: 65))
                    .foregroundColor(.white)
                
                Text("SECURITY BREACH")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(.white)
                
                Text("Phát hiện phần mềm can thiệp.\nỨng dụng đã bị khóa an toàn.")
                    .font(.system(size: 12, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.75))
            }
        }
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
        case .home: return "house.circle.fill"
        case .new: return "clock.fill"; case .sources: return "shippingbox.fill"
        case .installed: return "lock.shield.fill"
        case .files: return "folder.fill"; case .search: return "magnifyingglass"
        }
    }
}
