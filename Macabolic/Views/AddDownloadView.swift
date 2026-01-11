import SwiftUI

struct AddDownloadView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    
    @State private var urlInput: String = ""
    @State private var isLoading: Bool = false
    @State private var mediaInfo: MediaInfo?
    @State private var errorMessage: String?
    
    // Download Options
    @State private var saveFolder: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    @State private var fileType: MediaFileType = .mp4
    @State private var videoResolution: VideoResolution = .best
    @State private var customFilename: String = ""
    
    // Extra Options
    @State private var downloadSubtitles: Bool = false
    @State private var subtitleLanguages: String = "tr,en"
    @State private var embedSubtitles: Bool = true
    @State private var embedThumbnail: Bool = true
    @State private var embedMetadata: Bool = true
    @State private var splitChapters: Bool = false
    @State private var sponsorBlock: Bool = false
    
    @State private var showAdvancedOptions: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    urlSection
                    
                    if let info = mediaInfo {
                        mediaInfoSection(info)
                        formatSection
                        saveSection
                        
                        DisclosureGroup(languageService.s("extra_settings"), isExpanded: $showAdvancedOptions) {
                            extraOptionsSection
                        }
                        .padding(.top, 8)
                    }
                    
                    if let error = errorMessage {
                        errorSection(error)
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer
            footer
        }
        .frame(width: 600, height: 650)
        .onAppear {
            // Panoya kopyalanmış URL varsa otomatik yapıştır
            if let clipboardString = NSPasteboard.general.string(forType: .string),
               clipboardString.hasPrefix("http") {
                urlInput = clipboardString
            }
            
            // Eğer appState'den gelen URL varsa
            if !appState.urlToDownload.isEmpty {
                urlInput = appState.urlToDownload
                appState.urlToDownload = ""
            }
        }
        .onChange(of: urlInput) { newValue in
            // Link değiştiğinde ve geçerli bir linkse otomatik fetch başla
            if newValue.hasPrefix("http") && mediaInfo == nil && !isLoading {
                fetchInfo()
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text(languageService.s("new_download"))
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    // MARK: - URL Section
    
    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(languageService.s("video_url"))
                .font(.headline)
            
            HStack {
                TextField(languageService.s("url_hint"), text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        fetchInfo()
                    }
                
                Button {
                    if let clipboardString = NSPasteboard.general.string(forType: .string) {
                        urlInput = clipboardString
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .help(languageService.s("paste_from_clipboard"))
                
                Button {
                    fetchInfo()
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                }
                .disabled(urlInput.isEmpty || isLoading)
                .help(languageService.s("fetch_info"))
            }
        }
    }
    
    // MARK: - Media Info Section
    
    private func mediaInfoSection(_ info: MediaInfo) -> some View {
        HStack(spacing: 16) {
            // Thumbnail
            AsyncImage(url: info.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
            }
            .frame(width: 180, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(info.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if let uploader = info.uploader {
                    Text(uploader)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    if let duration = info.durationString {
                        Label(duration, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let views = info.viewCount {
                        Label(formatNumber(views), systemImage: "eye")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Format Section
    
    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageService.s("format"))
                .font(.headline)
            
            HStack(spacing: 20) {
                Picker(languageService.s("file_type"), selection: $fileType) {
                    ForEach(MediaFileType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                
                if fileType.isVideo {
                    Picker(languageService.s("quality"), selection: $videoResolution) {
                        ForEach(VideoResolution.allCases) { res in
                            Text(res.title(lang: languageService)).tag(res)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }
            }
        }
    }
    
    // MARK: - Save Section
    
    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageService.s("save_folder"))
                .font(.headline)
            
            HStack {
                TextField(languageService.s("save_folder"), text: .constant(saveFolder.path))
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)
                
                Button(languageService.s("select")) {
                    selectFolder()
                }
            }
            
            TextField(languageService.s("custom_filename_hint"), text: $customFilename)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    // MARK: - Extra Options Section
    
    private var extraOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Subtitles
            GroupBox(languageService.s("subtitles")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(languageService.s("download_subtitles"), isOn: $downloadSubtitles)
                    
                    if downloadSubtitles {
                        HStack {
                            Text(languageService.s("languages"))
                            TextField("tr,en,de...", text: $subtitleLanguages)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 150)
                        }
                        
                        if fileType.isVideo {
                            Toggle(languageService.s("embed_video"), isOn: $embedSubtitles)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Thumbnail & Metadata
            GroupBox(languageService.s("embedded_data")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(languageService.s("embed_thumbnail"), isOn: $embedThumbnail)
                    Toggle(languageService.s("metadata_desc"), isOn: $embedMetadata)
                }
                .padding(.vertical, 4)
            }
            
            // Advanced
            GroupBox(languageService.s("advanced")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(languageService.s("split_chapters"), isOn: $splitChapters)
                    Toggle(languageService.s("sponsorblock_hint"), isOn: $sponsorBlock)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Error Section
    
    private func errorSection(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(error)
                .foregroundColor(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Spacer()
            
            Button(languageService.s("cancel")) {
                dismiss()
            }
            .keyboardShortcut(.escape)
            
            Button(languageService.s("download_btn")) {
                startDownload()
            }
            .buttonStyle(.borderedProminent)
            .disabled(mediaInfo == nil)
            .keyboardShortcut(.return)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func fetchInfo() {
        guard !urlInput.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        mediaInfo = nil
        
        Task {
            do {
                let info = try await downloadManager.ytdlpService.fetchInfo(url: urlInput)
                mediaInfo = info
                customFilename = info.title
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func startDownload() {
        let options = DownloadOptions(
            saveFolder: saveFolder,
            fileType: fileType,
            videoResolution: fileType.isVideo ? videoResolution : nil,
            downloadSubtitles: downloadSubtitles,
            subtitleLanguages: subtitleLanguages.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            embedSubtitles: embedSubtitles,
            downloadThumbnail: false,
            embedThumbnail: embedThumbnail,
            embedMetadata: embedMetadata,
            splitChapters: splitChapters,
            sponsorBlock: sponsorBlock,
            customFilename: customFilename.isEmpty ? nil : customFilename
        )
        
        downloadManager.addDownload(url: urlInput, options: options)
        appState.selectedNavItem = .downloading
        dismiss()
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Seç"
        
        if panel.runModal() == .OK, let url = panel.url {
            saveFolder = url
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        
        if number >= 1_000_000_000 {
            return "\(formatter.string(from: NSNumber(value: Double(number) / 1_000_000_000)) ?? "")B"
        } else if number >= 1_000_000 {
            return "\(formatter.string(from: NSNumber(value: Double(number) / 1_000_000)) ?? "")M"
        } else if number >= 1_000 {
            return "\(formatter.string(from: NSNumber(value: Double(number) / 1_000)) ?? "")K"
        }
        return "\(number)"
    }
}

#Preview {
    AddDownloadView()
        .environmentObject(DownloadManager())
        .environmentObject(AppState())
        .environmentObject(LanguageService())
}
