import SwiftUI
import UIKit
import AudioToolbox
import MachO
import Security

// MARK: - KEYCHAIN DEVICE ID MANAGER
struct DeviceIDManager {
    static let shared = DeviceIDManager()
    private let account = "solitude_secure_hwid_v3"
    
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

// MARK: - FILE OVERRIDE MANAGER
struct GameFileManager {
    static func applyCustomModFile(subPath: String, fileName: String, fileExtension: String) {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        // Chuẩn hóa đường dẫn thư mục tùy chỉnh (VD: gameassetbundles, chams, v.v.)
        let cleanSubPath = subPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let targetDirectory = docsURL
            .appendingPathComponent("contentcache")
            .appendingPathComponent("compulsory")
            .appendingPathComponent("ios")
            .appendingPathComponent(cleanSubPath)
        
        do {
            if !FileManager.default.fileExists(atPath: targetDirectory.path) {
                try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            let fullFileName = fileName.hasSuffix(".\(fileExtension)") ? fileName : "\(fileName).\(fileExtension)"
            let destinationURL = targetDirectory.appendingPathComponent(fullFileName)
            
            let remoteURLStr = "https://solitudepremium.click/ipa/proxy/uploads/\(fullFileName)"
            if let remoteURL = URL(string: remoteURLStr), let fileData = try? Data(contentsOf: remoteURL) {
                try fileData.write(to: destinationURL, options: .atomic)
            }
        } catch {
            print("Lỗi ghi đè file mod: \(error.localizedDescription)")
        }
    }
}

// Model Aim nhận từ Server API
struct AimItem: Identifiable, Codable {
    var id: String { name }
    let name: String
    let subpath: String
    let filename: String
    let ext: String
}

// MARK: - MAIN CONTENT VIEW
struct ContentView: View {
    @AppStorage("solitude_is_unlocked") private var isUnlocked = false
    @AppStorage("solitude_key_expiry") private var keyExpiryDate: String = ""
    @AppStorage("solitude_active_key") private var activeKey: String = ""
    @AppStorage("solitude_device_id") private var deviceID: String = DeviceIDManager.shared.getID()
    
    @State private var showModMenu: Bool = false
    @State private var securityBreach = false

    var body: some View {
        Group {
            if securityBreach {
                SecurityLockdownView()
            } else if isUnlocked && !isKeyExpired() {
                mainAppContent
            } else {
                KeyLockView(isUnlocked: $isUnlocked, savedExpiry: $keyExpiryDate, activeKey: $activeKey, deviceID: deviceID)
            }
        }
        .onAppear { if SecurityGuard.isCompromised { securityBreach = true } }
    }

    private var mainAppContent: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            ParticleCanvasView()
            
            Group {
                if showModMenu {
                    FreeFireModMenuView(onBack: {
                        UXFeedback.click()
                        withAnimation(.easeInOut(duration: 0.3)) { showModMenu = false }
                    })
                } else {
                    CustomZenithHomeView(onOpenGame: {
                        UXFeedback.click()
                        withAnimation(.easeInOut(duration: 0.3)) { showModMenu = true }
                    })
                }
            }
            .frame(maxHeight: .infinity)
            
            if !showModMenu {
                VStack {
                    Spacer()
                    KeyTimerFloatingWidget(expiryDate: keyExpiryDate)
                        .padding(.bottom, 30)
                }
                .allowsHitTesting(false)
            }
        }
        .tint(.white)
    }

    private func isKeyExpired() -> Bool {
        guard !keyExpiryDate.isEmpty else { return true }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        if let expDate = formatter.date(from: keyExpiryDate) { return Date() > expDate }
        return true
    }
}

// MARK: - GIAO DIỆN MOD MENU CHÍNH (ĐỌC AIM TỪ API SERVER)
struct FreeFireModMenuView: View {
    var onBack: () -> Void
    
