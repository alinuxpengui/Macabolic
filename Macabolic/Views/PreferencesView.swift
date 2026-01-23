import SwiftUI
import AppKit

struct PreferencesView: View {
    @AppStorage("theme") private var theme: String = "system"
    @AppStorage("defaultSaveFolder") private var defaultSaveFolder: String = ""
    @AppStorage("maxConcurrentDownloads") private var maxConcurrentDownloads: Int = 3
    @AppStorage("embedThumbnail") private var embedThumbnail: Bool = true
    @AppStorage("embedMetadata") private var embedMetadata: Bool = true
    @AppStorage("defaultFileType") private var defaultFileType: String = "mp4"
    @AppStorage("defaultVideoResolution") private var defaultVideoResolution: String = "best"
    @AppStorage("defaultVideoCodec") private var defaultVideoCodec: String = "auto"
    @AppStorage("defaultAudioCodec") private var defaultAudioCodec: String = "auto"
    @AppStorage("selectedPreset") private var selectedPreset: String = "max_compatibility"
    @AppStorage("sponsorBlock") private var sponsorBlock: Bool = false
    @AppStorage("browserForCookies") private var browserForCookies: String = "none"
    
    @EnvironmentObject var languageService: LanguageService
    @EnvironmentObject var updateChecker: UpdateChecker
    @State private var isUpdatingYtdlp = false
    @State private var ytdlpUpdateMessage: String?
    @State private var selectedReleaseId: Int? = nil
    @State private var showLanguageChangeAlert = false
    @State private var previousLanguage: Language? = nil
    @State private var installedBrowsers: [SupportedBrowser] = []
    @State private var customPresets: [CustomPreset] = []
    @State private var showCreatePresetSheet = false
    @State private var newPresetName = ""
    @AppStorage("selectedCustomPresetId") private var selectedCustomPresetIdString: String = ""
    
    // Preset form state
    @State private var presetFileType: MediaFileType = .mp4
    @State private var presetVideoResolution: VideoResolution = .r1080p
    @State private var presetVideoCodec: VideoCodec = .h264
    @State private var presetAudioCodec: AudioCodec = .aac
    @State private var presetEmbedSubtitles: Bool = false
    @State private var presetSubtitleLang: String = ""
    @State private var editingPreset: CustomPreset? = nil
    
    private var presetFilteredResolutions: [VideoResolution] {
        if presetVideoCodec == .h264 {
            return VideoResolution.allCases.filter { res in
                res != .best && res != .r2160p && res != .r1440p
            }
        }
        return VideoResolution.allCases
    }
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {

                Spacer()
                    .frame(height: 44)
                
                TabView {
                    generalTab
                        .tabItem {
                            Label(languageService.s("general"), systemImage: "gear")
                        }
                    
                    downloadTab
                        .tabItem {
                            Label(languageService.s("download"), systemImage: "arrow.down.circle")
                        }
                    
                    advancedTab
                        .tabItem {
                            Label(languageService.s("advanced"), systemImage: "wrench.and.screwdriver")
                        }
                    
                    aboutTab
                        .tabItem {
                            Label(languageService.s("about"), systemImage: "info.circle")
                        }
                }
            }
            

            Button {
                dismiss()
            } label: {
                CloseButton()
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .frame(width: 550, height: 450)
        .onChange(of: theme) { newValue in
            applyTheme(newValue)
        }
        .onChange(of: languageService.selectedLanguage) { newValue in
            if previousLanguage != nil && previousLanguage != newValue {
                showLanguageChangeAlert = true
            }
            previousLanguage = newValue
        }
        .onAppear {
            applyTheme(theme)
            previousLanguage = languageService.selectedLanguage
            installedBrowsers = BrowserUtils.shared.getInstalledBrowsers()
            customPresets = CustomPreset.loadAll()
            Task {
                await updateChecker.fetchAllReleases()
            }
        }
        .sheet(isPresented: $showCreatePresetSheet) {
            createPresetSheet
        }
        .alert(languageService.s("update_ready_title"), isPresented: $updateChecker.needsRestart) {
            Button(languageService.s("ok")) {
                updateChecker.needsRestart = false
            }
        } message: {
            Text(languageService.s("update_ready_message"))
        }
        .alert(languageService.s("language_changed_title"), isPresented: $showLanguageChangeAlert) {
            Button(languageService.s("ok")) {
                showLanguageChangeAlert = false
            }
        } message: {
            Text(languageService.s("language_changed_message"))
        }
    }
    

