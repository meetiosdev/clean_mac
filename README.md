# Mac Cleaner - Unified Junk & System Data Cleaner

A comprehensive, optimized bash script to clean all junk, caches, and system data on macOS. Works on any Mac - uses generic paths with no hardcoded usernames.

## 🚀 Quick Start

### Option 1: Double-Click (Easiest)
1. Double-click `Clean Mac.command`
2. Enter your password when prompted (for system files)
3. Done!

### Option 2: Terminal
```bash
./mac_cleaner.sh
```

### Optional: Analyze First
Want to see what's taking up space before cleaning?
```bash
python3 find_system_data.py
```
This will show you a detailed breakdown of where your System Data is located.

## ✨ Features

### What It Cleans

1. **Xcode & Development Files** (~74 GB typical)
   - DerivedData (build artifacts)
   - iOS DeviceSupport (old device symbols)
   - CoreSimulator Caches
   - Archives (old app archives)
   - DocumentationCache
   - Swift Package Manager cache

2. **Browser & App Caches**
   - Chrome cache
   - Safari cache
   - Slack cache
   - VS Code cache
   - CocoaPods cache

3. **System Caches & Logs**
   - User Library caches
   - User Library logs
   - System Library caches
   - System logs

4. **Temporary Files**
   - System temp directory
   - User temp files

5. **Virtual Memory Swap**
   - Swap files (regenerated automatically)

6. **Time Machine Local Snapshots**
   - Thins snapshots (keeps 4 most recent)

7. **Installer Files**
   - DMG files in Downloads
   - PKG files in Downloads

8. **Homebrew**
   - Old package caches
   - Unused packages

9. **Additional Caches**
   - npm cache
   - Yarn cache
   - Python pip cache

## 📋 Requirements

- macOS (any version)
- Administrator password (for system files)
- No additional software needed

## 🔒 Safety

- **Safe to run**: Only removes caches and temporary files
- **Moves to Trash**: All deleted files/folders are moved to Trash (not permanently deleted)
- **Recoverable**: You can review and restore items from Trash before emptying
- **No data loss**: Doesn't touch user documents, photos, or applications
- **Regenerates**: Caches will be recreated automatically when needed
- **SIP-protected files**: Automatically skipped (won't cause errors)
- **System files**: Some system files (like swap files) are deleted as they regenerate automatically

## ⚡ Performance

- **Fast**: Optimized for speed
- **Efficient**: Uses `du` for accurate size calculations
- **Non-blocking**: Continues even if some files can't be deleted

## 📊 Expected Results

Typical space freed:
- **Xcode users**: 50-100 GB
- **Regular users**: 5-20 GB
- **Heavy developers**: 100+ GB

## 🛠️ Troubleshooting

### "Permission Denied" Errors
- Some system files are protected by System Integrity Protection (SIP)
- This is normal - the script will skip them automatically
- You'll still free significant space from other locations

### Script Won't Run
```bash
chmod +x mac_cleaner.sh
./mac_cleaner.sh
```

### No Space Freed
- Your Mac may already be clean
- Some directories might not exist (normal if you don't use those apps)

## 📝 What Gets Deleted

### ✅ Safe to Delete (Regenerated Automatically)
- All caches
- Temporary files
- Log files
- Build artifacts
- Old archives
- Installer files

### ❌ Never Deleted
- User documents
- Photos
- Applications
- System files (protected)
- User data

## 🔄 How It Works

1. Scans all common cache and junk locations
2. Calculates size before cleaning
3. Removes contents (keeps directories)
4. Calculates total space freed
5. Shows results

## 📦 Installation

No installation needed! Just:
1. Download the files
2. Make executable: `chmod +x mac_cleaner.sh`
3. Run: `./mac_cleaner.sh`

Or double-click `Clean Mac.command`

## 🌐 Compatibility

- ✅ macOS 10.12+
- ✅ Intel Macs
- ✅ Apple Silicon Macs
- ✅ Any user account
- ✅ Works on any Mac (no hardcoded paths)

## 💡 Tips

- **Run regularly**: Monthly cleanup keeps your Mac fast
- **Before updates**: Clean before major macOS updates
- **After Xcode updates**: Clean Xcode caches after updating
- **Check first**: The script shows what it will clean before proceeding

## 📄 License

Free to use, modify, and distribute.

## 🤝 Contributing

Feel free to improve and share!

## ⚠️ Disclaimer

This script is provided as-is. While it's designed to be safe, always have backups of important data. The author is not responsible for any data loss.

---

**Made for Mac users who want a clean, fast system! 🚀**

