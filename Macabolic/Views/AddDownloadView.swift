import SwiftUI

struct AddDownloadView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedPreset") private var selectedPreset: String = "max_compatibility"
    @AppStorage("selectedCustomPresetId") private var selectedCustomPresetIdString: String = ""
    
    @State private var urlInput: String = ""
    @State private var isLoading: Bool = false
    @State private var mediaInfo: MediaInfo?
    @State private var errorMessage: String?
    

    @State private var saveFolder: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    @State private var fileType: MediaFileType = .mp4
    @State private var videoResolution: VideoResolution = .best
    @State private var audioQuality: AudioQuality = .best
    @State private var customFilename: String = ""
    @State private var isVideoTab: Bool = true
    @State private var availableCodecs: [CodecOption] = []
    @State private var selectedCodec: String = "auto"
    @State private var selectedAudioCodec: String = "auto"
    @State private var customPresets: [CustomPreset] = []
    @State private var selectedPresetName: String? = nil
    @State private var presetSubtitleLanguage: String = ""
    

    @State private var downloadSubtitles: Bool = false
    @State private var selectedSubtitleLangs: Set<String> = []
    @State private var availableSubtitles: [SubtitleOption] = []
    @State private var embedSubtitles: Bool = true
    @State private var embedThumbnail: Bool = true
    @State private var embedMetadata: Bool = true
    @State private var splitChapters: Bool = false
    @State private var sponsorBlock: Bool = false
    
    @State private var showAdvancedOptions: Bool = false
    
    @State private var playlistItems: [MediaInfo] = []
    @State private var selectedPlaylistIds: Set<String> = []
    @State private var isLoadingPlaylist: Bool = false
    @State private var showPlaylistSelector: Bool = false
    @State private var downloadMode: DownloadMode = .single

    enum DownloadMode {
        case single, playlist
    }
    
    struct SubtitleOption: Identifiable, Hashable {
        let id: String
        let name: String
        let isAuto: Bool
    }
    
    struct CodecOption: Identifiable, Hashable {
        let id: String
        let name: String
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    urlSection
                    
                    if let info = mediaInfo {
                        if !showPlaylistSelector {
                            mediaInfoSection(info)
                            
                            if info.playlist != nil {
                                playlistDetectedBanner
                            }
                        } else {
                            playlistSelectorSection
                        }
                        
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
            footer
        }
        .frame(width: 600, height: 750)
        .onAppear {
            customPresets = CustomPreset.loadAll()
            
            // Check if custom preset is selected
            if let customPresetId = UUID(uuidString: selectedCustomPresetIdString),
               let customPreset = customPresets.first(where: { $0.id == customPresetId }) {
                // Apply custom preset
                videoResolution = customPreset.videoResolution
                selectedCodec = customPreset.videoCodec.rawValue
                selectedAudioCodec = customPreset.audioCodec.rawValue
                isVideoTab = customPreset.fileType.isVideo
                selectedPresetName = customPreset.name
                downloadSubtitles = customPreset.embedSubtitles ?? false
                embedSubtitles = customPreset.embedSubtitles ?? false
                presetSubtitleLanguage = customPreset.subtitleLanguage ?? ""
            } else if let preset = DownloadPreset(rawValue: selectedPreset) {
                // Apply built-in preset
                fileType = preset.fileType
                videoResolution = preset.videoResolution
                selectedCodec = preset.videoCodec.rawValue
                selectedAudioCodec = preset.audioCodec.rawValue
                isVideoTab = preset.fileType.isVideo
                selectedPresetName = preset.title(lang: languageService)
                
                // Subtitles off by default for built-in
                downloadSubtitles = false
                embedSubtitles = false
                presetSubtitleLanguage = ""
            }
            
            if let clipboardString = NSPasteboard.general.string(forType: .string),
               clipboardString.hasPrefix("http") {
                urlInput = clipboardString
            }
            
            if !appState.urlToDownload.isEmpty {
                urlInput = appState.urlToDownload
                appState.urlToDownload = ""
            }
        }
        .onChange(of: urlInput) { newValue in
            if newValue.hasPrefix("http") && mediaInfo == nil && !isLoading {
                fetchInfo()
            }
        }
    }
    
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
    
    private func mediaInfoSection(_ info: MediaInfo) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: info.thumbnailURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.2))
                    .overlay { Image(systemName: "photo").font(.largeTitle).foregroundColor(.gray) }
            }
            .frame(width: 180, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(info.title).font(.headline).lineLimit(2)
                if let uploader = info.uploader {
                    Text(uploader).font(.subheadline).foregroundColor(.secondary)
                }
                HStack(spacing: 12) {
                    if let duration = info.durationString {
                        Label(duration, systemImage: "clock").font(.caption).foregroundColor(.secondary)
                    }
                    if let views = info.viewCount {
                        Label(formatNumber(views), systemImage: "eye").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private var playlistDetectedBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(languageService.s("playlist_detected")).font(.headline)
                Text(languageService.s("entire_playlist")).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            if isLoadingPlaylist {
                ProgressView().scaleEffect(0.7)
            } else {
                Button(languageService.s("load_playlist")) { loadPlaylist() }.buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }

    private var playlistSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(languageService.s("entire_playlist")).font(.headline)
                Spacer()
                Button(languageService.s("single_video")) {
                    showPlaylistSelector = false
                    downloadMode = .single
                }
                .buttonStyle(.link)
            }
            
            HStack(spacing: 12) {
                Button(languageService.s("select_all")) { selectedPlaylistIds = Set(playlistItems.map { $0.id }) }
                    .buttonStyle(.plain).foregroundColor(.blue)
                Button(languageService.s("deselect_all")) { selectedPlaylistIds.removeAll() }
                    .buttonStyle(.plain).foregroundColor(.blue)
                Spacer()
                Text("\(selectedPlaylistIds.count) / \(playlistItems.count)").font(.caption).foregroundColor(.secondary)
            }
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(playlistItems, id: \.id) { item in
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { selectedPlaylistIds.contains(item.id) },
                                set: { isSelected in
                                    if isSelected { selectedPlaylistIds.insert(item.id) }
                                    else { selectedPlaylistIds.remove(item.id) }
                                }
                            )).toggleStyle(.checkbox)
                            
                            AsyncImage(url: item.thumbnailURL) { image in image.resizable().aspectRatio(contentMode: .fill) }
                            placeholder: { Rectangle().fill(Color.gray.opacity(0.2)) }
                            .frame(width: 50, height: 30).cornerRadius(4)
                            
                            VStack(alignment: .leading) {
                                Text(item.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                if let duration = item.durationString {
                                    Text(duration).font(.system(size: 11)).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(8).background(Color.gray.opacity(0.05)).cornerRadius(8)
                    }
                }
            }
            .frame(height: 250)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(languageService.s("format")).font(.headline)
                Spacer()
                
                Menu {
                    Section(languageService.s("download_presets")) {
                        ForEach(DownloadPreset.allCases) { preset in
                            Button {
                                applyPreset(preset)
                                selectedPresetName = preset.title(lang: languageService)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(preset.title(lang: languageService))
                                        Text(preset.description(lang: languageService))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if selectedPresetName == preset.title(lang: languageService) {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    
                    if !customPresets.isEmpty {
                        Divider()
                        Section(languageService.s("custom_presets")) {
                            ForEach(customPresets) { preset in
                                Button {
                                    applyCustomPreset(preset)
                                    selectedPresetName = preset.name
                                } label: {
                                    HStack {
                                        Text(preset.name)
                                        if selectedPresetName == preset.name {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        if let presetName = selectedPresetName {
                            Text("\(languageService.s("quick_presets")) (\(presetName))")
                        } else {
                            Text(languageService.s("quick_presets"))
                        }
                    }
                    .font(.caption)
                }
                .menuStyle(.borderlessButton)
            }
            
            Picker("", selection: $isVideoTab) {
                Text(languageService.s("video")).tag(true)
                Text(languageService.s("audio")).tag(false)
            }
            .pickerStyle(.segmented)
            .onChange(of: isVideoTab) { isVideo in
                if isVideo { fileType = .mp4 } else { fileType = .mp3 }
            }
            
            HStack(spacing: 24) {
                Picker(languageService.s("file_type"), selection: $fileType) {
                    if isVideoTab { ForEach(MediaFileType.videoTypes) { type in Text(type.rawValue).tag(type) } }
                    else { ForEach(MediaFileType.audioTypes) { type in Text(type.rawValue).tag(type) } }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 200, alignment: .leading)
                
                if isVideoTab {
                    Picker(languageService.s("quality"), selection: $videoResolution) {
                        ForEach(VideoResolution.allCases) { res in Text(res.title(lang: languageService)).tag(res) }
                    }
                    .pickerStyle(.menu).frame(minWidth: 220, alignment: .leading)
                } else {
                    Picker(languageService.s("audio_quality"), selection: $audioQuality) {
                        ForEach(AudioQuality.allCases) { quality in Text(quality.title(lang: languageService)).tag(quality) }
                    }
                    .pickerStyle(.menu).frame(minWidth: 220, alignment: .leading)
                }
            }
            
            if isVideoTab {
                HStack(spacing: 24) {
                    Picker(languageService.s("video_codec"), selection: $selectedCodec) {
                        Text(languageService.s("codec_auto")).tag("auto")
                        ForEach(availableCodecs) { codec in
                            Text(codec.name).tag(codec.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 200, alignment: .leading)
                    
                    Picker(languageService.s("audio_codec"), selection: $selectedAudioCodec) {
                        ForEach(AudioCodec.allCases) { codec in
                            Text(codec.title(lang: languageService)).tag(codec.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 200, alignment: .leading)
                }
            }
            
            if isVideoTab && (videoResolution == .r1440p || videoResolution == .r2160p || videoResolution == .best) {
                HStack {
                    Image(systemName: "info.circle")
                    Text(languageService.s("codec_warning"))
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
        }
    }
    
    private func applyPreset(_ preset: DownloadPreset) {
        selectedCodec = preset.videoCodec.rawValue
        selectedAudioCodec = preset.audioCodec.rawValue
        videoResolution = preset.videoResolution
        fileType = preset.fileType
        isVideoTab = preset.fileType.isVideo
        
        // Reset subtitles for built-in presets
        downloadSubtitles = false
        embedSubtitles = false
        selectedSubtitleLangs.removeAll()
        presetSubtitleLanguage = ""
    }
    
    private func applyCustomPreset(_ preset: CustomPreset) {
        selectedCodec = preset.videoCodec.rawValue
        selectedAudioCodec = preset.audioCodec.rawValue
        videoResolution = preset.videoResolution
        fileType = preset.fileType
        isVideoTab = preset.fileType.isVideo
        downloadSubtitles = preset.embedSubtitles ?? false
        embedSubtitles = preset.embedSubtitles ?? false
        presetSubtitleLanguage = preset.subtitleLanguage ?? ""
        
        // If info already loaded, try to apply language
        if !presetSubtitleLanguage.isEmpty && !availableSubtitles.isEmpty {
            if availableSubtitles.contains(where: { $0.id == presetSubtitleLanguage }) {
                selectedSubtitleLangs = [presetSubtitleLanguage]
            }
        }
    }

    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageService.s("save_folder")).font(.headline)
            HStack {
                TextField(languageService.s("save_folder"), text: .constant(saveFolder.path)).textFieldStyle(.roundedBorder).disabled(true)
                Button(languageService.s("select")) { selectFolder() }
            }
            TextField(languageService.s("custom_filename_hint"), text: $customFilename).textFieldStyle(.roundedBorder)
        }
    }

    private var extraOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isVideoTab {
                GroupBox(languageService.s("subtitles")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(languageService.s("download_subtitles"), isOn: $downloadSubtitles)
                            .disabled(availableSubtitles.isEmpty)
                        
                        if availableSubtitles.isEmpty && mediaInfo != nil {
                            Text(languageService.s("no_subtitles"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if downloadSubtitles {
                                Menu {
                                    let manualSubs = availableSubtitles.filter { !$0.isAuto }.sorted(by: { $0.name < $1.name })
                                    let autoSubs = availableSubtitles.filter { $0.isAuto }.sorted(by: { $0.name < $1.name })
                                    
                                    if !manualSubs.isEmpty {
                                        Section(header: Text(languageService.s("internal"))) {
                                            ForEach(manualSubs) { sub in
                                                Button {
                                                    toggleSubtitle(sub.id)
                                                } label: {
                                                    HStack {
                                                        if selectedSubtitleLangs.contains(sub.id) {
                                                            Image(systemName: "checkmark")
                                                        }
                                                        Text(sub.name)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    if !autoSubs.isEmpty {
                                        Section(header: Text(languageService.s("auto_subs"))) {
                                            ForEach(autoSubs) { sub in
                                                Button {
                                                    toggleSubtitle(sub.id)
                                                } label: {
                                                    HStack {
                                                        if selectedSubtitleLangs.contains(sub.id) {
                                                            Image(systemName: "checkmark")
                                                        }
                                                        Text("\(sub.name) [Auto]")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
 label: {
                                    HStack {
                                        Text(languageService.s("languages"))
                                        Spacer()
                                        if selectedSubtitleLangs.isEmpty {
                                            Text(languageService.s("select"))
                                        } else {
                                            Text(String(format: languageService.s("subtitles_selected"), selectedSubtitleLangs.count))
                                        }
                                    }
                                }
                                .menuStyle(.borderedButton)
                            Toggle(languageService.s("embed_video"), isOn: $embedSubtitles)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            GroupBox(languageService.s("embedded_data")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(languageService.s("embed_thumbnail"), isOn: $embedThumbnail)
                    Toggle(languageService.s("metadata_desc"), isOn: $embedMetadata)
                }
                .padding(.vertical, 4)
            }
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

    private func errorSection(_ error: String) -> some View {
        HStack { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red); Text(error).foregroundColor(.red) }
        .padding().background(Color.red.opacity(0.1)).cornerRadius(8)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(languageService.s("cancel")) { dismiss() }.keyboardShortcut(.escape)
            
            let downloadTitle = downloadMode == .playlist ? 
                String(format: languageService.s("download_selected"), selectedPlaylistIds.count) : 
                languageService.s("download_btn")
            
            Button(downloadTitle) { startDownload() }
            .buttonStyle(.borderedProminent)
            .disabled(mediaInfo == nil || (downloadMode == .playlist && selectedPlaylistIds.isEmpty))
            .keyboardShortcut(.return)
        }
        .padding()
    }

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
                
                var subs: [SubtitleOption] = []
                var foundLangs: Set<String> = []
                
                if let manual = info.subtitles {
                    for key in manual.keys {
                        if !foundLangs.contains(key) {
                            let name = manual[key]?.first?.name ?? key
                            subs.append(SubtitleOption(id: key, name: name, isAuto: false))
                            foundLangs.insert(key)
                        }
                    }
                }
                
                if let auto = info.automaticCaptions {
                    for key in auto.keys {
                        if !foundLangs.contains(key) {
                            let name = auto[key]?.first?.name ?? key
                            subs.append(SubtitleOption(id: key, name: name, isAuto: true))
                            foundLangs.insert(key)
                        }
                    }
                }
                
                availableSubtitles = subs
                selectedSubtitleLangs.removeAll()
                
                // Extract Codecs
                var codecs: Set<String> = []
                var codecOptions: [CodecOption] = []
                
                if let formats = info.formats {
                    for format in formats {
                        if let vcodec = format.vcodec, vcodec != "none" {
                            if vcodec.hasPrefix("avc1") {
                                if !codecs.contains("h264") {
                                    codecs.insert("h264")
                                    codecOptions.append(CodecOption(id: "h264", name: "H.264"))
                                }
                            } else if vcodec.hasPrefix("vp9") {
                                if !codecs.contains("vp9") {
                                    codecs.insert("vp9")
                                    codecOptions.append(CodecOption(id: "vp9", name: "VP9"))
                                }
                            } else if vcodec.hasPrefix("av01") {
                                if !codecs.contains("av1") {
                                    codecs.insert("av1")
                                    codecOptions.append(CodecOption(id: "av1", name: "AV1"))
                                }
                            } else if vcodec.hasPrefix("hev1") || vcodec.hasPrefix("hvc1") {
                                if !codecs.contains("h265") {
                                    codecs.insert("h265")
                                    codecOptions.append(CodecOption(id: "h265", name: "H.265 (HEVC)"))
                                }
                            }
                        }
                    }
                }
                availableCodecs = codecOptions.sorted(by: { $0.name < $1.name })
                // Don't reset selectedCodec here - preserve preset selection
                availableSubtitles = subs
                
                if !presetSubtitleLanguage.isEmpty {
                    if foundLangs.contains(presetSubtitleLanguage) {
                        selectedSubtitleLangs = [presetSubtitleLanguage]
                    } else {
                        selectedSubtitleLangs.removeAll()
                    }
                } else {
                    selectedSubtitleLangs.removeAll()
                }
                
            } catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }

    private func loadPlaylist() {
        isLoadingPlaylist = true
        errorMessage = nil
        Task {
            do {
                let items = try await downloadManager.ytdlpService.fetchPlaylistInfo(url: urlInput)
                playlistItems = items
                selectedPlaylistIds = Set(items.map { $0.id })
                showPlaylistSelector = true
                downloadMode = .playlist
            } catch { errorMessage = error.localizedDescription }
            isLoadingPlaylist = false
        }
    }

    private func startDownload() {
        let videoCodecEnum: VideoCodec? = {
            if !isVideoTab || selectedCodec == "auto" {
                return nil
            }
            return VideoCodec(rawValue: selectedCodec)
        }()
        
        let audioCodecEnum: AudioCodec? = {
            if !isVideoTab || selectedAudioCodec == "auto" {
                return nil
            }
            return AudioCodec(rawValue: selectedAudioCodec)
        }()
        
        let options = DownloadOptions(
            saveFolder: saveFolder,
            fileType: fileType,
            videoResolution: isVideoTab ? videoResolution : nil,
            audioQuality: isVideoTab ? nil : audioQuality,
            downloadSubtitles: isVideoTab ? downloadSubtitles : false,
            subtitleLanguages: Array(selectedSubtitleLangs),
            embedSubtitles: isVideoTab ? embedSubtitles : false,
            downloadThumbnail: false,
            embedThumbnail: embedThumbnail,
            embedMetadata: embedMetadata,
            splitChapters: splitChapters,
            sponsorBlock: sponsorBlock,
            customFilename: customFilename.isEmpty ? nil : customFilename,
            videoCodec: videoCodecEnum,
            audioCodec: audioCodecEnum
        )
        
        if downloadMode == .single {
            downloadManager.addDownload(url: urlInput, options: options)
        } else {
            let selectedItems = playlistItems.filter { selectedPlaylistIds.contains($0.id) }
            for item in selectedItems {
                let videoUrl = "https://www.youtube.com/watch?v=\(item.id)"
                var itemOptions = options
                itemOptions.customFilename = nil 
                downloadManager.addDownload(url: videoUrl, options: itemOptions)
            }
        }
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
        if panel.runModal() == .OK, let url = panel.url { saveFolder = url }
    }
    
    private func toggleSubtitle(_ id: String) {
        if selectedSubtitleLangs.contains(id) {
            selectedSubtitleLangs.remove(id)
        } else {
            selectedSubtitleLangs.insert(id)
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        if number >= 1_000_000_000 { return "\(formatter.string(from: NSNumber(value: Double(number) / 1_000_000_000)) ?? "")B" }
        else if number >= 1_000_000 { return "\(formatter.string(from: NSNumber(value: Double(number) / 1_000_000)) ?? "")M" }
        else if number >= 1_000 { return "\(formatter.string(from: NSNumber(value: Double(number) / 1_000)) ?? "")K" }
        return "\(number)"
    }
}

#Preview {
    AddDownloadView()
        .environmentObject(DownloadManager())
        .environmentObject(AppState())
        .environmentObject(LanguageService())
}
