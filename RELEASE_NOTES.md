# Macabolic v2.4.0 Release Notes

## ⚠️ Important Notice
Significant structural changes have been made to the application's core to support macOS 12 Monterey. If you experience any unexpected behavior, please go to Settings -> General -> All Versions to downgrade to a previous stable release.

## ✨ New Features
- **Advanced Custom Presets**: You can now save SponsorBlock (skip ads) and Split Chapters settings directly into your custom presets.
- **Rich Video Metadata**: Video descriptions, upload dates, and chapter markers are now automatically embedded into your downloads by default.
- **Enhanced Subtitles**: Added support for language wildcards (e.g., en.*) and fixed a logic error where preset subtitle settings were not being applied correctly.
- **Community Recognition**: A special thanks section has been added to the "About" tab to honor Neonapple for their incredible feedback and contributions.

## 🛠 Infrastructure & Performance
- **macOS Monterey Support**: Macabolic is now fully compatible with macOS 12 Monterey and later versions.
- **Smarter File Cleanup**: Improved temporary file removal logic using Video ID tracking, ensuring no .part or .ytdl files are left behind.
- **Advanced Debugging**: The full yt-dlp command is now logged at the start of every download, making it easier to troubleshoot issues.
- **Hybrid Navigation System**: A new, flexible navigation architecture has been implemented to ensure smooth performance across different macOS versions.
- **Code Optimization**: The settings architecture has been modularized for better stability, faster performance, and more reliable builds.

# Macabolic v2.2.0 Release Notes

## 🍪 Browser Cookie Support
Added ability to import cookies from browsers (Chrome, Firefox, Safari, Edge, etc.) to bypass YouTube's bot detection and rate limiting.
- **New Feature**: "Browser Cookies" section in Preferences.
- **Improved**: Significantly better success rate for downloading restricted or age-gated videos.

## 🎨 Advanced Format & Preset System
- **Custom Presets**: Users can now create, save, and manage their own download presets.
- **Codec Selection**: Integrated Video (H.264, AV1, VP9) and Audio (AAC, MP3, Opus) codec preferences into the preset system.
- **Default Presets**: Added quick presets for "Best Quality", "Max Compatibility", and "Smallest Size".

## 🛠️ Improvements & Fixes
- **Removed**: Keyring (Password Manager) has been removed to simplify the app focus.
- **UI**: Fixed capitalization for video format names in the UI.
- **UX**: The "Play" button now correctly opens the downloaded file in your system's default media player.
- **Core**: Updated `yt-dlp` integration to support cookie passing and advanced codec selection.
