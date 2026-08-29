 import SwiftUI
import UIKit
import AudioToolbox
import MachO

// MARK: - SYSTEM SECURITY GUARD (ANTI-DYLIB & ANTI-BYPASS)
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
    static func click() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { AudioServicesPlaySystemSound(1407); UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { AudioServicesPlaySystemSound(1053); UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func typing() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
}

// MARK: - MAIN CONTENT VIEW
struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false
     
    @AppStorage("solitude_is_unlocked") private var isUnlocked = false
    @AppStorage("solitude_key_expiry") private var keyExpiryDate: String = ""
    @AppStorage("solitude_active_key") private var activeKey: String = ""
    
    // Tự động tạo Device ID chuẩn form APEX-ZENITH-SOLITUDE-<RANDOM>
    @AppStorage("solitude_device_id") private var deviceID: String = "APEX-ZENITH-SOLITUDE-\(UUID().uuidString.prefix(8).uppercased())"
    
    @State private var tabNavigation: AppTabNavigationState
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var securityBreach = false

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
        Group {
            if securityBreach {
                SecurityLockdownView()
            } else if isUnlocked && !isKeyExpired() {
                mainAppContent
                    .overlay(KeyTimerFloatingWidget(expiryDate: keyExpiryDate), alignment: .bottomTrailing)
            } else {
                KeyLockView(isUnlocked: $isUnlocked, savedExpiry: $keyExpiryDate, activeKey: $activeKey, deviceID: deviceID)
            }
        }
        .onAppear { if SecurityGuard.isCompromised { securityBreach = true } }
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
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section).tabItem { CompactTabLabel(title: language.text(section.titleKey), systemImage: section.systemImage) }.tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button { withAnimation(.easeInOut(duration: 0.18)) { tabNavigation.select(section.rawValue) } } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.navigationTitle("3105")
        } detail: { sectionContent(selectedVisibleSection) }
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

    private var tabSelection: Binding<Int> { Binding(get: { tabNavigation.selectedTab }, set: { tabNavigation.select($0) }) }
    private var filesTabSession: Binding<FilesTabSession> { Binding(get: { tabNavigation.filesTabs }, set: { tabNavigation.setFilesTabs($0) }) }
    private var featureVisibility: FeatureVisibility { FeatureVisibility(developerModeEnabled: developerModeEnabled) }
    private var selectedVisibleSection: AppSection { AppSection(rawValue: tabNavigation.selectedTab) ?? .home }
    private func openSettings() { showSettings = true }
    private func openLogs() { showLogs = true }
    
    private func isKeyExpired() -> Bool {
        guard !keyExpiryDate.isEmpty else { return true }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        if let expDate = formatter.date(from: keyExpiryDate) { return Date() > expDate }
        return true
    }
}

// MARK: - MÀN HÌNH KHÓA KEY (ĐÃ CHẺ NHỎ UI ĐỂ FIX LỖI BUILD)
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
                }
                .padding(.bottom, 40)
            }
        }
    }

    // 1. Tách phần Header (Logo, Tên, Version)
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(AngularGradient(gradient: Gradient(colors: [.clear, .white, .clear]), center: .center), lineWidth: 2.5)
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear { withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { rotationAngle = 360 } }
                    .shadow(color: .white.opacity(0.8), radius: 15)
                
                AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                    switch phase {
                    case .empty: ProgressView().tint(.white)
                    case .success(let image):
                        image.resizable().scaledToFill().frame(width: 94, height: 94).clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    case .failure(_):
                        Image(systemName: "bolt.shield.fill").font(.system(size: 40)).foregroundColor(.white)
                    @unknown default: EmptyView()
                    }
                }
            }
            .padding(.top, 40)
            
            Text("ZENITH SOLITUDE")
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .tracking(6)
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.8), radius: 10)
            
            HStack(spacing: 8) {
                Circle().frame(width: 4, height: 4).foregroundColor(.white).shadow(color: .white, radius: 5)
                Text("Headlock Version 4.3.29")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.8))
                Circle().frame(width: 4, height: 4).foregroundColor(.white).shadow(color: .white, radius: 5)
            }
        }
    }
    
    // 2. Tách phần Khung Điều Khiển
    private var controlPanelSection: some View {
        VStack(spacing: 18) {
            hwidSection
            inputFormSection
            actionButtonsSection
        }
        .padding(20)
        .background(Color.black.opacity(0.7))
        .cornerRadius(28)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.2), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.9), radius: 40, x: 0, y: 20)
        .padding(.horizontal, 16)
    }
    
    // 3. Tách phần HWID và Nút Tìm Key
    private var hwidSection: some View {
        HStack {
            Image(systemName: "cpu").foregroundColor(.white.opacity(0.5)).font(.system(size: 10))
            Text("HWID: \(deviceID)")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
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
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // 4. Tách phần Form Nhập
    private var inputFormSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)).frame(width: 42, height: 42)
                    Image(systemName: "key.horizontal.fill").font(.system(size: 16)).foregroundColor(.white).rotationEffect(.degrees(-45))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Key:").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.8))
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
                            Image(systemName: isKeyVisible ? "eye.slash.fill" : "eye.fill").foregroundColor(.white.opacity(0.5)).font(.system(size: 13))
                        }
                    }
                    .padding(.vertical, 8).padding(.horizontal, 12).background(Color.black.opacity(0.8)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    
                    if let error = inlineErrorMsg {
                        Text(error)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(isSuccessMsg ? .green : .white)
                            .shadow(color: isSuccessMsg ? .green : .white, radius: 2)
                    } else {
                        Text("Trạng thái: Chờ xác thực mã...").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(.white.opacity(0.4))
                    }
                }
                
                Button(action: {
                    UXFeedback.click()
                    if let pasted = UIPasteboard.general.string { keyCode = pasted.trimmingCharacters(in: .whitespacesAndNewlines) }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)).frame(width: 42, height: 42)
                        Image(systemName: "doc.on.clipboard").font(.system(size: 15)).foregroundColor(.white.opacity(0.9))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.5))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.3), lineWidth: 1.5))
        .shadow(color: .white.opacity(0.1), radius: 15)
        .offset(x: shakeOffset)
    }
    
    // 5. Tách phần Nút Bấm
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: { UXFeedback.click(); verifyKeyWithServer() }) {
                Text("KÍCH HOẠT HỆ THỐNG")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .tracking(2).foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(LinearGradient(colors: [.white, Color(white: 0.7)], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(14).shadow(color: .white.opacity(0.6), radius: 10)
            }.disabled(isLoading || isFinding)

            Button(action: {
                UXFeedback.click()
                if let url = URL(string: "https://solitudepremium.click/ipa/proxy/key.php") { UIApplication.shared.open(url) }
            }) {
                HStack {
                    Image(systemName: "globe.asia.australia.fill")
                    Text("LẤY KEY BẢN QUYỀN MỚI")
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.white).frame(maxWidth: .infinity)
                .padding(.vertical, 14).background(Color.white.opacity(0.05)).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
        }
    }

    // MARK: - API LOGIC
    private func findKeyByDeviceID() {
        isFinding = true
        inlineErrorMsg = nil
        isSuccessMsg = false
        
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
                        } else {
                            let msg = json["message"] as? String ?? "Không tìm thấy Key!"
                            triggerError(msg: "❌ " + msg)
                        }
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
                            let expiry = json["expires_at"] as? String ?? ""
                            triggerSuccess(expiry: expiry, key: trimmedKey)
                        } else {
                            let msg = json["message"] as? String ?? "Mã Key sai hoặc không tồn tại!"
                            triggerError(msg: "❌ " + msg)
                        }
                    } else { triggerError(msg: "⚠️ Phản hồi bất thường!") }
                } catch { triggerError(msg: "⚠️ Lỗi hệ thống mã hóa!") }
            }
        }.resume()
    }
    
    private func triggerError(msg: String) {
        UXFeedback.error()
        isSuccessMsg = false
        inlineErrorMsg = msg
        withAnimation(.spring(response: 0.2, dampingFraction: 0.2)) { shakeOffset = 10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { shakeOffset = -10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { shakeOffset = 0 }
    }
    
    private func triggerSuccess(expiry: String, key: String) {
        UXFeedback.success()
        isSuccessMsg = true
        inlineErrorMsg = "✅ Xác thực thành công!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            savedExpiry = expiry; activeKey = key
            withAnimation(.easeInOut(duration: 0.6)) { isUnlocked = true }
        }
    }
}