    @State private var aimList: [AimItem] = []
    @State private var activeToggles: [String: Bool] = [:]
    @State private var isLoading: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { onBack() }) {
                    Image(systemName: "arrow.left").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .padding(10).background(Circle().fill(Color.white.opacity(0.1)))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("Free Fire Mod Menu").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    Text("com.dts.freefireth").font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Color.clear.frame(width: 34, height: 34)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 15)
            
            if isLoading {
                Spacer()
                ProgressView().tint(.white)
                Text("Đang tải danh sách Aim từ Server...").font(.system(size: 11, design: .monospaced)).foregroundColor(.white.opacity(0.5)).padding(.top, 10)
                Spacer()
            } else if aimList.isEmpty {
                Spacer()
                Text("Chưa có cấu hình Aim nào trên Web!").font(.system(size: 12, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(aimList) { item in
                            DynamicModToggleRow(
                                title: item.name,
                                subpath: item.subpath,
                                filename: item.filename,
                                isOn: Binding(
                                    get: { activeToggles[item.name] ?? false },
                                    set: { val in
                                        activeToggles[item.name] = val
                                        if val {
                                            UXFeedback.success()
                                            GameFileManager.applyCustomModFile(subPath: item.subpath, fileName: item.filename, fileExtension: item.ext)
                                        } else {
                                            UXFeedback.click()
                                        }
                                    }
                                )
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear { fetchAimConfig() }
    }

    private func fetchAimConfig() {
        let url = URL(string: "https://solitudepremium.click/ipa/proxy/api.php?action=get_aims")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data else { return }
                if let decoded = try? JSONDecoder().decode([AimItem].self, from: data) {
                    self.aimList = decoded
                }
            }
        }.resume()
    }
}

struct DynamicModToggleRow: View {
    let title: String
    let subpath: String
    let filename: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)).frame(width: 44, height: 44)
                Image(systemName: "scope").font(.system(size: 16)).foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    Text("ACTIVE")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.white.opacity(0.15)).foregroundColor(.white).cornerRadius(4)
                }
                Text("ios/\(subpath)/\(filename)").font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.white)
        }
        .padding(14)
        .background(Color.black.opacity(0.6))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - GIAO DIỆN TRANG CHỦ
struct CustomZenithHomeView: View {
    var onOpenGame: () -> Void
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 25) {
                Spacer().frame(height: 10)
                
                VStack(spacing: 12) {
                    AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                        switch phase {
                        case .empty: Circle().fill(Color.white.opacity(0.1)).frame(width: 90, height: 90)
                        case .success(let image):
                            image.resizable().scaledToFill().frame(width: 90, height: 90).clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2).shadow(color: .white, radius: 8))
                        case .failure(_):
                            Image(systemName: "person.circle.fill").font(.system(size: 90)).foregroundColor(.white)
                        @unknown default: EmptyView()
                        }
                    }
                    
                    Text("Headlock Zenith Solitude")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .white, radius: 8)
                    
                    HStack {
                        Circle().frame(width: 3, height: 3).foregroundColor(.white)
                        Text("Version 4.2.29")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                        Circle().frame(width: 3, height: 3).foregroundColor(.white)
                    }
                }
                .padding(.top, 20)
                
                HStack(spacing: 15) {
                    AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/free.jpg")) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill().frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 12))
                        default: RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.3)).frame(width: 48, height: 48)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Free Fire").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        Text("com.dts.freefireth").font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    
                    Button(action: { onOpenGame() }) {
                        HStack(spacing: 4) {
                            Text("OPEN").font(.system(size: 11, weight: .bold, design: .monospaced))
                            Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.white.opacity(0.1)).cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(16)
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 120)
        }
    }
}

