import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false
    
    // Trạng thái khóa / mở khóa ứng dụng (có lưu lại bằng AppStorage để không phải nhập lại mỗi lần mở app)
    @AppStorage("isAppUnlocked") private var isUnlocked = false

    @State private var tabNavigation: AppTabNavigationState
    @State private var showSettings = false
    @State private var showLogs = false

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-new-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-sources-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-installed-tab")
                    || arguments.contains("--simulate-patch-tab")
                    || arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-files-tab") {
            initialTab = 4
        } else if arguments.contains("--simulate-search-tab") {
            initialTab = 5
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
        _showSettings = State(
            initialValue: arguments.contains("--simulate-settings")
        )
        
        // Nếu chạy trên simulator và có arguments bypass lock (tuỳ chọn)
        if arguments.contains("--bypass-lock") {
            UserDefaults.standard.set(true, forKey: "isAppUnlocked")
        }
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if isUnlocked {
                // Giao diện chính của app khi đã mở khóa thành công
                mainAppContent
            } else {
                // Màn hình khóa nhập Key phong cách Dark-Neon
                KeyLockView(isUnlocked: $isUnlocked)
            }
        }
    }

    // Tách phần giao diện chính của app ra một biến riêng cho gọn code
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
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onChange(of: developerModeEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
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
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("3105")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            RepositoryHomeView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .new:
            RepositoryNewView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .sources:
            RepositorySourcesView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .installed:
            PatchProjectsView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession,
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .search:
            RepositorySearchView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(developerModeEnabled: developerModeActive)
    }

    private var developerModeActive: Bool {
#if targetEnvironment(simulator)
        developerModeEnabled
            || ProcessInfo.processInfo.arguments.contains("--simulate-developer-mode")
            || ProcessInfo.processInfo.arguments.contains("--simulate-files-tab")
#else
        developerModeEnabled
#endif
    }

    private var selectedVisibleSection: AppSection {
        let selected = AppSection(rawValue: tabNavigation.selectedTab)
        return selected.flatMap {
            featureVisibility.isVisible($0) ? $0 : nil
        } ?? .home
    }

    private func openSettings() {
        showSettings = true
    }

    private func openLogs() {
        showLogs = true
    }
}

// MARK: - Màn hình nhập Key (Dark-Neon Style)
private struct KeyLockView: View {
    @Binding var isUnlocked: Bool
    @State private var keyCode: String = "123" // Key mặc định
    @State private var deviceID: String = "APEX-ZENITH-SOLITUDE-74B2"
    @State private var clientIP: String = "113.160.225.12"
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header Logo / Icon
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(lineWidth: 2)
                                .foregroundColor(.white)
                                .frame(width: 90, height: 90)
                                .shadow(color: .white.opacity(0.8), radius: 10)
                            
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 35))
                                .foregroundColor(.white)
                                .shadow(color: .white, radius: 8)
                        }
                        
                        Text("ZENITH SOLITUDE")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .tracking(4)
                            .foregroundColor(.white)
                            .shadow(color: .white, radius: 8)
                        
                        HStack(spacing: 6) {
                            Circle().frame(width: 3, height: 3).foregroundColor(.white)
                            Text("VERSION 23.7.20")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(3)
                                .foregroundColor(.white.opacity(0.8))
                            Circle().frame(width: 3, height: 3).foregroundColor(.white)
                        }
                    }
                    .padding(.top, 30)

                    // Main Card chứa form Anti-Ban & Nhập Key
                    VStack(spacing: 16) {
                        // Anti-Ban Box
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle().frame(width: 8, height: 8).foregroundColor(.white).shadow(color: .white, radius: 6)
                                Text("HEADLOCK CENTER 23.7.20").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                Spacer()
                                Text("ANTIBAN").font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.6))
                            }
                            
                            HStack {
                                Text(clientIP)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3)))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: { clientIP = "113.160.225.12" }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Lấy lại IP")
                                    }
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 8).padding(.vertical, 6)
                                    .background(Color.white.opacity(0.05))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3)))
                                    .foregroundColor(.white)
                                }
                            }
                            
                            HStack {
                                Text("Device ID:").font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.5))
                                Text(deviceID).font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.8)).lineLimit(1)
                            }
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3)))

                        // Input Key Field
                        HStack {
                            Image(systemName: "key.fill").foregroundColor(.white.opacity(0.7)).padding(.leading, 12)
                            TextField("Nhập Key (VIP / FREE)...", text: $keyCode)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                            
                            Button(action: {
                                if let pasted = UIPasteboard.general.string {
                                    keyCode = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 6)
                        }
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.4), lineWidth: 1.5))

                        // Nút Login Hệ Thống
                        Button(action: {
                            let trimmedKey = keyCode.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmedKey == "123" || !trimmedKey.isEmpty {
                                withAnimation {
                                    isUnlocked = true
                                }
                            } else {
                                alertMessage = "Vui lòng nhập đúng Key kích hoạt!"
                                showAlert = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square.fill")
                                Text("LOGIN HỆ THỐNG")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .tracking(2)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .white.opacity(0.8), radius: 10)
                        }

                        // Sub Menu Links
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            Button(action: {}) {
                                HStack { Image(systemName: "key"); Text("LẤY KEY MỚI") }
                                    .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Color.black.opacity(0.7)).cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3)))
                            }.gridCellColumns(2)

                            Button(action: {}) {
                                HStack { Image(systemName: "magnifyingglass"); Text("TÌM KEY BẰNG IP") }
                                    .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Color.black.opacity(0.7)).cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3)))
                            }

                            Button(action: {}) {
                                HStack { Image(systemName: "shield.checkerboard"); Text("TẢI CERT APPLE") }
                                    .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Color.black.opacity(0.7)).cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3)))
                            }
                        }

                        Text("Headlock version 23.7.20 By Zenith Solitude")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.top, 5)
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.6), lineWidth: 1.5))
                    .shadow(color: .white.opacity(0.2), radius: 20)
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 30)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Thông báo"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage:String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
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
