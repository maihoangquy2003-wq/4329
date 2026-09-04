import SwiftUI
import UIKit
import AudioToolbox
import MachO
import Security

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = true
    
    func load(urlStr: String) {
        guard let url = URL(string: urlStr) else { isLoading = false; return }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                self.isLoading = false
                if let data = data, let uiImage = UIImage(data: data) { self.image = uiImage }
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
                ProgressView().tint(.white).scaleEffect(0.6)
            } else {
                Image(systemName: fallbackIcon).font(.title).foregroundColor(.white.opacity(0.5))
            }
        }
        .onAppear { loader.load(urlStr: url) }
    }
}

struct DeviceIDManager {
    static let shared = DeviceIDManager()
    private let account = "solitude_secure_hwid"
    func getID() -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data, let id = String(data: data, encoding: .utf8) { return id }
        let newID = "APEX-ZENITH-SOLITUDE-\(UUID().uuidString.prefix(8).uppercased())"
        SecItemAdd([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account, kSecValueData as String: newID.data(using: .utf8)!] as CFDictionary, nil)
        return newID
    }
}

struct UXFeedback {
    static func click() { AudioServicesPlaySystemSound(1306); UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { AudioServicesPlaySystemSound(1407); UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { AudioServicesPlaySystemSound(1053); UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey) private var developerModeEnabled = false
     
    @AppStorage("solitude_is_unlocked") private var isUnlocked = false
    @AppStorage("solitude_key_expiry") private var keyExpiryDate: String = ""
    @AppStorage("solitude_active_key") private var activeKey: String = ""
    
    @State private var deviceID: String = DeviceIDManager.shared.getID()
    @State private var tabNavigation: AppTabNavigationState = AppTabNavigationState()
    @State private var showSettings = false
    @State private var showLogs = false

    var body: some View {
        Group {
            if isUnlocked {
                TabView(selection: $tabNavigation.selectedTab) {
                    CustomZenithHomeView(onOpenApp: { targetBundle in
                        UserDefaults.standard.set(targetBundle, forKey: "selected_game_bundle")
                        tabNavigation.select(AppSection.installed.rawValue)
                    }).tag(0)
                    
                    PatchProjectsView(onOpenSettings: { showSettings = true }, onOpenLogs: { showLogs = true }).tag(1)
                }
            } else {
                KeyLockView(isUnlocked: $isUnlocked, savedExpiry: $keyExpiryDate, activeKey: $activeKey, deviceID: deviceID)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
        .patchStorePresentation(patchStore)
        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }
}

struct CustomZenithHomeView: View {
    var onOpenApp: (String) -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    Spacer().frame(height: 10)
                    VStack(spacing: 12) {
                        CachedImageView(url: "https://solitudepremium.click/ipa/proxy/li.jpg", fallbackIcon: "person.circle.fill")
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        
                        Text("VANDUYIOS VIP\nVANDUY")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                        
                        Text("+ MOD MENU ONLINE +")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // Chỉ hiển thị FF Max và FF Thường
                    VStack(spacing: 12) {
                        GameCardView(title: "Free Fire Max", bundle: "com.dts.freefiremax", icon: "https://solitudepremium.click/ipa/proxy/free.jpg") {
                            onOpenApp("com.dts.freefiremax")
                        }
                        GameCardView(title: "Free Fire", bundle: "com.dts.freefireth", icon: "https://solitudepremium.click/ipa/proxy/free.jpg") {
                            onOpenApp("com.dts.freefireth")
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 100)
            }
        }
    }
}

struct GameCardView: View {
    let title: String
    let bundle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            CachedImageView(url: icon, fallbackIcon: "gamecontroller.fill")
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Text(bundle).font(.system(size: 11, design: .monospaced)).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            
            Button(action: { UXFeedback.click(); action() }) {
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
        .padding(14)
        .background(Color.black.opacity(0.6))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
}

struct KeyLockView: View {
    @Binding var isUnlocked: Bool
    @Binding var savedExpiry: String
    @Binding var activeKey: String
    var deviceID: String
    @State private var keyCode = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("ZENITH SOLITUDE").font(.system(size: 24, weight: .black, design: .monospaced)).foregroundColor(.white)
                TextField("Nhập Key bản quyền...", text: $keyCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 30)
                Button(action: {
                    savedExpiry = "2026-12-31 23:59:59"
                    activeKey = keyCode
                    isUnlocked = true
                }) {
                    Text("KÍCH HOẠT HỆ THỐNG")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 30)
            }
        }
    }
}

private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore
    func body(content: Content) -> some View { content }
}
extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View { modifier(PatchStorePresentationModifier(store: store)) }
    func repositoryStorePresentation(_ store: PackageRepositoryStore, patchStore: PatchProjectStore) -> some View { self }
}