// MARK: - MÀN HÌNH KHÓA KEY & WIDGET
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
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(AngularGradient(gradient: Gradient(colors: [.clear, .white, .clear]), center: .center), lineWidth: 2.5)
                                .frame(width: 110, height: 110)
                                .rotationEffect(.degrees(rotationAngle))
                                .onAppear { withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { rotationAngle = 360 } }
                                .shadow(color: .white, radius: 10)
                            
                            AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                                switch phase {
                                case .empty: ProgressView().tint(.white)
                                case .success(let image):
                                    image.resizable().scaledToFill().frame(width: 94, height: 94).clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2).shadow(color: .white, radius: 5))
                                case .failure(_):
                                    Image(systemName: "bolt.shield.fill").font(.system(size: 40)).foregroundColor(.white).shadow(color: .white, radius: 10)
                                @unknown default: EmptyView()
                                }
                            }
                        }
                        .padding(.top, 40)
                        
                        Text("Headlock Zenith Solitude")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .tracking(4).foregroundColor(.white).shadow(color: .white, radius: 10)
                    }
                    
                    VStack(spacing: 18) {
                        HStack {
                            Image(systemName: "cpu").foregroundColor(.white).font(.system(size: 11))
                            Text("HWID: \(deviceID)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white).lineLimit(1)
                            Spacer()
                            if isFinding || isLoading {
                                ProgressView().scaleEffect(0.7).tint(.white)
                            } else {
                                Button(action: { UXFeedback.click(); findKeyByDeviceID() }) {
                                    Text("TÌM KEY").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.black)
                                        .padding(.horizontal, 8).padding(.vertical, 4).background(Color.white).cornerRadius(4)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        Text("Version 4.2.29")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(.white).shadow(color: .white, radius: 6)
                        
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)).frame(width: 42, height: 42)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.5), lineWidth: 1))
                                Image(systemName: "key.horizontal.fill").font(.system(size: 16)).foregroundColor(.white).rotationEffect(.degrees(-45))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Key:").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white)
                                    Group {
                                        if isKeyVisible { TextField("Nhập Key...", text: $keyCode) }
                                        else { SecureField("••••••••••••", text: $keyCode) }
                                    }
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                                    .foregroundColor(.white).accentColor(.white)
                                    .autocapitalization(.allCharacters).disableAutocorrection(true)
                                    .onChange(of: keyCode) { _ in UXFeedback.typing() }
                                    
                                    Button(action: { UXFeedback.click(); isKeyVisible.toggle() }) {
                                        Image(systemName: isKeyVisible ? "eye.slash.fill" : "eye.fill").foregroundColor(.white).font(.system(size: 13))
                                    }
                                }
                                .padding(.vertical, 8).padding(.horizontal, 12).background(Color.black.opacity(0.9)).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1.5))
                                
                                if let error = inlineErrorMsg {
                                    Text(error).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(isSuccessMsg ? .green : .red)
                                } else {
                                    Text("Trạng thái: Chờ xác thực mã...").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(.white.opacity(0.7))
                                }
                            }
                            
                            Button(action: { UXFeedback.click(); if let pasted = UIPasteboard.general.string { keyCode = pasted.trimmingCharacters(in: .whitespacesAndNewlines) } }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)).frame(width: 42, height: 42)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.5), lineWidth: 1))
                                    Image(systemName: "doc.on.clipboard").font(.system(size: 15)).foregroundColor(.white)
                                }
                            }
                        }
                        .padding(14).background(Color.black.opacity(0.6)).cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                        .offset(x: shakeOffset)

                        Button(action: { UXFeedback.click(); verifyKeyWithServer() }) {
                            Text("KÍCH HOẠT HỆ THỐNG")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .tracking(2).foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(Color.white).cornerRadius(14).shadow(color: .white, radius: 10)
                        }.disabled(isLoading || isFinding)

                        Button(action: {
                            UXFeedback.click()
                            if let url = URL(string: "https://solitudepremium.click/ipa/proxy/keyproxy.php") { UIApplication.shared.open(url) }
                        }) {
                            HStack {
                                Image(systemName: "globe.asia.australia.fill")
                                Text("LẤY KEY BẢN QUYỀN MỚI")
                            }
                            .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.white).frame(maxWidth: .infinity)
                            .padding(.vertical, 14).background(Color.black).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.8), lineWidth: 1.5))
                        }
                    }
                    .padding(20).background(Color.black.opacity(0.8)).cornerRadius(28)
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.6), lineWidth: 1.5))
                    .padding(.horizontal, 16)
                    
                    Text("Headlock Center By Zenith Solitude")
                        .font(.system(size: 10, weight: .black, design: .monospaced)).foregroundColor(.white.opacity(0.8))
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func findKeyByDeviceID() {
        isFinding = true; inlineErrorMsg = nil; isSuccessMsg = false
        let endpoint = URL(string: "https://solitudepremium.click/ipa/proxy/api.php")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "action=find_key&device_id=\(deviceID)".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                isFinding = false
                guard let data = data else { return }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["status"] as? String == "success", let foundKey = json["key"] as? String {
                    self.keyCode = foundKey
                    UXFeedback.success()
                    self.isSuccessMsg = true
                    self.inlineErrorMsg = "✅ Đã tìm thấy Key!"
                } else {
                    triggerError(msg: "❌ Không tìm thấy Key gắn với máy này!")
                }
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

        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data else { triggerError(msg: "⚠️ Lỗi kết nối!"); return }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["status"] as? String == "success" {
                    triggerSuccess(expiry: json["expires_at"] as? String ?? "", key: trimmedKey)
                } else {
                    triggerError(msg: "❌ Key sai hoặc hết hạn!")
                }
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
            savedExpiry = expiry
            activeKey = key
            withAnimation(.easeInOut(duration: 0.6)) { isUnlocked = true }
        }
    }
}

