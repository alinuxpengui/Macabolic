import SwiftUI

struct DownloadListView: View {
    let downloads: [Download]
    let emptyMessage: String
    let showStop: Bool
    
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var languageService: LanguageService
    
    var body: some View {
        Group {
            if downloads.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(downloads) { download in
                            DownloadRowView(download: download, showStop: showStop)
                        }
                    }
                    .padding()
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Group {
                    if !downloads.isEmpty {
                        if showStop {
                            Button {
                                downloadManager.stopAllDownloads()
                            } label: {
                                Label(languageService.s("stop_all"), systemImage: "stop.circle")
                            }
                        } else {
                            Button {
                                downloadManager.clearDownloads(downloads)
                            } label: {
                                Label(languageService.s("clear"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(emptyMessage)
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DownloadRowView: View {
    @ObservedObject var download: Download
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var languageService: LanguageService
    let showStop: Bool
    
    @State private var isHovering = false
    @State private var showLog = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {

                thumbnailView
                

                VStack(alignment: .leading, spacing: 4) {
                    Text(download.title == "___FETCHING___" ? languageService.s("fetching") : download.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack {
                        statusBadge
                        
                        if let duration = download.duration {
                            Text(duration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if download.status == .downloading {
                        Text(download.displayProgress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let error = download.errorMessage {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .lineLimit(2)
                            
                            if error.contains("Sign in to confirm you're not a bot") {
                                Button(languageService.s("fix_signin_error")) {
                                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                            }
                        }
                    }
                }
                
                Spacer()
                

                actionButtons
            }
            

            if download.status == .downloading || download.status == .processing {
                ProgressView(value: download.progress)
                    .progressViewStyle(.linear)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .onHover { hovering in
            isHovering = hovering
        }
        .sheet(isPresented: $showLog) {
            logSheet
        }
    }
    
    private var thumbnailView: some View {
        Group {
            if let url = download.thumbnailURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    thumbnailPlaceholder
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 120, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "play.rectangle")
                    .foregroundColor(.gray)
            }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            switch download.status {
            case .downloading:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            case .fetching:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            case .processing:
                Image(systemName: "gearshape.2")
                    .font(.caption2)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption2)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption2)
            case .stopped:
                Image(systemName: "stop.circle.fill")
                    .foregroundColor(.gray)
                    .font(.caption2)
            case .queued:
                Image(systemName: "clock")
                    .foregroundColor(.orange)
                    .font(.caption2)
            case .paused:
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.yellow)
                    .font(.caption2)
            }
            
            Text(download.status.title(lang: languageService))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            if download.status == .completed {
                Button {
                    if let path = download.filePath {
                        downloadManager.openFile(path)
                    }
                } label: {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.borderless)
                .help(languageService.s("play"))
                
                Button {
                    if let path = download.filePath {
                        downloadManager.showInFinder(path)
                    }
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help(languageService.s("finder"))
                
                Button {
                    appState.urlToDownload = download.url
                    appState.showAddDownloadSheet = true
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .help(languageService.s("redownload"))
            }
            
            if download.status == .failed || download.status == .stopped {
                Button {
                    downloadManager.retryDownload(download)
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                }
                .buttonStyle(.borderless)
                .help(languageService.s("retry"))
                
                Button {
                    appState.urlToDownload = download.url
                    appState.showAddDownloadSheet = true
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .help(languageService.s("redownload"))
            }
            
            if showStop && (download.status == .downloading || download.status == .queued) {
                Button {
                    downloadManager.stopDownload(download)
                } label: {
                    Image(systemName: "stop.circle")
                }
                .buttonStyle(.borderless)
                .help(languageService.s("stop"))
            }
            
            Button {
                showLog = true
            } label: {
                Image(systemName: "doc.text")
            }
            .buttonStyle(.borderless)
            .help(languageService.s("log"))
            
            if download.status == .completed || download.status == .failed || download.status == .stopped {
                Button {
                    downloadManager.removeDownload(download)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .help(languageService.s("remove"))
            }
        }
    }
    
    private var logSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text(languageService.s("download_log"))
                    .font(.headline)
                Spacer()
                Button(languageService.s("close")) {
                    showLog = false
                }
            }
            .padding()
            
            Divider()
            
            ScrollView {
                Text(download.log.isEmpty ? languageService.s("no_log") : download.log)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(width: 600, height: 400)
    }
}
