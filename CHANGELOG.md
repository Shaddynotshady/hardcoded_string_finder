# Changelog

## 1.0.0 - 2024

### 🚀 Initial Release

#### Core Features

- Automatic hardcoded string detection in Flutter/Dart projects
- JSON and CSV export with 70+ language support
- Translation preservation feature (smart merge)
- Smart filtering for URLs, numbers, and already localized strings
- Auto key generation (snake_case)
- Detects already localized strings (.tr, .i18n, AppString.)

#### 🎯 Performance & Reliability

- **Memory Efficient**: Stream-based file processing for large codebases
- **Progress Tracking**: Real-time progress indicators showing:
  - File collection progress
  - Scanning progress (every 10 files)
  - String count updates
  - Export progress with file sizes
- **Timeout Handling**: 5-minute default timeout prevents hanging on large projects
- **Error Handling**:
  - Graceful error recovery
  - Custom exceptions (ScanException, DirectoryNotFoundException, ExportException)
  - Detailed error messages with stack traces
  - Stops after 10 consecutive errors to prevent cascading failures
- **Large File Protection**: Automatically skips files >1MB with warning
- **Memory Monitoring**: Cross-platform memory usage tracking (Windows, macOS, Linux)

#### 🛠️ Technical Improvements

- Async file operations for better performance
- Non-blocking directory traversal
- Efficient regex pattern matching
- Smart CSV parsing with quote handling
- Relative path display for cleaner output
- Fixed all linter warnings

#### 📊 User Experience

- Interactive CLI with smart defaults
- **Command-line options**:
  - `--memory` / `-m` flag to enable memory monitoring
  - `--timeout=<minutes>` to set custom timeout
  - `--help` / `-h` to show usage information
- Existing folder detection and management
- Three merge strategies (Smart Merge, New Version, Overwrite)
- Format selection (JSON, CSV, or both)
- Key format options (snake_case or readable)
- Comprehensive progress feedback
- Optional memory usage reporting (enabled with `--memory` flag)

### What Makes This Production-Ready

✅ Handles large codebases efficiently  
✅ Won't hang or crash on edge cases  
✅ Clear progress feedback for long operations  
✅ Preserves existing translation work  
✅ Comprehensive error handling  
✅ Cross-platform compatibility  
✅ Memory-conscious design