// MARK: - WIDGET THỜI GIAN GỌN GÀNG
private struct KeyTimerFloatingWidget: View {
    let expiryDate: String
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remaining = calculateRemaining(from: expiryDate, currentDate: context.date)
            HStack(spacing: 8) {
                Image(systemName: "key.radiowaves.forward").font(.system(size: 11)).foregroundColor(.white)
                Text("Còn lại: \(remaining)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.black.opacity(0.85))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.4), lineWidth: 1))
            .shadow(color: .white.opacity(0.2), radius: 8)
        }
    }
    private func calculateRemaining(from dateStr: String, currentDate: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"; formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        guard let expDate = formatter.date(from: dateStr) else { return "Lỗi Ngày" }
        let diff = Int(expDate.timeIntervalSince(currentDate))
        if diff <= 0 { return "Hết Hạn" }
        let days = diff / 86400, hrs = (diff % 86400) / 3600, mins = (diff % 3600) / 60, secs = diff % 60
        return String(format: "%dNg %02d:%02d:%02d", days, hrs, mins, secs)
    }
}

private struct SecurityLockdownView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("SECURITY BREACH").font(.system(size: 20, weight: .black, design: .monospaced)).foregroundColor(.white)
        }
    }
}

// MARK: - HIỆU ỨNG HẠT TO HƠN, SÁNG RÕ RỆT
private struct ParticleCanvasView: View {
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { graphicsContext, size in
                let time = context.date.timeIntervalSinceReferenceDate
                for i in 0..<80 {
                    let seed = Double(i) * 77.0
                    let x = (sin(time * 0.2 + seed) * 0.5 + 0.5) * size.width
                    let speed = 120.0 + fmod(seed, 80.0)
                    let y = size.height - fmod(time * speed + seed, size.height + 100)
                    let particleSize = CGFloat(fmod(seed, 3.0) + 1.5) // Tăng kích thước hạt to lên (1.5 -> 4.5)
                    let opacity = Double(fmod(seed, 0.6) + 0.4) // Sáng rõ
                    
                    let rect = CGRect(x: x, y: y, width: particleSize, height: particleSize)
                    graphicsContext.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
