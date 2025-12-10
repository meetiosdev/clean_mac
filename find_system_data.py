#!/usr/bin/env python3

"""
System Data Finder for macOS
Scans for large directories that contribute to "System Data" storage
"""

import os
import subprocess
import sys
from pathlib import Path
from typing import List, Tuple

# Colors for terminal output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    BOLD = '\033[1m'
    NC = '\033[0m'  # No Color

def print_colored(text: str, color: str = Colors.NC):
    """Print colored text"""
    print(f"{color}{text}{Colors.NC}")

def get_directory_size(path: Path) -> Tuple[int, bool]:
    """
    Get directory size using du command (faster and more accurate).
    Returns (size_in_bytes, success)
    """
    try:
        if not path.exists():
            return 0, False
        
        # Use du command for accurate size calculation
        result = subprocess.run(
            ['du', '-sk', str(path)],
            capture_output=True,
            text=True,
            timeout=300
        )
        
        if result.returncode == 0:
            size_kb = int(result.stdout.split()[0])
            return size_kb * 1024, True
        else:
            return 0, False
    except (subprocess.TimeoutExpired, ValueError, PermissionError, OSError):
        return 0, False

def bytes_to_gb(bytes_size: int) -> float:
    """Convert bytes to GB"""
    return bytes_size / (1024 ** 3)

def scan_system_data_locations() -> List[Tuple[str, str, int, bool]]:
    """Scan common System Data locations"""
    locations = []
    
    # System directories that contribute to System Data
    system_locations = [
        # System Caches
        ("/Library/Caches", "System Caches", True),
        ("/private/var/folders", "System Temporary Files", True),
        ("/private/var/vm", "Virtual Memory Swap Files", True),
        ("/private/var/db", "System Databases", True),
        ("/private/var/log", "System Logs", True),
        ("/System/Library/Caches", "System Library Caches", True),
        
        # Time Machine Local Snapshots
        ("/.MobileBackups", "Time Machine Local Snapshots", True),
        ("/private/var/db/.MobileBackups", "Time Machine Local Snapshots (Alt)", True),
        
        # User Library (often large)
        (os.path.expanduser("~/Library/Caches"), "User Library Caches", False),
        (os.path.expanduser("~/Library/Logs"), "User Library Logs", False),
        (os.path.expanduser("~/Library/Application Support"), "User Application Support", False),
        (os.path.expanduser("~/Library/Containers"), "User App Containers", False),
        
        # Xcode and Development (can be huge)
        (os.path.expanduser("~/Library/Developer"), "Xcode & Developer Files", False),
        
        # Docker and Virtual Machines
        (os.path.expanduser("~/Library/Containers/com.docker.docker"), "Docker Data", False),
        (os.path.expanduser("~/Library/VirtualBox"), "VirtualBox VMs", False),
        (os.path.expanduser("~/Library/Application Support/Parallels"), "Parallels VMs", False),
        
        # System Containers
        ("/private/var/containers", "System App Containers", True),
        
        # Spotlight Index
        ("/.Spotlight-V100", "Spotlight Index", True),
        (os.path.expanduser("~/.Spotlight-V100"), "User Spotlight Index", False),
        
        # Mail Downloads
        (os.path.expanduser("~/Library/Mail"), "Mail Data", False),
        
        # iOS Device Backups
        (os.path.expanduser("~/Library/Application Support/MobileSync/Backup"), "iOS Device Backups", False),
        
        # Homebrew
        ("/opt/homebrew", "Homebrew (Apple Silicon)", True),
        ("/usr/local", "Homebrew (Intel)", True),
        
        # Node modules (can be huge)
        (os.path.expanduser("~/node_modules"), "Node Modules (Home)", False),
        
        # Trash
        (os.path.expanduser("~/.Trash"), "Trash", False),
    ]
    
    print_colored("Scanning system locations... This may take a few minutes.", Colors.BLUE)
    print()
    
    for path_str, description, requires_sudo in system_locations:
        path = Path(path_str)
        print(f"Scanning: {description}...", end="\r")
        
        size_bytes, success = get_directory_size(path)
        
        if success and size_bytes > 0:
            locations.append((path_str, description, size_bytes, requires_sudo))
            size_gb = bytes_to_gb(size_bytes)
            print_colored(f"Found: {description} - {size_gb:.2f} GB", Colors.GREEN)
        elif not success and path.exists():
            # Directory exists but we couldn't read it (permission issue)
            locations.append((path_str, description, 0, requires_sudo))
            print_colored(f"Found: {description} - [Permission Denied - may require sudo]", Colors.YELLOW)
    
    print()  # New line after scanning
    return locations

def find_large_directories(root_path: Path, min_size_gb: float = 1.0) -> List[Tuple[str, int]]:
    """Find large directories within a path"""
    large_dirs = []
    
    try:
        if not root_path.exists() or not root_path.is_dir():
            return large_dirs
        
        # Use find with du to get sizes of immediate subdirectories
        result = subprocess.run(
            ['find', str(root_path), '-maxdepth', '1', '-type', 'd', '-exec', 'du', '-sk', '{}', ';'],
            capture_output=True,
            text=True,
            timeout=300
        )
        
        if result.returncode == 0:
            for line in result.stdout.strip().split('\n'):
                if line:
                    parts = line.split('\t')
                    if len(parts) == 2:
                        size_kb = int(parts[0])
                        dir_path = parts[1]
                        
                        if size_kb > 0:
                            size_gb = bytes_to_gb(size_kb * 1024)
                            if size_gb >= min_size_gb:
                                large_dirs.append((dir_path, size_kb * 1024))
    except (subprocess.TimeoutExpired, ValueError, PermissionError, OSError):
        pass
    
    return large_dirs

