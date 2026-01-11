import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var languageService: LanguageService
    @State private var searchText = ""
    
    var filteredHistory: [HistoricDownload] {
        if searchText.isEmpty {
            return downloadManager.history
        }
        return downloadManager.history.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        Group {
            if downloadManager.history.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                    
                    Divider()
                    
                    // List
                    List {
                        ForEach(filteredHistory) { download in
                            HistoryRowView(download: download)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.inset)
                }
            }
        }
        .toolbar {
            if !downloadManager.history.isEmpty {
                ToolbarItem {
                    Button {
                        downloadManager.clearHistory()
                    } label: {
                        Label(languageService.s("clear_history"), systemImage: "trash")
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(languageService.s("history_empty"))
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text(languageService.s("history_desc"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(languageService.s("search_history"), text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding()
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let download = filteredHistory[index]
            downloadManager.removeFromHistory(download)
        }
    }
}

struct HistoryRowView: View {
    let download: HistoricDownload
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var languageService: LanguageService
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: download.fileType.isVideo ? "play.rectangle.fill" : "music.note")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(download.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(download.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(download.fileType.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(formatDate(download.downloadDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                // Dosya varsa aç butonu
                if FileManager.default.fileExists(atPath: download.filePath) {
                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: download.filePath))
                    } label: {
                        Image(systemName: "play.circle")
                    }
                    .buttonStyle(.borderless)
                    .help(languageService.s("play"))
                }
                
                // Yeniden indir
                Button {
                    appState.urlToDownload = download.url
                    appState.showAddDownloadSheet = true
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .help(languageService.s("redownload"))
                
                // URL kopyala
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(download.url, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help(languageService.s("copy_url"))
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: languageService.selectedLanguage == .turkish ? "tr_TR" : "en_US")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    HistoryView()
        .environmentObject(DownloadManager())
        .environmentObject(AppState())
        .environmentObject(LanguageService())
}
