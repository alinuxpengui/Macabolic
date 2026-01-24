# Macabolic v2.4.1 Release Notes

## ⚠️ Important Notice
Significant structural changes have been made to the application's core to support macOS 12 Monterey. If you experience any unexpected behavior, please go to Settings -> General -> All Versions to downgrade to a previous stable release.

## ✨ New Features
- **Power User Control**: Added an 'Additional Arguments' field to pass custom commands directly to yt-dlp, with a link to official documentation.
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
