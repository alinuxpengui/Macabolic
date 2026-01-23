import SwiftUI

struct ContentView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var languageService: LanguageService
    @EnvironmentObject var updateChecker: UpdateChecker
    @State private var showPreferences = false
    @State private var showUpdateAlert = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView(showPreferences: $showPreferences)
        } detail: {
            DetailView()
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
        List(selection: $appState.selectedNavItem) {
            Section {
                NavigationLink(value: NavigationItem.home) {
                    Label(NavigationItem.home.title(lang: languageService), systemImage: NavigationItem.home.icon)
                }
            }
            
            Section(languageService.s("downloading")) {
                NavigationLink(value: NavigationItem.downloading) {
                    HStack {
                        Label(NavigationItem.downloading.title(lang: languageService), systemImage: NavigationItem.downloading.icon)
                        Spacer()
                        if downloadManager.downloadingCount > 0 {
                            Text("\(downloadManager.downloadingCount)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                NavigationLink(value: NavigationItem.queued) {
                    HStack {
                        Label(NavigationItem.queued.title(lang: languageService), systemImage: NavigationItem.queued.icon)
                        Spacer()
                        if downloadManager.queuedCount > 0 {
                            Text("\(downloadManager.queuedCount)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            Section(languageService.s("history")) {
                NavigationLink(value: NavigationItem.completed) {
                    HStack {
                        Label(NavigationItem.completed.title(lang: languageService), systemImage: NavigationItem.completed.icon)
                        Spacer()
                        if downloadManager.completedCount > 0 {
                            Text("\(downloadManager.completedCount)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                }

                NavigationLink(value: NavigationItem.failed) {
                    HStack {
                        Label(NavigationItem.failed.title(lang: languageService), systemImage: NavigationItem.failed.icon)
                        Spacer()
                        if downloadManager.failedCount > 0 {
                            Text("\(downloadManager.failedCount)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
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

#Preview {
    ContentView()
        .environmentObject(DownloadManager())
        .environmentObject(AppState())
        .environmentObject(LanguageService())
}
