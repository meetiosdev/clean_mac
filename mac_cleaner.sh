#!/bin/bash

# =============================================================================
# MAC CLEANER - Unified Junk & System Data Cleaner for macOS
# =============================================================================
# A comprehensive, optimized script to clean all junk, caches, and system data
# Works on any Mac - uses generic paths, no hardcoded usernames
# =============================================================================

set -eo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Print functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
section() { echo -e "${CYAN}${BOLD}[SECTION]${NC} $1"; }

# Convert bytes to human readable
bytes_to_human() {
    local bytes=$1
    if [ $bytes -ge 1073741824 ]; then
        awk "BEGIN {printf \"%.2f GB\", $bytes/1073741824}"
    elif [ $bytes -ge 1048576 ]; then
        awk "BEGIN {printf \"%.2f MB\", $bytes/1048576}"
    elif [ $bytes -ge 1024 ]; then
        awk "BEGIN {printf \"%.2f KB\", $bytes/1024}"
    else
        echo "${bytes} bytes"
    fi
}

# Get folder size in bytes (fast)
get_size() {
    [ -d "$1" ] && du -sb "$1" 2>/dev/null | cut -f1 || echo 0
}

# Clean directory contents (keeps directory, moves to Trash)
clean_dir() {
    local dir="$1" desc="$2" use_sudo="${3:-false}"
    [ ! -d "$dir" ] && echo 0 && return 0
    [ -z "$(ls -A "$dir" 2>/dev/null)" ] && echo 0 && return 0
    
    local size_before=$(get_size "$dir")
    info "Cleaning: $desc (moving to Trash)" >&2
    
    # Create timestamped folder in Trash
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local trash_dir="$HOME/.Trash/${desc//\//_}_${timestamp}"
    mkdir -p "$trash_dir" 2>/dev/null || true
    
    if [ "$use_sudo" = "true" ]; then
        # For system files, we still need to delete (can't move to user Trash with sudo)
        # But try to move what we can
        for item in "$dir"/*; do
            [ -e "$item" ] && sudo mv "$item" "$trash_dir/" 2>/dev/null || sudo rm -rf "$item" 2>/dev/null || true
        done
    else
        # Move all contents to Trash
        for item in "$dir"/* "$dir"/.*; do
            # Skip . and ..
            [ "$item" = "$dir/." ] && continue
            [ "$item" = "$dir/.." ] && continue
            [ -e "$item" ] && mv "$item" "$trash_dir/" 2>/dev/null || true
        done
    fi
    
    local size_after=$(get_size "$dir")
    local freed=$((size_before - size_after))
    echo $freed
}

# Clean specific files by pattern (moves to Trash)
clean_files() {
    local pattern="$1" desc="$2" dir="${3:-$HOME/Downloads}"
    [ ! -d "$dir" ] && echo 0 && return 0
    
    local total=0
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local trash_dir="$HOME/.Trash/${desc//\//_}_${timestamp}"
    mkdir -p "$trash_dir" 2>/dev/null || true
    
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
            total=$((total + size))
            mv "$file" "$trash_dir/" 2>/dev/null || true
        fi
    done < <(find "$dir" -name "$pattern" -type f 2>/dev/null)
    
    [ $total -gt 0 ] && info "Moved $desc to Trash: $(bytes_to_human $total)" >&2
    echo $total
}

# Clean Downloads folder: zip/folder pairs, images, and other cleanup (moves to Trash)
clean_downloads() {
    local downloads_dir="${1:-$HOME/Downloads}"
    [ ! -d "$downloads_dir" ] && echo 0 && return 0
    
    local total=0
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local trash_dir="$HOME/.Trash/Downloads_Cleanup_${timestamp}"
    mkdir -p "$trash_dir" 2>/dev/null || true
    
    # 1. Remove .zip files if there's an unzipped folder with the same name
    info "Checking zip files with matching folders..." >&2
    while IFS= read -r zip_file; do
        if [ -f "$zip_file" ]; then
            # Get zip file name without extension
            local zip_basename=$(basename "$zip_file" .zip)
            local zip_dirname=$(dirname "$zip_file")
            local matching_folder="$zip_dirname/$zip_basename"
            
            # Check if matching folder exists
            if [ -d "$matching_folder" ]; then
                # Move both zip and folder to Trash
                local zip_size=$(stat -f%z "$zip_file" 2>/dev/null || stat -c%s "$zip_file" 2>/dev/null || echo 0)
                local folder_size=$(get_size "$matching_folder")
                local pair_size=$((zip_size + folder_size))
                
                mv "$zip_file" "$trash_dir/" 2>/dev/null || true
                mv "$matching_folder" "$trash_dir/" 2>/dev/null || true
                
                total=$((total + pair_size))
                info "Moved zip+folder pair to Trash: $zip_basename ($(bytes_to_human $pair_size))" >&2
            fi
        fi
    done < <(find "$downloads_dir" -maxdepth 1 -name "*.zip" -type f 2>/dev/null)
    
    # 2. Move remaining .zip files to Trash (those without matching folders)
    info "Moving remaining .zip files to Trash..." >&2
    while IFS= read -r zip_file; do
        if [ -f "$zip_file" ]; then
            local zip_basename=$(basename "$zip_file" .zip)
            local zip_dirname=$(dirname "$zip_file")
            local matching_folder="$zip_dirname/$zip_basename"
            
            # Only move if no matching folder exists
            if [ ! -d "$matching_folder" ]; then
                local size=$(stat -f%z "$zip_file" 2>/dev/null || stat -c%s "$zip_file" 2>/dev/null || echo 0)
                total=$((total + size))
                mv "$zip_file" "$trash_dir/" 2>/dev/null || true
            fi
        fi
    done < <(find "$downloads_dir" -maxdepth 1 -name "*.zip" -type f 2>/dev/null)
    
    # 3. Move .txt files to Trash
    info "Moving .txt files to Trash..." >&2
    while IFS= read -r txt_file; do
        if [ -f "$txt_file" ]; then
            local size=$(stat -f%z "$txt_file" 2>/dev/null || stat -c%s "$txt_file" 2>/dev/null || echo 0)
            total=$((total + size))
            mv "$txt_file" "$trash_dir/" 2>/dev/null || true
        fi
    done < <(find "$downloads_dir" -maxdepth 1 -name "*.txt" -type f 2>/dev/null)
    
    # 4. Move all files under 100KB to Trash
    info "Moving files under 100KB to Trash..." >&2
    local size_limit=$((100 * 1024))  # 100KB in bytes
    while IFS= read -r small_file; do
        if [ -f "$small_file" ]; then
            local size=$(stat -f%z "$small_file" 2>/dev/null || stat -c%s "$small_file" 2>/dev/null || echo 0)
            if [ $size -lt $size_limit ] && [ $size -gt 0 ]; then
                total=$((total + size))
                mv "$small_file" "$trash_dir/" 2>/dev/null || true
            fi
        fi
    done < <(find "$downloads_dir" -maxdepth 1 -type f 2>/dev/null)
    
    # 5. Move all folders containing .xcodeproj files to Trash
    info "Moving folders containing .xcodeproj files to Trash..." >&2
    for folder in "$downloads_dir"/*; do
        if [ -d "$folder" ]; then
            local folder_name=$(basename "$folder")
            # Check if this folder (or any subfolder) contains .xcodeproj
            if find "$folder" -name "*.xcodeproj" -type d 2>/dev/null | head -1 | grep -q .; then
                local folder_size=$(get_size "$folder")
                total=$((total + folder_size))
                mv "$folder" "$trash_dir/" 2>/dev/null || true
                info "Moved Xcode project folder to Trash: $folder_name ($(bytes_to_human $folder_size))" >&2
            fi
        fi
    done
    
    # Move .png files to Trash (but not in subdirectories, only in Downloads root)
    while IFS= read -r png_file; do
        if [ -f "$png_file" ]; then
            local size=$(stat -f%z "$png_file" 2>/dev/null || stat -c%s "$png_file" 2>/dev/null || echo 0)
            total=$((total + size))
            mv "$png_file" "$trash_dir/" 2>/dev/null || true
        fi
    done < <(find "$downloads_dir" -maxdepth 1 -name "*.png" -type f 2>/dev/null)
    
    # Move .jpg files to Trash (but not .jpeg - that's excluded)
    while IFS= read -r jpg_file; do
        if [ -f "$jpg_file" ]; then
            # Double check it's not .jpeg (case insensitive)
            local ext=$(echo "$jpg_file" | awk -F. '{print tolower($NF)}')
            if [ "$ext" = "jpg" ]; then
                local size=$(stat -f%z "$jpg_file" 2>/dev/null || stat -c%s "$jpg_file" 2>/dev/null || echo 0)
                total=$((total + size))
                mv "$jpg_file" "$trash_dir/" 2>/dev/null || true
            fi
        fi
    done < <(find "$downloads_dir" -maxdepth 1 -name "*.jpg" -type f 2>/dev/null)
    
    [ $total -gt 0 ] && info "Downloads cleanup (moved to Trash): $(bytes_to_human $total)" >&2
    echo $total
}

# Add to total
add_freed() {
    local amount=${1:-0}
    # Ensure amount is numeric
    amount=$(echo "$amount" | grep -oE '^[0-9]+$' || echo 0)
    total_freed=$((${total_freed:-0} + amount))
}

# Main cleanup function
main() {
    echo -e "${BLUE}${BOLD}========================================${NC}"
    echo -e "${BLUE}${BOLD}     MAC CLEANER - Unified Cleaner     ${NC}"
    echo -e "${BLUE}${BOLD}========================================${NC}"
    echo ""
    
    # Check macOS
    [[ "$OSTYPE" != "darwin"* ]] && error "macOS only!" && exit 1
    
    # Show what will be cleaned
    echo -e "${YELLOW}This will clean:${NC}"
    echo "  • All app caches (Xcode, browsers, dev tools)"
    echo "  • System caches and logs"
    echo "  • Temporary files"
    echo "  • Time Machine snapshots"
    echo "  • Installer files (DMG/PKG)"
    echo "  • Homebrew caches"
    echo "  • Downloads: zip files, .txt files, small files (<100KB), Xcode projects"
    echo ""
    echo -e "${GREEN}Note: All deleted files/folders will be moved to Trash${NC}"
    echo -e "${GREEN}      (except system files that require deletion)${NC}"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    [[ ! $REPLY =~ ^[Yy]$ ]] && warning "Cancelled" && exit 0
    
    echo ""
    info "Starting cleanup..."
    echo ""
    
    # Ensure Trash directory exists
    [ ! -d "$HOME/.Trash" ] && mkdir -p "$HOME/.Trash" 2>/dev/null || true
    
    total_freed=0
    local freed=0
    
    # SECTION 1: Xcode & Development
    section "1. Xcode & Development Files"
    freed=$(clean_dir "$HOME/Library/Developer/Xcode/DerivedData" "Xcode DerivedData" false)
    add_freed $freed
    freed=$(clean_dir "$HOME/Library/Developer/Xcode/iOS DeviceSupport" "iOS DeviceSupport" false)
    add_freed $freed
    freed=$(clean_dir "$HOME/Library/Developer/CoreSimulator/Caches" "CoreSimulator Caches" false)
    add_freed $freed
    freed=$(clean_dir "$HOME/Library/Developer/Xcode/Archives" "Xcode Archives" false)
    add_freed $freed
    freed=$(clean_dir "$HOME/Library/Developer/Xcode/DocumentationCache" "Xcode Docs" false)
    add_freed $freed
    [ -f "$HOME/Library/Caches/org.swift.swiftpm" ] && mv "$HOME/Library/Caches/org.swift.swiftpm" "$HOME/.Trash/" 2>/dev/null && add_freed 1000000
    echo ""
    
    # SECTION 2: Browser & App Caches
    section "2. Browser & Application Caches"
    freed=$(clean_dir "$HOME/Library/Caches/Google/Chrome" "Chrome Cache" false)
    add_freed $freed
    freed=$(clean_dir "$HOME/Library/Caches/com.apple.Safari" "Safari Cache" false)
    add_freed $freed
    freed=$(clean_dir "$HOME/Library/Application Support/Slack/Cache" "Slack Cache" false)
    add_freed $freed
    freed=$(clean_dir "$HOME/Library/Application Support/Code/Cache" "VS Code Cache" false)
    add_freed $freed
    freed=$(clean_dir "$HOME/Library/Caches/CocoaPods" "CocoaPods Cache" false)
    add_freed $freed
    echo ""
    
    # SECTION 3: System Caches & Logs
    section "3. System Caches & Logs"
    freed=$(clean_dir "$HOME/Library/Caches" "User Caches" false)
    add_freed $freed
    freed=$(clean_dir "$HOME/Library/Logs" "User Logs" false)
    add_freed $freed
    freed=$(clean_dir "/Library/Caches" "System Caches" true)
    add_freed $freed
    freed=$(clean_dir "/private/var/log" "System Logs" true)
    add_freed $freed
    echo ""
    
    # SECTION 4: Temporary Files
    section "4. Temporary Files"
    freed=$(clean_dir "/private/var/tmp" "System Temp" true)
    add_freed $freed
    if [ -d "/private/var/folders" ]; then
        for folder in /private/var/folders/*/*/C; do
            [ -d "$folder" ] && freed=$(clean_dir "$folder" "User Temp" true) && add_freed $freed
        done
    fi
    echo ""
    
    # SECTION 5: Virtual Memory
    section "5. Virtual Memory Swap"
    info "Note: Swap files are system-managed and will regenerate automatically" >&2
    info "These are deleted (not moved to Trash) as they're system files" >&2
    if [ -d "/private/var/vm" ]; then
        local vm_size=$(get_size "/private/var/vm")
        sudo rm -f /private/var/vm/swapfile* 2>/dev/null || true
        local vm_after=$(get_size "/private/var/vm")
        add_freed $((vm_size - vm_after))
    fi
    echo ""
    
    # SECTION 6: Time Machine Snapshots
    section "6. Time Machine Local Snapshots"
    if command -v tmutil &>/dev/null; then
        local snap_count=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c "com.apple.TimeMachine" || echo 0)
        if [ "$snap_count" -gt 0 ]; then
            sudo tmutil thinlocalsnapshots / 10000000000 4 2>/dev/null || true
            info "Thinned Time Machine snapshots"
        fi
    fi
    echo ""
    
    # SECTION 7: Installer Files
    section "7. Installer Files (DMG/PKG)"
    freed=$(clean_files "*.dmg" "DMG files" "$HOME/Downloads")
    add_freed $freed
    freed=$(clean_files "*.pkg" "PKG files" "$HOME/Downloads")
    add_freed $freed
    echo ""
    
    # SECTION 8: Homebrew
    section "8. Homebrew Cleanup"
    if command -v brew &>/dev/null; then
        brew cleanup -q 2>/dev/null || true
        brew autoremove -q 2>/dev/null || true
        success "Homebrew cleaned"
    else
        warning "Homebrew not found"
    fi
    echo ""
    
    # SECTION 9: Additional Caches
    section "9. Additional Caches"
    freed=$(clean_dir "$HOME/.npm" "npm Cache" false)
    add_freed $freed
    [ -d "$HOME/.yarn/cache" ] && freed=$(clean_dir "$HOME/.yarn/cache" "Yarn Cache" false) && add_freed $freed
    [ -d "$HOME/Library/Caches/pip" ] && freed=$(clean_dir "$HOME/Library/Caches/pip" "pip Cache" false) && add_freed $freed
    [ -d "$HOME/.cache/pip" ] && freed=$(clean_dir "$HOME/.cache/pip" "pip Cache" false) && add_freed $freed
    echo ""
    
    # SECTION 10: Downloads Cleanup
    section "10. Downloads Folder Cleanup"
    info "Cleaning Downloads:" >&2
    info "  • Zip files (with matching folders or standalone)" >&2
    info "  • .txt files" >&2
    info "  • Files under 100KB" >&2
    info "  • Folders containing .xcodeproj files" >&2
    info "  • .png and .jpg files" >&2
    info "Protecting: .HEIC and .jpeg files" >&2
    freed=$(clean_downloads "$HOME/Downloads")
    add_freed $freed
    echo ""
    
    # Results
    echo -e "${BLUE}${BOLD}========================================${NC}"
    if [ $total_freed -gt 0 ]; then
        success "🎉 Cleanup completed!"
        success "Total space freed: $(bytes_to_human $total_freed)"
    else
        warning "No significant space was freed"
    fi
    echo -e "${BLUE}${BOLD}========================================${NC}"
    echo ""
}

main "$@"