    struct CloseButton: View {
        @State private var isHovering = false
        
        var body: some View {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.black.opacity(0.5))
                        .opacity(isHovering ? 1 : 0)
                )
                .onHover { hovering in
                    isHovering = hovering
                }
        }
    }
    

    
    private func applyTheme(_ theme: String) {
        switch theme {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }
    

    
    private var generalTab: some View {
        Form {
            Section(languageService.s("theme")) {
                Picker(languageService.s("theme"), selection: $theme) {
                    Text(languageService.s("system")).tag("system")
                    Text(languageService.s("light")).tag("light")
                    Text(languageService.s("dark")).tag("dark")
                }
                .pickerStyle(.segmented)
            }
            
            Section(languageService.s("language")) {
                Picker(languageService.s("language"), selection: $languageService.selectedLanguage) {
                    ForEach(Language.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            }
            
            Section(languageService.s("save_folder")) {
                HStack {
                    TextField(languageService.s("save_folder"), text: .constant(defaultSaveFolder.isEmpty ? (languageService.selectedLanguage == .turkish ? "İndirilenler" : "Downloads") : defaultSaveFolder))
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    
                    Button(languageService.s("select")) {
                        selectFolder()
                    }
                    
                    if !defaultSaveFolder.isEmpty {
                        Button {
                            defaultSaveFolder = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Section(languageService.s("updates")) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(languageService.s("app_updates"))
                        if let latestVersion = updateChecker.latestVersion {
                            Text("\(languageService.s("latest")): \(latestVersion)")
                                .font(.caption)
                                .foregroundColor(updateChecker.hasUpdate ? .orange : .green)
                        }
                    }
                    Spacer()
                    if updateChecker.isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if updateChecker.hasUpdate {
                        VStack(alignment: .trailing, spacing: 8) {
                            if updateChecker.isDownloading {
                                HStack {
                                    ProgressView(value: updateChecker.updateProgress)
                                        .controlSize(.small)
                                    Text(languageService.s("downloading_update"))
                                        .font(.caption)
                                }
                                .frame(width: 200)
                            } else if updateChecker.isInstalling {
                                Text(languageService.s("installing_update"))
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else if updateChecker.needsRestart {
                                Text("✅ \(languageService.s("update_ready_title"))")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Button(languageService.s("update_now")) {
                                    Task {
                                        await updateChecker.downloadAndInstallUpdate()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    } else if updateChecker.showUpToDateMessage {
                        Text(languageService.s("app_up_to_date"))
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Button(languageService.s("check_updates")) {
                            Task {
                                await updateChecker.checkForUpdates()
                            }
                        }
                    }
                }
            }
            
            Section(languageService.s("all_versions")) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker(languageService.s("select_version"), selection: $selectedReleaseId) {
                        Text(languageService.s("select")).tag(nil as Int?)
                        ForEach(updateChecker.availableReleases) { release in
                            Text(release.tagName).tag(release.id as Int?)
                        }
                    }
                    
                    if let selectedId = selectedReleaseId,
                       let release = updateChecker.availableReleases.first(where: { $0.id == selectedId }) {
                        HStack {
                            Spacer()
                            Button(languageService.s("install")) {
                                Task {
                                    await updateChecker.installSpecificRelease(release)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    

    
    private var downloadTab: some View {
        Form {
            Section(languageService.s("download_presets")) {
                Picker("", selection: $selectedPreset) {
                    ForEach(DownloadPreset.allCases) { preset in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.title(lang: languageService))
                                    .fontWeight(.medium)
                                Text(preset.description(lang: languageService))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .tag(preset.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .onChange(of: selectedPreset) { newValue in
                    if let preset = DownloadPreset(rawValue: newValue) {
                        selectedCustomPresetIdString = ""
                        applyPreset(preset)
                    }
                }
            }
            
            Section(languageService.s("custom_presets")) {
                if customPresets.isEmpty {
                    Text(languageService.s("no_custom_presets"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(customPresets) { preset in
                        HStack {
                            Button {
                                selectedPreset = ""
                                selectedCustomPresetIdString = preset.id.uuidString
                                applyCustomPreset(preset)
                            } label: {
                                HStack {
                                    Image(systemName: selectedCustomPresetIdString == preset.id.uuidString ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(selectedCustomPresetIdString == preset.id.uuidString ? .accentColor : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(preset.name)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Text("\(preset.videoCodec.title(lang: languageService)) + \(preset.audioCodec.title(lang: languageService)) • \(preset.videoResolution.title(lang: languageService))\(preset.embedSubtitles == true ? " • CC: \(preset.subtitleLanguage ?? "")" : "")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Button {
                                    startEditingPreset(preset)
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.borderless)
                                
                                Button {
                                    deleteCustomPreset(preset)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Button {
                    showCreatePresetSheet = true
                } label: {
                    Label(languageService.s("create_preset"), systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
            
            Section {
                Picker(languageService.s("file_type"), selection: $defaultFileType) {
                    ForEach(MediaFileType.allCases) { type in
                        Text(type.rawValue).tag(type.rawValue.lowercased())
                    }
                }
                
                Picker(languageService.s("video_quality"), selection: $defaultVideoResolution) {
                    ForEach(VideoResolution.allCases) { res in
                        Text(res.title(lang: languageService)).tag(res.rawValue)
                    }
                }
                
                HStack {
                    Spacer()
                    Button {
                        resetFormatToDefaults()
                    } label: {
                        Label(languageService.s("reset_to_defaults"), systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .controlSize(.small)
                }
            } header: {
                Text(languageService.s("format_settings"))
            }
            
            Section(languageService.s("codec_settings")) {
                Picker(languageService.s("preferred_video_codec"), selection: $defaultVideoCodec) {
                    ForEach(VideoCodec.allCases) { codec in
                        Text(codec.title(lang: languageService)).tag(codec.rawValue)
                    }
                }
                
                Picker(languageService.s("preferred_audio_codec"), selection: $defaultAudioCodec) {
                    ForEach(AudioCodec.allCases) { codec in
                        Text(codec.title(lang: languageService)).tag(codec.rawValue)
                    }
                }
                
                Text(languageService.s("codec_fallback_note"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(languageService.s("embed_options")) {
                Toggle(languageService.s("embed_thumbnail"), isOn: $embedThumbnail)
                Toggle(languageService.s("embed_metadata"), isOn: $embedMetadata)
            }
            
            Section(languageService.s("concurrent_downloads")) {
                Stepper("\(languageService.s("max")): \(maxConcurrentDownloads)", value: $maxConcurrentDownloads, in: 1...10)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var createPresetSheet: some View {
        VStack(spacing: 16) {
            Text(editingPreset == nil ? languageService.s("create_preset") : languageService.s("edit_preset"))
                .font(.headline)
            
            TextField(languageService.s("preset_name"), text: $newPresetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 350)
            
            Divider()
            
            Form {
                Section(languageService.s("format_settings")) {
                    Picker(languageService.s("file_type"), selection: $presetFileType) {
                        ForEach(MediaFileType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    if presetFileType.isVideo {
                        Picker(languageService.s("video_quality"), selection: $presetVideoResolution) {
                            ForEach(presetFilteredResolutions) { res in
                                Text(res.title(lang: languageService)).tag(res)
                            }
                        }
                        .onChange(of: presetVideoCodec) { newCodec in
                            if newCodec == .h264 && (presetVideoResolution == .r1440p || presetVideoResolution == .r2160p || presetVideoResolution == .best) {
                                presetVideoResolution = .r1080p
                            }
                        }
                    }
                }
                
                if presetFileType.isVideo {
                    Section(languageService.s("codec_settings")) {
                        Picker(languageService.s("video_codec"), selection: $presetVideoCodec) {
                            ForEach(VideoCodec.allCases) { codec in
                                Text(codec.title(lang: languageService)).tag(codec)
                            }
                        }
                        
                        Picker(languageService.s("audio_codec"), selection: $presetAudioCodec) {
                            ForEach(AudioCodec.allCases) { codec in
                                Text(codec.title(lang: languageService)).tag(codec)
                            }
                        }
                        
                        if presetVideoCodec == .h264 {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text(languageService.s("h264_preset_info"))
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    Section(languageService.s("subtitles")) {
                        Toggle(languageService.s("download_subtitles"), isOn: $presetEmbedSubtitles)
                        
                        if presetEmbedSubtitles {
                            Picker(languageService.s("subtitle_output"), selection: Binding(
                                get: { presetSubtitleLang.hasPrefix("embed:") },
                                set: { isEmbed in
                                    let lang = presetSubtitleLang.replacingOccurrences(of: "embed:", with: "")
                                    presetSubtitleLang = isEmbed ? "embed:\(lang)" : lang
                                }
                            )) {
                                Text(languageService.s("subtitle_external")).tag(false)
                                Text(languageService.s("subtitle_embedded")).tag(true)
                            }
                            .pickerStyle(.segmented)
                            
                            TextField(languageService.s("subtitle_lang_hint"), text: Binding(
                                get: { presetSubtitleLang.replacingOccurrences(of: "embed:", with: "") },
                                set: { newLang in
                                    let isEmbed = presetSubtitleLang.hasPrefix("embed:")
                                    presetSubtitleLang = isEmbed ? "embed:\(newLang)" : newLang
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button(languageService.s("cancel")) {
                    resetPresetForm()
                    editingPreset = nil
                    showCreatePresetSheet = false
                }
                .keyboardShortcut(.escape)
                
                Button(languageService.s("save")) {
                    createCustomPreset()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newPresetName.isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 480)
    }
    
    private func resetPresetForm() {
        newPresetName = ""
        presetFileType = .mp4
        presetVideoResolution = .r1080p
        presetVideoCodec = .h264
        presetAudioCodec = .aac
        presetEmbedSubtitles = false
        presetSubtitleLang = ""
    }
    
    private func startEditingPreset(_ preset: CustomPreset) {
        editingPreset = preset
        newPresetName = preset.name
        presetFileType = preset.fileType
        presetVideoResolution = preset.videoResolution
        presetVideoCodec = preset.videoCodec
        presetAudioCodec = preset.audioCodec
        presetEmbedSubtitles = preset.embedSubtitles ?? false
        presetSubtitleLang = preset.subtitleLanguage ?? ""
        showCreatePresetSheet = true
    }
    
    private func applyPreset(_ preset: DownloadPreset) {
        defaultVideoCodec = preset.videoCodec.rawValue
        defaultAudioCodec = preset.audioCodec.rawValue
        defaultVideoResolution = preset.videoResolution.rawValue
        defaultFileType = preset.fileType.rawValue.lowercased()
    }
    
    private func applyCustomPreset(_ preset: CustomPreset) {
        defaultVideoCodec = preset.videoCodec.rawValue
        defaultAudioCodec = preset.audioCodec.rawValue
        defaultVideoResolution = preset.videoResolution.rawValue
        defaultFileType = preset.fileType.rawValue.lowercased()
    }
    
    private func createCustomPreset() {
        if let editing = editingPreset {
            if let index = customPresets.firstIndex(where: { $0.id == editing.id }) {
                customPresets[index].name = newPresetName
                customPresets[index].fileType = presetFileType
                customPresets[index].videoResolution = presetVideoResolution
                customPresets[index].videoCodec = presetVideoCodec
                customPresets[index].audioCodec = presetAudioCodec
                customPresets[index].embedSubtitles = presetEmbedSubtitles
                customPresets[index].subtitleLanguage = presetSubtitleLang
            }
            editingPreset = nil
        } else {
            let preset = CustomPreset(
                name: newPresetName,
                videoCodec: presetVideoCodec,
                audioCodec: presetAudioCodec,
                videoResolution: presetVideoResolution,
                fileType: presetFileType,
                embedSubtitles: presetEmbedSubtitles,
                subtitleLanguage: presetSubtitleLang
            )
            customPresets.append(preset)
        }
        
        CustomPreset.saveAll(customPresets)
        resetPresetForm()
        showCreatePresetSheet = false
    }
    
    private func deleteCustomPreset(_ preset: CustomPreset) {
        customPresets.removeAll { $0.id == preset.id }
        CustomPreset.saveAll(customPresets)
    }
    
    private func resetFormatToDefaults() {
        defaultFileType = "mp4"
        defaultVideoResolution = "best"
        defaultVideoCodec = "auto"
        defaultAudioCodec = "auto"
    }
    

    
    private var advancedTab: some View {
        Form {
            Section("SponsorBlock") {
                Toggle(languageService.s("sponsorblock_desc"), isOn: $sponsorBlock)
            }
            
            Section("yt-dlp") {
                HStack {
                    VStack(alignment: .leading) {
                        Text(languageService.s("ytdlp_update"))
                        if let message = ytdlpUpdateMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if isUpdatingYtdlp {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(languageService.s("downloading_ytdlp"))
                            .font(.caption)
                    } else {
                        Button(languageService.s("update_now")) {
                            updateYtdlp()
                        }
                    }
                }
            }
            
            Section(languageService.s("browser_cookies")) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: $browserForCookies) {
                        Text(languageService.s("none")).tag("none")
                        ForEach(installedBrowsers) { browser in
                            Text(browser.displayName).tag(browser.id)
                        }
                    }
                    .labelsHidden()
                    
                    Text(languageService.s("browser_hint"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if browserForCookies == "safari" {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(languageService.s("safari_warning"))
                                .font(.caption)
                                .foregroundColor(.orange)
                                .fixedSize(horizontal: false, vertical: true) // Ensure text wraps and doesn't truncate
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button(languageService.s("open_system_settings")) {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    

    
    private var aboutTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                Text("Macabolic")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(languageService.s("version") + " \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(languageService.s("app_desc"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Divider()
                    .padding(.horizontal, 40)
                

                GroupBox(languageService.s("credits")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(languageService.s("original_project") + ":")
                            Spacer()
                            Link("Parabolic by Nickvision", destination: URL(string: "https://github.com/NickvisionApps/Parabolic")!)
                                .font(.caption)
                        }
                        HStack {
                            Text(languageService.s("macos_port") + ":")
                            Spacer()
                            Text("alinuxpengui")
                                .font(.caption)
                        }
                        HStack {
                            Text(languageService.s("video_downloading") + ":")
                            Spacer()
                            Link("yt-dlp", destination: URL(string: "https://github.com/yt-dlp/yt-dlp")!)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, 20)
                

                GroupBox(languageService.s("legal_disclaimer_title")) {
                    Text(languageService.s("legal_disclaimer_message"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 4)
                }
                .padding(.horizontal, 20)
                
                GroupBox(languageService.s("license")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GNU General Public License v3.0")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(languageService.s("license_desc"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Link(languageService.s("view_license"), destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, 20)
                
                HStack(spacing: 16) {
                    Link(destination: URL(string: "https://github.com/alinuxpengui/Macabolic")!) {
                        Label("GitHub", systemImage: "link")
                    }
                    Link(destination: URL(string: "https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md")!) {
                        Label(languageService.s("supported_sites"), systemImage: "globe")
                    }
                }
                .font(.caption)
                
                Text("© 2026 alinuxpengui")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
    

    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Seç"
        
        if panel.runModal() == .OK, let url = panel.url {
            defaultSaveFolder = url.path
        }
    }
    
    private func updateYtdlp() {
        isUpdatingYtdlp = true
        ytdlpUpdateMessage = nil
        
        Task {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let macabolicDir = appSupport.appendingPathComponent("Macabolic")
            let destination = macabolicDir.appendingPathComponent("yt-dlp")
            
            do {
                try FileManager.default.createDirectory(at: macabolicDir, withIntermediateDirectories: true)
                
                let downloadURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
                let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
                
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                
                try FileManager.default.moveItem(at: tempURL, to: destination)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
                
                await MainActor.run {
                    ytdlpUpdateMessage = languageService.s("update_complete")
                    isUpdatingYtdlp = false
                }
            } catch {
                await MainActor.run {
                    ytdlpUpdateMessage = languageService.s("update_error") + " \(error.localizedDescription)"
                    isUpdatingYtdlp = false
                }
            }
        }
    }
}



#Preview {
    PreferencesView()
}

enum SupportedBrowser: String, CaseIterable, Identifiable {
    case chrome = "chrome"
    case firefox = "firefox"
    case opera = "opera"
    case edge = "edge"
    case brave = "brave"
    case vivaldi = "vivaldi"
    case safari = "safari"
    case chromium = "chromium"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .chrome: return "Google Chrome"
        case .firefox: return "Mozilla Firefox"
        case .opera: return "Opera"
        case .edge: return "Microsoft Edge"
        case .brave: return "Brave"
        case .vivaldi: return "Vivaldi"
        case .safari: return "Safari"
        case .chromium: return "Chromium"
        }
    }
    
    var bundleIdentifier: String {
        switch self {
        case .chrome: return "com.google.Chrome"
        case .firefox: return "org.mozilla.firefox"
        case .opera: return "com.operasoftware.Opera"
        case .edge: return "com.microsoft.edgemac"
        case .brave: return "com.brave.Browser"
        case .vivaldi: return "com.vivaldi.Vivaldi"
        case .safari: return "com.apple.Safari"
        case .chromium: return "org.chromium.Chromium"
        }
    }
}

class BrowserUtils {
    static let shared = BrowserUtils()
    
    func getInstalledBrowsers() -> [SupportedBrowser] {
        let workspace = NSWorkspace.shared
        var installed: [SupportedBrowser] = []
        
        for browser in SupportedBrowser.allCases {
            if let _ = workspace.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) {
                installed.append(browser)
            }
        }
        
        return installed
    }
}