def print_results_table(locations: List[Tuple[str, str, int, bool]]):
    """Print formatted results table"""
    if not locations:
        print_colored("No large directories found.", Colors.YELLOW)
        return
    
    # Sort by size (largest first)
    locations.sort(key=lambda x: x[2], reverse=True)
    
    # Calculate column widths
    max_path_len = max(len(row[0]) for row in locations) if locations else 0
    max_desc_len = max(len(row[1]) for row in locations) if locations else 0
    
    path_width = max(60, min(max_path_len + 2, 80))
    desc_width = max(35, min(max_desc_len + 2, 50))
    size_width = 15
    perm_width = 12
    
    # Print header
    header = f"{'Path':<{path_width}} {'Description':<{desc_width}} {'Size':<{size_width}} {'Permission':<{perm_width}}"
    print_colored(header, Colors.BOLD + Colors.CYAN)
    print_colored("=" * (path_width + desc_width + size_width + perm_width), Colors.CYAN)
    
    total_size = 0
    for path, desc, size_bytes, requires_sudo in locations:
        total_size += size_bytes
        size_gb = bytes_to_gb(size_bytes)
        
        # Truncate path if too long
        display_path = path if len(path) <= path_width - 2 else "..." + path[-(path_width-5):]
        
        perm_text = "sudo needed" if requires_sudo and size_bytes == 0 else "user access"
        perm_color = Colors.YELLOW if requires_sudo and size_bytes == 0 else Colors.GREEN
        
        row = f"{display_path:<{path_width}} {desc:<{desc_width}} {size_gb:>10.2f} GB {perm_text:<{perm_width}}"
        print(row)
    
    print()
    total_gb = bytes_to_gb(total_size)
    print_colored(f"Total Scanned: {total_gb:.2f} GB", Colors.BOLD + Colors.GREEN)
    print()

def main():
    """Main function"""
    print_colored("=" * 100, Colors.BLUE)
    print_colored("        SYSTEM DATA LOCATION FINDER FOR macOS", Colors.BOLD + Colors.BLUE)
    print_colored("=" * 100, Colors.BLUE)
    print()
    
    # Check if running on macOS
    if sys.platform != "darwin":
        print_colored("⚠️  WARNING: This script is designed for macOS only!", Colors.YELLOW)
        sys.exit(1)
    
    # Scan system locations
    locations = scan_system_data_locations()
    
    # Print results
    print_colored("=" * 100, Colors.BLUE)
    print_colored("RESULTS:", Colors.BOLD + Colors.YELLOW)
    print()
    print_results_table(locations)
    
    # Additional scan for large subdirectories in key locations
    print_colored("Scanning for large subdirectories in key locations...", Colors.BLUE)
    print()
    
    key_locations = [
        (Path(os.path.expanduser("~/Library")), "User Library subdirectories"),
        (Path("/Library"), "System Library subdirectories"),
        (Path("/private/var"), "System var subdirectories"),
    ]
    
    for root_path, desc in key_locations:
        if root_path.exists():
            print_colored(f"Scanning {desc}...", Colors.CYAN)
            large_dirs = find_large_directories(root_path, min_size_gb=0.5)
            
            if large_dirs:
                large_dirs.sort(key=lambda x: x[1], reverse=True)
                print_colored(f"Large directories in {desc}:", Colors.YELLOW)
                for dir_path, size_bytes in large_dirs[:10]:  # Show top 10
                    size_gb = bytes_to_gb(size_bytes)
                    print(f"  {dir_path}: {size_gb:.2f} GB")
                print()
    
    # Check for Time Machine local snapshots (often huge)
    print_colored("Checking for Time Machine local snapshots...", Colors.BLUE)
    try:
        result = subprocess.run(
            ['tmutil', 'listlocalsnapshots', '/'],
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode == 0 and result.stdout.strip():
            snapshots = [line for line in result.stdout.strip().split('\n') if line.startswith('com.apple.TimeMachine')]
            if snapshots:
                print_colored(f"⚠️  Found {len(snapshots)} Time Machine local snapshots!", Colors.YELLOW)
                print_colored("   These can take up significant space. To delete them:", Colors.YELLOW)
                print_colored("   sudo tmutil deletelocalsnapshots <snapshot-date>", Colors.CYAN)
                print_colored("   Or delete all: sudo tmutil deletelocalsnapshots /", Colors.CYAN)
                print()
    except (subprocess.TimeoutExpired, FileNotFoundError, PermissionError):
        pass
    
    print_colored("=" * 100, Colors.BLUE)
    print_colored("💡 TIP: Some locations may require sudo to access. Use 'sudo du -sh <path>' to check.", Colors.CYAN)
    print_colored("💡 TIP: To check specific directory: du -sh <path>", Colors.CYAN)
    print()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        print_colored("\nOperation cancelled by user (Ctrl+C).", Colors.YELLOW)
        sys.exit(1)
    except Exception as e:
        print_colored(f"\nUnexpected error: {str(e)}", Colors.RED)
        import traceback
        traceback.print_exc()
        sys.exit(1)