// MARK: - WIDGET NỔI GÓC DƯỚI
private struct KeyTimerFloatingWidget: View {
    let expiryDate: String
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remaining = calculateRemaining(from: expiryDate, currentDate: context.date)
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)).frame(width: 32, height: 32)
                    Image(systemName: "key.radiowaves.forward").font(.system(size: 14)).foregroundColor(.white).shadow(color: .white, radius: 4)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("BẢN QUYỀN ĐÃ KÍCH HOẠT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                    Text("Còn Lại: \(remaining)")
                        .font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(.white)
                }
            }
            .padding(10).background(.ultraThinMaterial).background(Color.black.opacity(0.8)).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 1))
            .shadow(color: .white.opacity(0.1), radius: 10).padding(.bottom, 60).padding(.trailing, 16)
        }
    }
    private func calculateRemaining(from dateStr: String, currentDate: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"; formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        guard let expDate = formatter.date(from: dateStr) else { return "Lỗi Ngày" }
        let diff = Int(expDate.timeIntervalSince(currentDate))
        if diff <= 0 { return "Đã Hết Hạn" }
        let days = diff / 86400, hrs = (diff % 86400) / 3600, mins = (diff % 3600) / 60, secs = diff % 60
        return String(format: "%d Ngày %02d:%02d:%02d", days, hrs, mins, secs)
    }
}

// MARK: - MÀN HÌNH KHÓA KHẨN CẤP
private struct SecurityLockdownView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "shield.slash.fill").font(.system(size: 80)).foregroundColor(.white).shadow(color: .white, radius: 20)
                Text("SECURITY BREACH").font(.system(size: 20, weight: .black, design: .monospaced)).foregroundColor(.white)
                Text("Phát hiện phần mềm can thiệp.\nỨng dụng đã bị khóa an toàn.").font(.system(size: 12, design: .monospaced)).multilineTextAlignment(.center).foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - HIỆU ỨNG HẠT BỤI NỀN ĐỘNG
private struct ParticleCanvasView: View {
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { graphicsContext, size in
                let time = context.date.timeIntervalSinceReferenceDate
                for i in 0..<150 {
                    let seed = Double(i) * 99.0
                    let x = (sin(time * 0.15 + seed) * 0.5 + 0.5) * size.width
                    let speed = 150.0 + fmod(seed, 100.0)
                    let y = size.height - fmod(time * speed + seed, size.height + 50)
                    let particleSize = CGFloat(fmod(seed, 1.5) + 0.5)
                    let opacity = Double(fmod(seed, 0.6) + 0.1)
                    
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
        case .home: return "tab.home"
        case .new: return "tab.new"
        case .sources: return "tab.sources"
        case .installed: return "tab.installed"
        case .files: return "tab.files"
        case .search: return "tab.search"
        }
    }
    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .new: return "clock.fill"
        case .sources: return "shippingbox.fill"
        case .installed: return "tray.full.fill"
        case .files: return "folder.fill"
        case .search: return "magnifyingglass"
        }
    }
}
