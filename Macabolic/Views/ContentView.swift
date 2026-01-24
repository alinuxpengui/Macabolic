import SwiftUI

struct ContentView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var languageService: LanguageService
    @EnvironmentObject var updateChecker: UpdateChecker
    @State private var showPreferences = false
    @State private var showUpdateAlert = false
    
    var body: some View {
        Group {
            if #available(macOS 13.0, *) {
                NavigationSplitView {
                    SidebarView(showPreferences: $showPreferences)
                } detail: {
                    DetailView()
                }
            } else {
                NavigationView {
                    SidebarView(showPreferences: $showPreferences)
                    DetailView()
                }
            }
        }
        .sheet(isPresented: $appState.showAddDownloadSheet) {
            AddDownloadView()
                .environmentObject(downloadManager)
                .environmentObject(appState)
                .environmentObject(languageService)
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesView()
        }
        .sheet(isPresented: $languageService.isFirstLaunch) {
            WelcomeView()
                .interactiveDismissDisabled()
        }
        .task {
            await downloadManager.initialize(languageService: languageService)
            await updateChecker.checkForUpdates()
            if updateChecker.hasUpdate {
                showUpdateAlert = true
            }
        }
        .alert(languageService.s("update_available_title"), isPresented: $showUpdateAlert) {
            Button(languageService.s("update_now")) {
                showPreferences = true
            }
            Button(languageService.s("later"), role: .cancel) { }
        } message: {
            Text(String(format: languageService.s("update_available_message"), updateChecker.latestVersion ?? ""))
        }
        .alert(languageService.s("legal_disclaimer_title"), isPresented: $downloadManager.showDisclaimer) {
            Button(languageService.s("close")) {
                downloadManager.acknowledgeDisclaimer()
            }
        } message: {
            Text(languageService.s("legal_disclaimer_message"))
        }
        .alert(String(format: languageService.s("whats_new_title"), Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.1.1"), isPresented: $downloadManager.showWhatsNew) {
            Button(languageService.s("ok")) { }
        } message: {
            Text(String(format: languageService.s("whats_new_message"), Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.1.1"))
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var languageService: LanguageService
    @Binding var showPreferences: Bool
    
    var body: some View {
        List {
            Section {
                sidebarButton(item: .home)
            }
            
            Section(languageService.s("downloading")) {
                sidebarButton(item: .downloading, badgeCount: downloadManager.downloadingCount, badgeColor: .blue)
                sidebarButton(item: .queued, badgeCount: downloadManager.queuedCount, badgeColor: .orange)
            }
            
            Section(languageService.s("history")) {
                sidebarButton(item: .completed, badgeCount: downloadManager.completedCount, badgeColor: .green)
                sidebarButton(item: .failed, badgeCount: downloadManager.failedCount, badgeColor: .red)
            }
        }
        .listStyle(.sidebar)
        .macabolicSidebarWidth()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/sponsors/alinuxpengui")!) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text(languageService.s("support_btn"))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)

                Button {
                    showPreferences = true
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text(languageService.s("settings"))
                        Spacer()
                        Text("⌘,")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
            .padding(.bottom, 8)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    appState.showAddDownloadSheet = true
                } label: {
                    Label(languageService.s("new_download"), systemImage: "plus")
                }
            }
        }
    }
    
    @ViewBuilder
    private func sidebarButton(item: NavigationItem, badgeCount: Int = 0, badgeColor: Color = .blue) -> some View {
        Button {
            appState.selectedNavItem = item
        } label: {
            HStack {
                Label(item.title(lang: languageService), systemImage: item.icon)
                Spacer()
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .foregroundColor(appState.selectedNavItem == item ? .accentColor : .primary)
        .listRowBackground(appState.selectedNavItem == item ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

extension View {
    @ViewBuilder
    func macabolicSidebarWidth() -> some View {
        if #available(macOS 13.0, *) {
            self.navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } else {
            self.frame(minWidth: 200, idealWidth: 220, maxWidth: 300)
        }
    }
}

struct DetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var languageService: LanguageService
    
    var body: some View {
        currentView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(appState.selectedNavItem)
    }
    
    @ViewBuilder
    private var currentView: some View {
        switch appState.selectedNavItem {
        case .home:
            HomeView()
        case .downloading:
            DownloadListView(downloads: downloadManager.downloadingDownloads, emptyMessage: languageService.s("empty_downloading"), showStop: true)
        case .queued:
            DownloadListView(downloads: downloadManager.queuedDownloads, emptyMessage: languageService.s("empty_queued"), showStop: true)
        case .completed:
            DownloadListView(downloads: downloadManager.completedDownloads, emptyMessage: languageService.s("empty_completed"), showStop: false)
        case .failed:
            DownloadListView(downloads: downloadManager.failedDownloads, emptyMessage: languageService.s("empty_failed"), showStop: false)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var languageService: LanguageService
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "arrow.down")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Macabolic")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(LocalizedStringKey(languageService.s("url_placeholder")))
                .font(.title3)
                .foregroundColor(.secondary)
            
            Button {
                appState.showAddDownloadSheet = true
            } label: {
                Label(languageService.s("new_download"), systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("n", modifiers: .command)
            
            HStack(spacing: 20) {
                StatCard(title: languageService.s("stat_downloading"), count: downloadManager.downloadingCount, color: .blue) {
                    appState.selectedNavItem = .downloading
                }
                StatCard(title: languageService.s("stat_queued"), count: downloadManager.queuedCount, color: .orange) {
                    appState.selectedNavItem = .queued
                }
                StatCard(title: languageService.s("stat_completed"), count: downloadManager.completedCount, color: .green) {
                    appState.selectedNavItem = .completed
                }
                StatCard(title: languageService.s("stat_failed"), count: downloadManager.failedCount, color: .red) {
                    appState.selectedNavItem = .failed
                }
            }
            .padding(.top, 20)
            
            Spacer()
            
            if let version = downloadManager.ytdlpVersion {
                HStack {
                    Image(systemName: "terminal")
                    Text("yt-dlp \(version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct StatCard: View {
    @EnvironmentObject var languageService: LanguageService
    let title: String
    let count: Int
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text("\(count)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
