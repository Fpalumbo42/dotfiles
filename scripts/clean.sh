#!/usr/bin/env bash
# Enhanced System Cleaner v3.0
# Deep cleaning and optimization script for macOS and Linux
set -u -o pipefail
IFS=$'\n\t'

# Configuration
DRY_RUN=false
AUTO_YES=false
VERBOSE=false

# Detect OS (darwin/linux)
OS_NAME="$(uname -s)"
OS="unknown"
IS_MACOS=false
IS_LINUX=false
case "$OS_NAME" in
  Darwin)
    OS="macos"
    IS_MACOS=true
    ;;
  Linux)
    OS="linux"
    IS_LINUX=true
    ;;
  *)
    OS="$OS_NAME"
    ;;
esac

LOG_FILE="/tmp/cleaner_${OS}_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

print_help() {
  cat <<EOF
Enhanced System Cleaner v3.0

USAGE: $0 [options]

OPTIONS:
  -n, --dry-run     Simulate actions without deleting anything
  -y, --yes         Auto-confirm all prompts
  -v, --verbose     Enable verbose output
  -h, --help        Show this help message

This script supports macOS (Darwin) and Linux. Some operations are OS-specific and will be skipped on the other platform.

FEATURES (high level):
  • User and system cache cleanup
  • Package manager cache cleaning (brew/apt/dnf/pacman/npm/pip/...)
  • Development environment cleanup (Xcode, npm, pip, etc.)
  • System database and journal optimization
  • Browser and third-party app caches cleanup
  • Large file scanning

EOF
}

log_message() {
  local level="$1"
  shift
  local message="$*"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  case "$level" in
    "INFO")     echo -e "${BLUE}[INFO]${NC}    $message" ;;
    "WARN")     echo -e "${YELLOW}[WARN]${NC}    $message" ;;
    "ERROR")    echo -e "${RED}[ERROR]${NC}   $message" ;;
    "SUCCESS")  echo -e "${GREEN}[OK]${NC}      $message" ;;
    "CLEAN")    echo -e "${CYAN}[CLEAN]${NC}   $message" ;;
  esac
  
  echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

confirm() {
  [[ "$AUTO_YES" == true ]] && return 0
  local prompt="$1"
  read -p "$prompt [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

run_cmd() {
  local cmd="$*"
  
  # Check if command requires sudo and if sudo is available
  if [[ "$cmd" =~ ^sudo ]] && ! command -v sudo &>/dev/null; then
    [[ "$VERBOSE" == true ]] && log_message "INFO" "Skipping command (sudo not available)"
    return 0
  fi
  
  if [[ "$DRY_RUN" == true ]]; then
    log_message "INFO" "DRY-RUN: $cmd"
  else
    if [[ "$VERBOSE" == true ]]; then
      log_message "INFO" "Executing: $cmd"
    fi
    eval "$cmd" 2>/dev/null || {
      [[ "$VERBOSE" == true ]] && log_message "WARN" "Command failed (non-critical): $cmd"
      return 0
    }
  fi
}

get_size() {
  local path="$1"
  if [[ -e "$path" ]]; then
    du -sh "$path" 2>/dev/null | cut -f1
  else
    echo "0"
  fi
}

run_cmd_if_exists() {
  local path_to_check="$1"
  shift
  local cmd="$*"
  
  # Extract path from command for checking (handles quoted paths)
  if [[ -n "$path_to_check" && ! -e "$path_to_check" ]]; then
    [[ "$VERBOSE" == true ]] && log_message "INFO" "Skipping (path not found): $path_to_check"
    return 0
  fi
  
  run_cmd "$cmd"
}

get_free_space() {
  # Try to get home directory space, fallback to root
  if df -H "$HOME" &>/dev/null; then
    df -H "$HOME" | awk 'NR==2 {print $4}'
  else
    df -H / | awk 'NR==2 {print $4}'
  fi
}

check_permissions() {
  if [[ $EUID -eq 0 ]]; then
    log_message "WARN" "Running as root. This is not recommended for safety reasons."
    if ! confirm "Continue running as root?"; then
      exit 1
    fi
  fi
}

cleanup_macos_system() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping macOS system cleanup on $OS"
    return
  fi

  log_message "CLEAN" "Starting macOS system caches and logs cleanup..."

  # Calculate sizes before cleaning
  local cache_size=$(get_size ~/Library/Caches)
  log_message "INFO" "User cache size: $cache_size"

  # User caches
  run_cmd "rm -rf ~/Library/Caches/*"

  # System caches (requires sudo)
  run_cmd "sudo rm -rf /Library/Caches/*"
  run_cmd "sudo rm -rf /System/Library/Caches/*"
  
  # Application Support caches
  run_cmd "rm -rf ~/Library/Application\\ Support/CrashReporter/*"
  
  # Log files
  run_cmd "rm -rf ~/Library/Logs/*"
  run_cmd "sudo rm -rf /Library/Logs/*"
  run_cmd "sudo rm -rf /var/log/*.log"
  run_cmd "sudo rm -rf /var/log/*.out"
  
  # ASL logs
  run_cmd "sudo rm -rf /private/var/log/asl/*.asl"
  
  # Trash
  run_cmd "rm -rf ~/.Trash/*"
  run_cmd "rm -rf ~/.Trash/.**"
  
  # Temporary files
  run_cmd "sudo rm -rf /private/var/folders/*"
  run_cmd "sudo rm -rf /private/tmp/*"
  run_cmd "sudo rm -rf /tmp/*"
  
  # DS_Store files
  run_cmd "find ~ -name '.DS_Store' -delete"
  run_cmd "sudo find /Volumes -name '.DS_Store' -delete 2>/dev/null"
  
  # AppleDouble files
  run_cmd "find ~ -name '._*' -delete"
  
  log_message "SUCCESS" "macOS system cleanup completed"
}

cleanup_linux_system() {
  if [[ "$IS_LINUX" != true ]]; then
    log_message "INFO" "Skipping Linux system cleanup on $OS"
    return
  fi

  log_message "CLEAN" "Starting comprehensive Linux cleanup..."

  local cleaned_items=0
  local total_freed=0
  
  # User caches - More aggressive
  if [[ -d ~/.cache ]]; then
    local cache_size_before=$(du -sb ~/.cache 2>/dev/null | cut -f1)
    log_message "INFO" "User cache size before: $(numfmt --to=iec $cache_size_before 2>/dev/null || echo '0')"
    
    # Clean all cache contents aggressively
    run_cmd "find ~/.cache -type f -delete 2>/dev/null"
    run_cmd "find ~/.cache -type d -empty -delete 2>/dev/null"
    
    local cache_size_after=$(du -sb ~/.cache 2>/dev/null | cut -f1)
    local freed=$((cache_size_before - cache_size_after))
    total_freed=$((total_freed + freed))
    log_message "INFO" "Freed from cache: $(numfmt --to=iec $freed 2>/dev/null || echo '0')"
    ((cleaned_items++))
  fi

  # Trash (freedesktop)
  if [[ -d ~/.local/share/Trash ]]; then
    local trash_size=$(du -sb ~/.local/share/Trash 2>/dev/null | cut -f1)
    log_message "INFO" "Emptying trash: $(numfmt --to=iec $trash_size 2>/dev/null || echo '0')"
    run_cmd "rm -rf ~/.local/share/Trash/files/*"
    run_cmd "rm -rf ~/.local/share/Trash/info/*"
    run_cmd "rm -rf ~/.local/share/Trash/expunged/*"
    total_freed=$((total_freed + trash_size))
    ((cleaned_items++))
  fi

  # User temporary files
  if [[ -d ~/.tmp ]]; then
    run_cmd "rm -rf ~/.tmp/*"
    ((cleaned_items++))
  fi
  
  # XDG cache dirs
  if [[ -d ~/.local/share/gvfs-metadata ]]; then
    run_cmd "rm -rf ~/.local/share/gvfs-metadata/*"
    ((cleaned_items++))
  fi
  
  # Recently used files
  if [[ -f ~/.local/share/recently-used.xbel ]]; then
    local size=$(stat -c%s ~/.local/share/recently-used.xbel 2>/dev/null || echo "0")
    run_cmd "rm -f ~/.local/share/recently-used.xbel"
    total_freed=$((total_freed + size))
    ((cleaned_items++))
  fi
  
  # Desktop entries cache
  if [[ -d ~/.local/share/applications ]]; then
    run_cmd "find ~/.local/share/applications -name '*.desktop~' -delete"
  fi
  
  # Icon cache
  if [[ -d ~/.cache/icon-cache.kcache ]]; then
    run_cmd "rm -f ~/.cache/icon-cache.kcache"
    ((cleaned_items++))
  fi
  
  # Systemd user logs
  if [[ -d ~/.local/share/systemd/user ]]; then
    run_cmd "find ~/.local/share/systemd/user -name '*.log' -delete"
  fi

  # Shell history trimming (keep last 1000 lines)
  for hist_file in ~/.bash_history ~/.zsh_history; do
    if [[ -f "$hist_file" ]] && [[ $(wc -l < "$hist_file") -gt 1000 ]]; then
      log_message "INFO" "Trimming history file: $hist_file"
      run_cmd "tail -1000 '$hist_file' > '${hist_file}.tmp' && mv '${hist_file}.tmp' '$hist_file'"
    fi
  done

  # User logs
  if [[ -d ~/.xsession-errors ]]; then
    run_cmd "rm -f ~/.xsession-errors*"
    ((cleaned_items++))
  fi
  
  # Old core dumps
  if [[ -d ~/core ]]; then
    run_cmd "find ~/core -name 'core.*' -mtime +7 -delete"
  fi
  run_cmd "find ~/ -maxdepth 1 -name 'core.*' -mtime +7 -delete 2>/dev/null"

  log_message "SUCCESS" "Linux cleanup completed - $cleaned_items areas, freed $(numfmt --to=iec $total_freed 2>/dev/null || echo '0')"
}

cleanup_old_logs_and_temp() {
  if [[ "$IS_LINUX" != true ]]; then
    return
  fi
  
  log_message "CLEAN" "Cleaning old logs and temporary files..."
  
  local files_deleted=0
  
  # Old log files in home directory
  log_message "INFO" "Scanning for old log files..."
  files_deleted=$(find ~/ -maxdepth 3 -name '*.log' -mtime +30 -type f 2>/dev/null | wc -l)
  if [[ $files_deleted -gt 0 ]]; then
    log_message "INFO" "Found $files_deleted old log files (>30 days)"
    if confirm "Delete old log files?"; then
      run_cmd "find ~/ -maxdepth 3 -name '*.log' -mtime +30 -type f -delete 2>/dev/null"
    fi
  fi
  
  # Old .tmp files
  local tmp_count=$(find ~/ -name '*.tmp' -mtime +7 -type f 2>/dev/null | wc -l)
  if [[ $tmp_count -gt 0 ]]; then
    log_message "INFO" "Found $tmp_count .tmp files (>7 days)"
    run_cmd "find ~/ -name '*.tmp' -mtime +7 -type f -delete 2>/dev/null"
  fi
  
  # Old backup files
  local backup_count=$(find ~/ -name '*~' -o -name '*.bak' -o -name '*.backup' 2>/dev/null | wc -l)
  if [[ $backup_count -gt 0 ]]; then
    log_message "INFO" "Found $backup_count backup files (*~, *.bak, *.backup)"
    if confirm "Delete backup files?"; then
      run_cmd "find ~/ -name '*~' -delete 2>/dev/null"
      run_cmd "find ~/ -name '*.bak' -delete 2>/dev/null"
      run_cmd "find ~/ -name '*.backup' -delete 2>/dev/null"
    fi
  fi
  
  # Vim swap files
  run_cmd "find ~/ -name '.*.swp' -delete 2>/dev/null"
  run_cmd "find ~/ -name '.*.swo' -delete 2>/dev/null"
  
  log_message "SUCCESS" "Old files cleanup completed"
}

cleanup_ios_device_support() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping iOS device support cleanup on $OS"
    return
  fi

  log_message "CLEAN" "Cleaning iOS device support files..."

  local ios_support_path=~/Library/Developer/Xcode/iOS\ DeviceSupport
  if [[ -d "$ios_support_path" ]]; then
    local size=$(get_size "$ios_support_path")
    log_message "INFO" "iOS DeviceSupport size: $size"

    # Keep only the two most recent versions
    run_cmd "ls -t '$ios_support_path' | tail -n +3 | xargs -I {} rm -rf '$ios_support_path/{}'"
  fi

  # Clean watchOS DeviceSupport
  local watch_support_path=~/Library/Developer/Xcode/watchOS\ DeviceSupport
  if [[ -d "$watch_support_path" ]]; then
    run_cmd "rm -rf '$watch_support_path'/*"
  fi

  log_message "SUCCESS" "iOS device support cleaned"
}

cleanup_ios_backups() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping iOS backups cleanup on $OS"
    return
  fi

  log_message "CLEAN" "Analyzing iOS device backups..."

  local backup_dir=~/Library/Application\ Support/MobileSync/Backup
  if [[ -d "$backup_dir" ]]; then
    local total_size=$(get_size "$backup_dir")
    log_message "INFO" "iOS backups total size: $total_size"

    # Delete backups older than 60 days
    run_cmd "find '$backup_dir' -maxdepth 1 -type d -mtime +60 -exec rm -rf {} \;"

    # Delete incomplete backups
    run_cmd "find '$backup_dir' -name 'Status.plist' -exec grep -L 'BackupState' {} \; | xargs -I {} dirname {} | xargs -I {} rm -rf {}"
  fi

  log_message "SUCCESS" "iOS backups cleaned"
}

cleanup_photos_library() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping Photos library optimization on $OS"
    return
  fi

  log_message "CLEAN" "Optimizing Photos library..."

  local photos_lib=~/Pictures/Photos\ Library.photoslibrary
  if [[ -d "$photos_lib" ]]; then
    # Clean derivatives cache
    run_cmd "rm -rf '$photos_lib/resources/derivatives'/*"
    run_cmd "rm -rf '$photos_lib/resources/cloudsharing/data'/*"
    run_cmd "rm -rf '$photos_lib/resources/renders'/*"

    # Clean database journals
    run_cmd "find '$photos_lib/database' -name '*-wal' -delete"
    run_cmd "find '$photos_lib/database' -name '*-shm' -delete"
  fi

  # Clean Photos agent caches
  run_cmd "rm -rf ~/Library/Containers/com.apple.cloudphotod/Data/Library/Caches/*"
  run_cmd "rm -rf ~/Library/Containers/com.apple.Photos/Data/Library/Caches/*"

  log_message "SUCCESS" "Photos library optimized"
}

cleanup_saved_application_states() {
  log_message "CLEAN" "Cleaning saved application states..."
  
  local saved_state_size=$(get_size ~/Library/Saved\ Application\ State)
  log_message "INFO" "Saved states size: $saved_state_size"
  
  run_cmd "rm -rf ~/Library/Saved\\ Application\\ State/*"
  run_cmd "rm -rf ~/Library/Autosave\\ Information/*"
  run_cmd "rm -rf ~/Library/Containers/*/Data/Library/Saved\\ Application\\ State/*"
  
  log_message "SUCCESS" "Application states cleaned"
}

cleanup_time_machine() {
  log_message "CLEAN" "Cleaning Time Machine local snapshots..."
  
  if ! command -v tmutil &>/dev/null; then
    log_message "WARN" "tmutil not found, skipping Time Machine cleanup"
    return
  fi
  
  # Delete all local snapshots
  run_cmd "tmutil listlocalsnapshots / | grep -o '[0-9-]*$' | xargs -I {} sudo tmutil deletelocalsnapshots {}"
  
  # Thin local snapshots
  run_cmd "sudo tmutil thinlocalsnapshots / 10000000000 4"
  
  log_message "SUCCESS" "Time Machine snapshots cleaned"
}

cleanup_browsers() {
  log_message "CLEAN" "Deep cleaning browser caches..."
  
  if [[ "$IS_MACOS" == true ]]; then
    # Safari (macOS only)
    run_cmd "rm -rf ~/Library/Caches/com.apple.Safari/*"
    run_cmd "rm -rf ~/Library/Safari/LocalStorage/*"
    run_cmd "rm -rf ~/Library/Safari/Databases/*"
    run_cmd "rm -rf ~/Library/Safari/Downloads/*.plist"
    run_cmd "rm -rf ~/Library/Safari/Favicon\\ Cache/*"
    run_cmd "rm -rf ~/Library/Containers/com.apple.Safari/Data/Library/Caches/*"
    
    # Chrome (macOS)
    run_cmd "rm -rf ~/Library/Caches/Google/Chrome/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Google/Chrome/Default/Application\\ Cache/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Google/Chrome/Default/Service\\ Worker/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Google/Chrome/Default/GPUCache/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Google/Chrome/ShaderCache/*"
    
    # Firefox (macOS)
    run_cmd "rm -rf ~/Library/Caches/Firefox/*"
    run_cmd "find ~/Library/Application\\ Support/Firefox/Profiles -name 'cache2' -type d -exec rm -rf {} + 2>/dev/null"
    run_cmd "find ~/Library/Application\\ Support/Firefox/Profiles -name 'startupCache' -type d -exec rm -rf {} + 2>/dev/null"
    
    # Edge (macOS)
    run_cmd "rm -rf ~/Library/Caches/com.microsoft.edgemac/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Microsoft\\ Edge/Default/Service\\ Worker/*"
    
    # Brave (macOS)
    run_cmd "rm -rf ~/Library/Caches/BraveSoftware/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/BraveSoftware/Brave-Browser/Default/Service\\ Worker/*"
  else
    # Linux browsers
    local browsers_cleaned=0
    
    # Chrome (Linux)
    if [[ -d ~/.cache/google-chrome ]]; then
      local chrome_size=$(get_size ~/.cache/google-chrome)
      log_message "INFO" "Chrome cache: $chrome_size"
      run_cmd "rm -rf ~/.cache/google-chrome/*"
      run_cmd "rm -rf ~/.config/google-chrome/Default/Service\\ Worker/* 2>/dev/null"
      run_cmd "rm -rf ~/.config/google-chrome/Default/GPUCache/* 2>/dev/null"
      run_cmd "rm -rf ~/.config/google-chrome/ShaderCache/* 2>/dev/null"
      ((browsers_cleaned++))
    fi
    
    # Chromium (Linux)
    if [[ -d ~/.cache/chromium ]]; then
      local chromium_size=$(get_size ~/.cache/chromium)
      log_message "INFO" "Chromium cache: $chromium_size"
      run_cmd "rm -rf ~/.cache/chromium/*"
      run_cmd "rm -rf ~/.config/chromium/Default/Service\\ Worker/* 2>/dev/null"
      ((browsers_cleaned++))
    fi
    
    # Firefox (Linux)
    if [[ -d ~/.cache/mozilla ]]; then
      local firefox_size=$(get_size ~/.cache/mozilla)
      log_message "INFO" "Firefox cache: $firefox_size"
      run_cmd "rm -rf ~/.cache/mozilla/*"
      run_cmd "find ~/.mozilla/firefox -name 'cache2' -type d -exec rm -rf {} + 2>/dev/null"
      run_cmd "find ~/.mozilla/firefox -name 'startupCache' -type d -exec rm -rf {} + 2>/dev/null"
      ((browsers_cleaned++))
    fi
    
    # Edge (Linux)
    if [[ -d ~/.cache/microsoft-edge ]]; then
      log_message "INFO" "Cleaning Edge cache"
      run_cmd "rm -rf ~/.cache/microsoft-edge/*"
      run_cmd "rm -rf ~/.config/microsoft-edge/Default/Service\\ Worker/* 2>/dev/null"
      ((browsers_cleaned++))
    fi
    
    # Brave (Linux)
    if [[ -d ~/.cache/BraveSoftware ]]; then
      log_message "INFO" "Cleaning Brave cache"
      run_cmd "rm -rf ~/.cache/BraveSoftware/*"
      run_cmd "rm -rf ~/.config/BraveSoftware/Brave-Browser/Default/Service\\ Worker/* 2>/dev/null"
      ((browsers_cleaned++))
    fi
    
    if [[ $browsers_cleaned -eq 0 ]]; then
      log_message "INFO" "No browser caches found"
    fi
  fi
  
  log_message "SUCCESS" "Browser caches cleaned"
}

cleanup_third_party_apps() {
  log_message "CLEAN" "Deep cleaning third-party application caches..."
  
  if [[ "$IS_MACOS" == true ]]; then
    # Slack
    run_cmd "rm -rf ~/Library/Application\\ Support/Slack/Cache/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Slack/Service\\ Worker/CacheStorage/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Slack/Code\\ Cache/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Slack/logs/*"
    
    # Discord
    run_cmd "rm -rf ~/Library/Application\\ Support/discord/Cache/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/discord/Code\\ Cache/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/discord/GPUCache/*"
    
    # Spotify
    run_cmd "rm -rf ~/Library/Caches/com.spotify.client/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Spotify/PersistentCache/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Spotify/Users/*/cache/*"
    
    # Teams
    run_cmd "rm -rf ~/Library/Application\\ Support/Microsoft/Teams/Cache/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Microsoft/Teams/Service\\ Worker/CacheStorage/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Microsoft/Teams/tmp/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Microsoft/Teams/media-stack/*"
    
    # Zoom
    run_cmd "rm -rf ~/Library/Caches/us.zoom.xos/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/zoom.us/AutoUpdater/*"
    run_cmd "rm -rf ~/Library/Logs/zoom*"
    
    # Adobe Creative Cloud
    run_cmd "rm -rf ~/Library/Caches/Adobe/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Adobe/Common/Media\\ Cache/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Adobe/Common/Media\\ Cache\\ Files/*"
    
    # Telegram
    run_cmd "find ~/Library/Group\\ Containers -name 'Telegram*' -exec rm -rf {}/Telegram/Cache/* \; 2>/dev/null"
    
    # WhatsApp
    run_cmd "find ~/Library/Group\\ Containers -name '*WhatsApp*' -exec rm -rf {}/Cache/* \; 2>/dev/null"
    
    # Notion
    run_cmd "rm -rf ~/Library/Application\\ Support/Notion/Cache/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Notion/GPUCache/*"
    
    # VSCode
    run_cmd "rm -rf ~/Library/Application\\ Support/Code/CachedData/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Code/Cache/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Code/CachedExtensions/*"
    run_cmd "rm -rf ~/Library/Application\\ Support/Code/logs/*"
    
    # Skype
    run_cmd "rm -rf ~/Library/Application\\ Support/Skype/*/media_messaging/media_cache/*"
    run_cmd "rm -rf ~/Library/Caches/com.skype.skype/*"
  else
    # Linux paths for common apps
    local apps_cleaned=0
    
    # Slack
    if [[ -d ~/.config/Slack ]]; then
      log_message "INFO" "Cleaning Slack cache"
      run_cmd "rm -rf ~/.config/Slack/Cache/*"
      run_cmd "rm -rf ~/.config/Slack/Service\\ Worker/CacheStorage/*"
      run_cmd "rm -rf ~/.config/Slack/Code\\ Cache/*"
      run_cmd "rm -rf ~/.config/Slack/logs/*"
      ((apps_cleaned++))
    fi
    
    # Discord
    if [[ -d ~/.config/discord ]]; then
      local discord_size=$(get_size ~/.config/discord/Cache 2>/dev/null || echo "0")
      log_message "INFO" "Discord cache: $discord_size"
      run_cmd "rm -rf ~/.config/discord/Cache/*"
      run_cmd "rm -rf ~/.config/discord/Code\\ Cache/*"
      run_cmd "rm -rf ~/.config/discord/GPUCache/*"
      ((apps_cleaned++))
    fi
    
    # Spotify
    if [[ -d ~/.cache/spotify ]]; then
      local spotify_size=$(get_size ~/.cache/spotify)
      log_message "INFO" "Spotify cache: $spotify_size"
      run_cmd "rm -rf ~/.cache/spotify/*"
      run_cmd "rm -rf ~/.config/spotify/Users/*/Cache/* 2>/dev/null"
      ((apps_cleaned++))
    fi
    
    # Teams
    if [[ -d ~/.config/Microsoft/Teams ]]; then
      log_message "INFO" "Cleaning Teams cache"
      run_cmd "rm -rf ~/.config/Microsoft/Teams/Cache/*"
      run_cmd "rm -rf ~/.config/Microsoft/Teams/Service\\ Worker/CacheStorage/*"
      ((apps_cleaned++))
    fi
    
    # Zoom
    if [[ -d ~/.zoom ]] || [[ -d ~/.cache/zoom ]]; then
      log_message "INFO" "Cleaning Zoom cache"
      run_cmd "rm -rf ~/.zoom/logs/*"
      run_cmd "rm -rf ~/.cache/zoom/*"
      ((apps_cleaned++))
    fi
    
    # Telegram
    if [[ -d ~/.local/share/TelegramDesktop ]]; then
      log_message "INFO" "Cleaning Telegram cache"
      run_cmd "rm -rf ~/.local/share/TelegramDesktop/tdata/user_data/cache/*"
      ((apps_cleaned++))
    fi
    
    # VSCode
    if [[ -d ~/.config/Code ]]; then
      local vscode_size=$(get_size ~/.config/Code/Cache 2>/dev/null || echo "0")
      log_message "INFO" "VSCode cache: $vscode_size"
      run_cmd "rm -rf ~/.config/Code/CachedData/*"
      run_cmd "rm -rf ~/.config/Code/Cache/*"
      run_cmd "rm -rf ~/.config/Code/CachedExtensions/*"
      run_cmd "rm -rf ~/.config/Code/logs/*"
      ((apps_cleaned++))
    fi
    
    # Skype
    if [[ -d ~/.config/skypeforlinux ]]; then
      log_message "INFO" "Cleaning Skype cache"
      run_cmd "rm -rf ~/.config/skypeforlinux/Cache/*"
      ((apps_cleaned++))
    fi
    
    if [[ $apps_cleaned -eq 0 ]]; then
      log_message "INFO" "No third-party app caches found"
    fi
  fi
  
  log_message "SUCCESS" "Third-party apps cleaned"
}

cleanup_mail_attachments() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping mail cleanup on $OS"
    return
  fi
  
  log_message "CLEAN" "Cleaning mail attachments and data..."
  
  # Mail Downloads
  run_cmd "find ~/Library/Mail\\ Downloads -type f -mtime +30 -delete"
  
  # Mail attachment caches
  run_cmd "find ~/Library/Mail -type d -name 'Attachments' -exec find {} -type f -mtime +30 -delete \;"
  
  # Mail envelope index
  run_cmd "rm -rf ~/Library/Mail/V*/MailData/Envelope\\ Index*"
  
  # Mail avatars
  run_cmd "rm -rf ~/Library/Mail/V*/MailData/Avatars/*"
  
  log_message "SUCCESS" "Mail data cleaned"
}

cleanup_development_caches() {
  log_message "CLEAN" "Deep cleaning development environment..."
  
  # Xcode
  if [[ -d ~/Library/Developer/Xcode ]]; then
    run_cmd "rm -rf ~/Library/Developer/Xcode/DerivedData/*"
    run_cmd "rm -rf ~/Library/Developer/Xcode/Archives/*"
    run_cmd "rm -rf ~/Library/Developer/CoreSimulator/Caches/*"
    run_cmd "rm -rf ~/Library/Developer/CoreSimulator/Devices/*/data/Library/Caches/*"
    
    # Clean simulator devices
    if command -v xcrun &>/dev/null; then
      run_cmd "xcrun simctl delete unavailable"
      run_cmd "xcrun simctl erase all"
    fi
  fi
  
  # CocoaPods
  run_cmd "rm -rf ~/.cocoapods/repos/*"
  run_cmd "pod cache clean --all" 2>/dev/null
  
  # Carthage
  run_cmd "rm -rf ~/Library/Caches/org.carthage.CarthageKit/*"
  
  # Swift Package Manager
  run_cmd "rm -rf ~/Library/Developer/SwiftPM/*"
  run_cmd "rm -rf ~/Library/Caches/org.swift.swiftpm/*"
  
  # Android Studio
  run_cmd "rm -rf ~/Library/Caches/AndroidStudio*"
  run_cmd "rm -rf ~/Library/Android/sdk/system-images/*"
  run_cmd "rm -rf ~/.gradle/caches/*"
  run_cmd "rm -rf ~/.gradle/wrapper/dists/*"
  run_cmd "rm -rf ~/.android/build-cache/*"
  run_cmd "rm -rf ~/.android/cache/*"
  
  # JetBrains IDEs
  run_cmd "rm -rf ~/Library/Caches/JetBrains/*"
  run_cmd "rm -rf ~/Library/Logs/JetBrains/*"
  run_cmd "find ~/Library/Application\\ Support/JetBrains -name 'caches' -type d -exec rm -rf {} + 2>/dev/null"
  
  log_message "SUCCESS" "Development caches cleaned"
}

cleanup_package_managers() {
  log_message "CLEAN" "Deep cleaning package manager caches..."

  # macOS Homebrew
  if [[ "$IS_MACOS" == true && $(command -v brew || true) != "" ]]; then
    run_cmd "brew cleanup --prune=all -s"
    run_cmd "brew autoremove"
    run_cmd "rm -rf $(brew --cache)/*"
    run_cmd "rm -rf ~/Library/Caches/Homebrew/*"
    run_cmd "rm -rf ~/Library/Logs/Homebrew/*"
  fi

  # Linux package managers
  if [[ "$IS_LINUX" == true ]]; then
    # apt
    if command -v apt-get &>/dev/null; then
      run_cmd "sudo apt-get autoremove -y"
      run_cmd "sudo apt-get autoclean -y"
      run_cmd "sudo apt-get clean -y"
    fi

    # dnf
    if command -v dnf &>/dev/null; then
      run_cmd "sudo dnf autoremove -y"
      run_cmd "sudo dnf clean all"
    fi

    # pacman
    if command -v pacman &>/dev/null; then
      run_cmd "sudo pacman -Scc --noconfirm"
    fi

    # snap
    if command -v snap &>/dev/null; then
      run_cmd "sudo snap remove --purge $(snap list --all | awk '/disabled/{print $1}') 2>/dev/null || true"
    fi

    # flatpak
    if command -v flatpak &>/dev/null; then
      run_cmd "flatpak uninstall --unused -y"
      run_cmd "flatpak repair"
    fi
  fi

  # npm
  if command -v npm &>/dev/null; then
    run_cmd "npm cache clean --force"
    run_cmd "rm -rf ~/.npm/*"
  fi

  # yarn
  if command -v yarn &>/dev/null; then
    run_cmd "yarn cache clean --all"
    if [[ "$IS_MACOS" == true ]]; then
      run_cmd "rm -rf ~/Library/Caches/Yarn/*"
    else
      run_cmd "rm -rf ~/.cache/yarn/*"
    fi
  fi

  # pnpm
  if command -v pnpm &>/dev/null; then
    run_cmd "pnpm store prune"
  fi

  # pip
  if command -v pip3 &>/dev/null; then
    run_cmd "pip3 cache purge"
    if [[ "$IS_MACOS" == true ]]; then
      run_cmd "rm -rf ~/Library/Caches/pip/*"
    else
      run_cmd "rm -rf ~/.cache/pip/*"
    fi
  fi

  # Composer
  if command -v composer &>/dev/null; then
    run_cmd "composer clear-cache"
    run_cmd "rm -rf ~/.composer/cache/*"
  fi

  # Ruby gems
  if command -v gem &>/dev/null; then
    run_cmd "gem cleanup"
    run_cmd "rm -rf ~/.gem/ruby/*/cache/*"
  fi

  # Rust cargo
  if command -v cargo &>/dev/null; then
    run_cmd "rm -rf ~/.cargo/registry/cache/*"
    run_cmd "rm -rf ~/.cargo/git/db/*"
  fi

  # Go modules
  if command -v go &>/dev/null; then
    run_cmd "go clean -modcache"
  fi

  log_message "SUCCESS" "Package managers cleaned"
}

cleanup_python_environments() {
  log_message "CLEAN" "Deep cleaning Python environments..."
  
  local pycache_count=0
  local pyc_count=0
  
  # Count and clean __pycache__ directories
  log_message "INFO" "Scanning for __pycache__ directories..."
  pycache_count=$(find ~/ -type d -name '__pycache__' 2>/dev/null | wc -l)
  if [[ $pycache_count -gt 0 ]]; then
    log_message "INFO" "Found $pycache_count __pycache__ directories"
    run_cmd "find ~/ -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null"
  fi
  
  # Count and clean .pyc and .pyo files
  log_message "INFO" "Scanning for compiled Python files..."
  pyc_count=$(find ~/ -name '*.pyc' -o -name '*.pyo' 2>/dev/null | wc -l)
  if [[ $pyc_count -gt 0 ]]; then
    log_message "INFO" "Found $pyc_count compiled Python files"
    run_cmd "find ~/ -name '*.pyc' -delete 2>/dev/null"
    run_cmd "find ~/ -name '*.pyo' -delete 2>/dev/null"
  fi
  
  # pytest cache
  local pytest_count=$(find ~/ -type d -name '.pytest_cache' 2>/dev/null | wc -l)
  if [[ $pytest_count -gt 0 ]]; then
    log_message "INFO" "Cleaning $pytest_count pytest caches"
    run_cmd "find ~/ -type d -name '.pytest_cache' -exec rm -rf {} + 2>/dev/null"
  fi
  
  # mypy cache
  local mypy_count=$(find ~/ -type d -name '.mypy_cache' 2>/dev/null | wc -l)
  if [[ $mypy_count -gt 0 ]]; then
    log_message "INFO" "Cleaning $mypy_count mypy caches"
    run_cmd "find ~/ -type d -name '.mypy_cache' -exec rm -rf {} + 2>/dev/null"
  fi
  
  # .hypothesis cache
  run_cmd "find ~/ -type d -name '.hypothesis' -exec rm -rf {} + 2>/dev/null"
  
  # .tox cache
  run_cmd "find ~/ -type d -name '.tox' -exec rm -rf {} + 2>/dev/null"
  
  # .nox cache
  run_cmd "find ~/ -type d -name '.nox' -exec rm -rf {} + 2>/dev/null"
  
  # IPython/Jupyter
  if [[ -d ~/.ipython ]]; then
    log_message "INFO" "Cleaning IPython caches"
    run_cmd "rm -rf ~/.ipython/profile_*/db/*"
  fi
  
  if [[ -d ~/.jupyter ]]; then
    log_message "INFO" "Cleaning Jupyter caches"
    run_cmd "rm -rf ~/.jupyter/lab/workspaces/*"
    run_cmd "rm -rf ~/.local/share/jupyter/runtime/*"
  fi
  
  # pip cache
  if command -v pip3 &>/dev/null; then
    local pip_cache_size=$(du -sh ~/.cache/pip 2>/dev/null | cut -f1 || echo "0")
    if [[ "$pip_cache_size" != "0" ]]; then
      log_message "INFO" "Pip cache size: $pip_cache_size"
      run_cmd "pip3 cache purge"
    fi
  fi
  
  # Virtual environments (be careful)
  if confirm "Search and clean unused Python virtual environments?"; then
    run_cmd "find ~/ -type d -name 'venv' -o -name '.venv' -o -name 'env' | xargs -I {} sh -c 'test -f {}/bin/activate && echo {} && rm -rf {}' 2>/dev/null"
  fi
  
  log_message "SUCCESS" "Python environments cleaned"
}

cleanup_node_modules() {
  log_message "CLEAN" "Scanning for node_modules directories..."
  
  if ! confirm "Deep clean node_modules? (This may take time)"; then
    log_message "INFO" "Skipping node_modules cleanup"
    return
  fi
  
  # Find all node_modules directories
  local node_modules_dirs=$(find ~/ -type d -name "node_modules" -not -path "*/node_modules/*" 2>/dev/null)
  
  if [[ -z "$node_modules_dirs" ]]; then
    log_message "INFO" "No node_modules directories found"
    return
  fi
  
  local total_size=0
  local count=0
  
  while IFS= read -r dir; do
    if [[ -z "$dir" ]]; then continue; fi
    
    local parent=$(dirname "$dir")
    local pkg_json="$parent/package.json"
    
    # Check if project is inactive (not modified in 30 days)
    if [[ -f "$pkg_json" ]]; then
      # Get modification time (compatible with macOS and Linux)
      local file_mtime
      if [[ "$IS_MACOS" == true ]]; then
        file_mtime=$(stat -f "%m" "$pkg_json" 2>/dev/null || echo "0")
      else
        file_mtime=$(stat -c "%Y" "$pkg_json" 2>/dev/null || echo "0")
      fi
      local days_old=$(( ($(date +%s) - file_mtime) / 86400 ))
      
      if [[ $days_old -gt 30 ]]; then
        local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        log_message "INFO" "Removing inactive project node_modules: $dir ($size)"
        run_cmd "rm -rf '$dir'"
        ((count++))
      fi
    else
      # No package.json, probably orphaned
      run_cmd "rm -rf '$dir'"
      ((count++))
    fi
  done <<< "$node_modules_dirs"
  
  log_message "SUCCESS" "Cleaned $count node_modules directories"
}

cleanup_docker() {
  log_message "CLEAN" "Deep cleaning Docker resources..."
  
  if ! command -v docker &>/dev/null; then
    log_message "INFO" "Docker not found, skipping"
    return
  fi
  
  # Check if Docker daemon is running
  if ! docker info >/dev/null 2>&1; then
    log_message "WARN" "Docker daemon not running, skipping Docker cleanup"
    return
  fi
  
  # Complete Docker cleanup
  run_cmd "docker system prune -af --volumes"
  run_cmd "docker builder prune -af"
  run_cmd "docker image prune -af"
  run_cmd "docker volume prune -af"
  run_cmd "docker network prune -f"
  
  # Remove old Docker.raw if exists
  local docker_raw_old=~/Library/Containers/com.docker.docker/Data/vms/0/Docker.raw.old
  if [[ -f "$docker_raw_old" ]]; then
    local size=$(get_size "$docker_raw_old")
    log_message "INFO" "Removing old Docker.raw ($size)"
    run_cmd "rm -f '$docker_raw_old'"
  fi
  
  log_message "SUCCESS" "Docker cleanup completed"
}

cleanup_git_repositories() {
  log_message "CLEAN" "Optimizing Git repositories..."
  
  if ! confirm "Deep clean and optimize Git repositories?"; then
    log_message "INFO" "Skipping Git cleanup"
    return
  fi
  
  local git_dirs=$(find ~/ -name ".git" -type d 2>/dev/null | head -50)
  
  if [[ -z "$git_dirs" ]]; then
    log_message "INFO" "No Git repositories found"
    return
  fi
  
  while IFS= read -r git_dir; do
    if [[ -z "$git_dir" ]]; then continue; fi
    
    local repo_dir=$(dirname "$git_dir")
    log_message "INFO" "Optimizing: $repo_dir"
    
    # Clean and optimize
    run_cmd "cd '$repo_dir' && git reflog expire --expire=now --all"
    run_cmd "cd '$repo_dir' && git gc --prune=now --aggressive"
    run_cmd "cd '$repo_dir' && git repack -Ad"
    run_cmd "cd '$repo_dir' && git prune-packed"
    
    # Clean git lfs if present
    if [[ -f "$repo_dir/.gitattributes" ]] && grep -q "filter=lfs" "$repo_dir/.gitattributes"; then
      run_cmd "cd '$repo_dir' && git lfs prune"
    fi
  done <<< "$git_dirs"
  
  log_message "SUCCESS" "Git repositories optimized"
}

optimize_system_databases() {
  log_message "CLEAN" "Optimizing system databases..."
  
  # Optimize SQLite databases
  find ~/Library -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" 2>/dev/null | while read db; do
    if [[ -f "$db" && -w "$db" ]]; then
      run_cmd "sqlite3 '$db' 'VACUUM;' 2>/dev/null"
      run_cmd "sqlite3 '$db' 'REINDEX;' 2>/dev/null"
    fi
  done
  
  # Clean Core Data stores
  run_cmd "rm -rf ~/Library/Application\\ Support/com.apple.sharedfilelist/*"
  run_cmd "rm -rf ~/Library/Application\\ Support/com.apple.appstoreagent/*"
  
  log_message "SUCCESS" "Databases optimized"
}

optimize_memory_and_swap() {
  log_message "CLEAN" "Optimizing memory and swap..."
  
  # Purge inactive memory
  if command -v purge &>/dev/null; then
    run_cmd "sudo purge"
  fi
  
  # Clean swap files
  run_cmd "sudo rm -rf /private/var/vm/swapfile*"
  
  # Restart memory-intensive services
  run_cmd "sudo killall -KILL mds"
  run_cmd "sudo killall -KILL mds_stores"
  
  log_message "SUCCESS" "Memory optimized"
}

cleanup_network_caches() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping network caches cleanup on $OS"
    return
  fi
  
  log_message "CLEAN" "Cleaning network and DNS caches..."
  
  # Flush DNS cache
  run_cmd "sudo dscacheutil -flushcache"
  run_cmd "sudo killall -HUP mDNSResponder"
  
  # Clear network preferences cache
  run_cmd "sudo rm -rf /Library/Preferences/SystemConfiguration/CaptiveNetworkSupport/cache.plist"
  run_cmd "sudo rm -rf /Library/Preferences/com.apple.wifi.plist"
  
  log_message "SUCCESS" "Network caches cleaned"
}

cleanup_quicklook_cache() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping QuickLook cleanup on $OS"
    return
  fi
  
  log_message "CLEAN" "Cleaning QuickLook cache..."
  
  run_cmd "qlmanage -r cache"
  run_cmd "rm -rf ~/Library/Caches/com.apple.QuickLookDaemon/*"
  run_cmd "rm -rf ~/Library/Application\\ Support/Quick\\ Look/*"
  
  log_message "SUCCESS" "QuickLook cache cleaned"
}

cleanup_font_caches() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping font cache rebuild on $OS"
    return
  fi

  log_message "CLEAN" "Rebuilding font caches..."

  run_cmd "sudo atsutil databases -remove"
  run_cmd "sudo atsutil server -shutdown"
  run_cmd "sudo atsutil server -ping"
  run_cmd "rm -rf ~/Library/Fonts/.*.cache"
  run_cmd "rm -rf /System/Library/Caches/com.apple.ATS/*"

  log_message "SUCCESS" "Font caches rebuilt"
}

find_large_files() {
  log_message "INFO" "Scanning for large files..."
  
  local size_threshold="1G"
  
  log_message "INFO" "Finding files larger than $size_threshold..."
  
  # Focus on common locations with large files
  local search_paths=(
    ~/Downloads
    ~/Desktop
    ~/Documents
    ~/Movies
    ~/.Trash
  )
  
  for path in "${search_paths[@]}"; do
    if [[ -d "$path" ]]; then
      local large_files=$(find "$path" -type f -size +$size_threshold 2>/dev/null | head -10)
      if [[ -n "$large_files" ]]; then
        echo "Large files in $path:"
        echo "$large_files" | xargs -I{} du -h "{}" 2>/dev/null | sort -hr
      fi
    fi
  done
}

# cleanup_old_downloads() {
#   log_message "CLEAN" "Cleaning old downloads..."
  
#   # Remove old files in Downloads (>60 days)
#   if confirm "Remove files in Downloads older than 60 days?"; then
#     run_cmd "find ~/Downloads -type f -mtime +60 -delete"
#     run_cmd "find ~/Downloads -type d -empty -delete"
#   fi
  
#   # Clean Desktop old files (>90 days)
#   if confirm "Remove files on Desktop older than 90 days?"; then
#     run_cmd "find ~/Desktop -type f -mtime +90 -delete"
#   fi
  
#   log_message "SUCCESS" "Old downloads cleaned"
# }

cleanup_application_support() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping Application Support cleanup on $OS"
    return
  fi
  
  log_message "CLEAN" "Cleaning Application Support orphaned data..."
  
  # Find Application Support folders for uninstalled apps
  local app_support=~/Library/Application\ Support
  
  # Clean known uninstalled apps residues
  local orphaned_apps=(
    "com.apple.garageband*"
    "com.apple.iMovieApp"
    "CleanMyMac*"
    "Parallels"
    "VMware*"
    "CrossOver"
    "Little Snitch"
  )
  
  for app in "${orphaned_apps[@]}"; do
    if [[ -d "$app_support/$app" ]]; then
      run_cmd "rm -rf '$app_support/$app'"
    fi
  done
  
  log_message "SUCCESS" "Application Support cleaned"
}

cleanup_preferences() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping preferences cleanup on $OS"
    return
  fi
  
  log_message "CLEAN" "Cleaning orphaned preferences..."
  
  # Remove preference files for uninstalled apps
  run_cmd "find ~/Library/Preferences -name '*.plist' -size 0 -delete"
  
  # Remove lock files
  run_cmd "find ~/Library/Preferences -name '*.lockfile' -delete"
  run_cmd "find ~/Library/Preferences -name '*.plist.lock' -delete"
  
  log_message "SUCCESS" "Preferences cleaned"
}

cleanup_launch_agents() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping launch agents cleanup on $OS"
    return
  fi
  
  log_message "CLEAN" "Cleaning launch agents and daemons..."
  
  # User launch agents for uninstalled apps
  local launch_agents_paths=(
    ~/Library/LaunchAgents
    /Library/LaunchAgents
    /Library/LaunchDaemons
  )
  
  for path in "${launch_agents_paths[@]}"; do
    if [[ -d "$path" ]]; then
      # Remove broken symlinks
      run_cmd "find '$path' -type l ! -exec test -e {} \; -delete"
      
      # Remove known obsolete agents
      run_cmd "rm -f '$path'/com.adobe.* 2>/dev/null"
      run_cmd "rm -f '$path'/com.oracle.* 2>/dev/null"
      run_cmd "rm -f '$path'/com.microsoft.update.* 2>/dev/null"
    fi
  done
  
  log_message "SUCCESS" "Launch agents cleaned"
}

cleanup_receipts() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping receipts cleanup on $OS"
    return
  fi
  
  log_message "CLEAN" "Cleaning installation receipts..."
  
  # Clean old receipts
  run_cmd "sudo rm -rf /Library/Receipts/*.pkg"
  run_cmd "sudo find /Library/Receipts -name '*.bom' -delete"
  
  # Clean installer packages cache
  run_cmd "sudo rm -rf /Library/Caches/com.apple.installd.plist"
  
  log_message "SUCCESS" "Receipts cleaned"
}

cleanup_diagnostics() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping diagnostics cleanup on $OS"
    return
  fi
  
  log_message "CLEAN" "Cleaning diagnostic reports..."
  
  # Clean diagnostic reports older than 7 days
  run_cmd "find ~/Library/Logs/DiagnosticReports -type f -mtime +7 -delete"
  run_cmd "sudo find /Library/Logs/DiagnosticReports -type f -mtime +7 -delete"
  
  # Clean crash reports
  run_cmd "rm -rf ~/Library/Application\\ Support/CrashReporter/*"
  
  # Clean hang reports
  run_cmd "rm -rf ~/Library/Logs/HangReporter/*"
  
  log_message "SUCCESS" "Diagnostics cleaned"
}

cleanup_containers() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping containers cleanup on $OS"
    return
  fi
  
  log_message "CLEAN" "Cleaning app containers..."
  
  # Clean container caches
  run_cmd "find ~/Library/Containers -type d -name 'Caches' -exec sh -c 'rm -rf {}/*' \; 2>/dev/null"
  
  # Clean container logs
  run_cmd "find ~/Library/Containers -type d -name 'Logs' -exec sh -c 'rm -rf {}/*' \; 2>/dev/null"
  
  # Clean container tmp
  run_cmd "find ~/Library/Containers -type d -name 'tmp' -exec sh -c 'rm -rf {}/*' \; 2>/dev/null"
  
  log_message "SUCCESS" "Containers cleaned"
}

cleanup_spotlight() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping Spotlight reindex on $OS"
    return
  fi

  log_message "CLEAN" "Rebuilding Spotlight index..."

  if confirm "Rebuild Spotlight index? (Mac may be slow during reindexing)"; then
    run_cmd "sudo mdutil -E /"
    run_cmd "sudo mdutil -i on /"
    run_cmd "sudo rm -rf /.Spotlight-V100"
    run_cmd "sudo rm -rf ~/Library/Metadata/CoreSpotlight"
  fi

  log_message "SUCCESS" "Spotlight reindexed"
}

cleanup_icloud_cache() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping iCloud cleanup on $OS"
    return
  fi
  
  log_message "CLEAN" "Cleaning iCloud cache..."
  
  # iCloud Drive cache
  run_cmd "rm -rf ~/Library/Caches/CloudKit/*"
  run_cmd "rm -rf ~/Library/Caches/com.apple.bird/*"
  
  # Clean Mobile Documents caches
  if [[ -d ~/Library/Mobile\ Documents ]]; then
    run_cmd "find ~/Library/Mobile\\ Documents -name '.Trash' -type d -exec rm -rf {} + 2>/dev/null"
    run_cmd "find ~/Library/Mobile\\ Documents -name 'Downloads' -type d -exec sh -c 'find {} -type f -mtime +30 -delete' \; 2>/dev/null"
  fi
  
  log_message "SUCCESS" "iCloud cache cleaned"
}

cleanup_ruby_environment() {
  log_message "CLEAN" "Cleaning Ruby environment..."
  
  # Clean gem documentation
  if command -v gem &>/dev/null; then
    run_cmd "rm -rf ~/.gem/ruby/*/doc/*"
    run_cmd "rm -rf ~/.gem/ruby/*/gems/*/test/*"
    run_cmd "rm -rf ~/.gem/ruby/*/gems/*/spec/*"
  fi
  
  # Clean rbenv/rvm caches
  run_cmd "rm -rf ~/.rbenv/cache/*"
  run_cmd "rm -rf ~/.rvm/archives/*"
  run_cmd "rm -rf ~/.rvm/log/*"
  run_cmd "rm -rf ~/.rvm/tmp/*"
  
  log_message "SUCCESS" "Ruby environment cleaned"
}

cleanup_audio_caches() {
  if [[ "$IS_MACOS" != true ]]; then
    log_message "INFO" "Skipping audio caches cleanup on $OS"
    return
  fi
  
  log_message "CLEAN" "Cleaning audio and music caches..."
  
  # Music/iTunes cache
  run_cmd "rm -rf ~/Library/Caches/com.apple.Music/*"
  run_cmd "rm -rf ~/Library/Caches/com.apple.iTunes/*"
  run_cmd "rm -rf ~/Library/Caches/com.apple.AMPArtworkAgent/*"
  
  # GarageBand
  run_cmd "rm -rf ~/Library/Caches/com.apple.garageband*"
  run_cmd "rm -rf ~/Library/Audio/Plug-Ins/Components/*.component/Contents/Resources/Snapshots/*"
  
  # Logic Pro
  run_cmd "rm -rf ~/Library/Caches/com.apple.logic*"
  run_cmd "rm -rf ~/Music/Audio\\ Music\\ Apps/Bounce/*"
  
  log_message "SUCCESS" "Audio caches cleaned"
}

cleanup_virtualenvs() {
  log_message "CLEAN" "Cleaning virtual environments..."
  
  # Python virtualenvs
  local venv_dirs=(
    ~/.virtualenvs
    ~/.venvs
    ~/envs
  )
  
  for venv_dir in "${venv_dirs[@]}"; do
    if [[ -d "$venv_dir" ]]; then
      if confirm "Clean virtual environments in $venv_dir?"; then
        # Remove virtualenvs not accessed in 60 days
        run_cmd "find '$venv_dir' -maxdepth 1 -type d -atime +60 -exec rm -rf {} \;"
      fi
    fi
  done
  
  # Conda environments
  if command -v conda &>/dev/null; then
    run_cmd "conda clean --all -y"
    run_cmd "rm -rf ~/.conda/pkgs/*"
  fi
  
  log_message "SUCCESS" "Virtual environments cleaned"
}

generate_summary() {
  local before_space="$1"
  local after_space=$(get_free_space)
  
  # Convert space to bytes for calculation if possible
  local space_freed="N/A"
  
  # Calculate freed space if we have numeric values
  if [[ "$before_space" =~ ^[0-9.]+G$ ]] && [[ "$after_space" =~ ^[0-9.]+G$ ]]; then
    local before_num=$(echo "$before_space" | sed 's/G//')
    local after_num=$(echo "$after_space" | sed 's/G//')
    local freed=$(echo "$after_num - $before_num" | bc 2>/dev/null || echo "0")
    if [[ "$freed" != "0" ]]; then
      space_freed="${freed}G"
    fi
  fi
  
  echo
  echo -e "${BOLD}${WHITE}===============================================================================${NC}"
  echo -e "${BOLD}${CYAN}                        SYSTEM CLEANUP REPORT${NC}"
  echo -e "${BOLD}${WHITE}===============================================================================${NC}"
  echo
  echo -e "  ${GRAY}Operating System    :${NC} ${WHITE}$OS_NAME${NC}"
  echo -e "  ${GRAY}Cleanup Date        :${NC} ${WHITE}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
  echo -e "  ${GRAY}User                :${NC} ${WHITE}$USER${NC}"
  echo
  echo -e "${BLUE}-------------------------------------------------------------------------------${NC}"
  echo -e "${BOLD}${YELLOW}  DISK SPACE SUMMARY${NC}"
  echo -e "${BLUE}-------------------------------------------------------------------------------${NC}"
  echo
  printf "  ${GRAY}%-30s${NC} ${CYAN}%s${NC}\n" "Free space before:" "$before_space"
  printf "  ${GRAY}%-30s${NC} ${GREEN}%s${NC}\n" "Free space after:" "$after_space"
  if [[ "$space_freed" != "N/A" ]]; then
    printf "  ${GRAY}%-30s${NC} ${BOLD}${GREEN}%s${NC}\n" "Space recovered:" "$space_freed"
  fi
  echo
  echo -e "${BLUE}-------------------------------------------------------------------------------${NC}"
  echo -e "${BOLD}${YELLOW}  CLEANED COMPONENTS${NC}"
  echo -e "${BLUE}-------------------------------------------------------------------------------${NC}"
  echo
  
  if [[ "$IS_MACOS" == true ]]; then
    echo -e "  ${GREEN}[+]${NC} System & user caches"
    echo -e "  ${GREEN}[+]${NC} macOS application states"
    echo -e "  ${GREEN}[+]${NC} iOS device support & backups"
    echo -e "  ${GREEN}[+]${NC} Photos library optimization"
    echo -e "  ${GREEN}[+]${NC} Time Machine snapshots"
    echo -e "  ${GREEN}[+]${NC} QuickLook & font caches"
    echo -e "  ${GREEN}[+]${NC} Spotlight index optimization"
  else
    echo -e "  ${GREEN}[+]${NC} System & user caches"
    echo -e "  ${GREEN}[+]${NC} Trash & temporary files"
    echo -e "  ${GREEN}[+]${NC} Old log files & backups"
    echo -e "  ${GREEN}[+]${NC} Shell history optimization"
    echo -e "  ${GREEN}[+]${NC} Desktop thumbnails cache"
  fi
  
  echo -e "  ${GREEN}[+]${NC} Browser caches (Chrome, Firefox, Edge, Brave)"
  echo -e "  ${GREEN}[+]${NC} Third-party applications (VSCode, Discord, Slack, etc.)"
  echo -e "  ${GREEN}[+]${NC} Development environments (Python, Node.js, Ruby, Go, Rust)"
  echo -e "  ${GREEN}[+]${NC} Package manager caches (npm, pip, yarn, gem, cargo)"
  echo -e "  ${GREEN}[+]${NC} Docker images & containers"
  echo -e "  ${GREEN}[+]${NC} Git repositories optimization"
  echo -e "  ${GREEN}[+]${NC} Database optimization (SQLite)"
  echo
  echo -e "${BLUE}-------------------------------------------------------------------------------${NC}"
  echo -e "${BOLD}${YELLOW}  RECOMMENDATIONS${NC}"
  echo -e "${BLUE}-------------------------------------------------------------------------------${NC}"
  echo
  if [[ "$IS_MACOS" == true ]]; then
    echo -e "  ${CYAN}*${NC} Restart your system for optimal performance"
    echo -e "  ${CYAN}*${NC} Run this script monthly for best results"
    echo -e "  ${CYAN}*${NC} Some applications may rebuild caches on next launch"
    echo -e "  ${CYAN}*${NC} Consider reviewing large files manually"
  else
    echo -e "  ${CYAN}*${NC} Clear browser cache manually for additional space"
    echo -e "  ${CYAN}*${NC} Run this script weekly for optimal performance"
    echo -e "  ${CYAN}*${NC} Review large files in ~/Documents and ~/Downloads"
    echo -e "  ${CYAN}*${NC} Consider cleaning package manager caches with sudo privileges"
  fi
  echo
  echo -e "${BLUE}-------------------------------------------------------------------------------${NC}"
  echo -e "${BOLD}${YELLOW}  DETAILS${NC}"
  echo -e "${BLUE}-------------------------------------------------------------------------------${NC}"
  echo
  echo -e "  ${GRAY}Log file:${NC} ${WHITE}$LOG_FILE${NC}"
  echo
  echo -e "${BOLD}${WHITE}===============================================================================${NC}"
  echo
}

main() {
  clear
  echo -e "${BOLD}${WHITE}===============================================================================${NC}"
  echo -e "${BOLD}${CYAN}                   ENHANCED SYSTEM CLEANER v3.0${NC}"
  echo -e "${BOLD}${WHITE}===============================================================================${NC}"
  echo
  echo -e "  ${GRAY}Platform:${NC} ${WHITE}$OS_NAME${NC}"
  echo -e "  ${GRAY}User:${NC} ${WHITE}$USER${NC}"
  echo -e "  ${GRAY}Date:${NC} ${WHITE}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
  echo
  echo -e "${BLUE}-------------------------------------------------------------------------------${NC}"
  echo
  
  check_permissions
  
  local before_space=$(get_free_space)
  log_message "INFO" "Starting cleanup - Free space: $before_space"
  echo
  echo -e "${MAGENTA}-------------------------------------------------------------------------------${NC}"
  echo -e "${BOLD}${WHITE}  PHASE 1: SYSTEM CLEANUP${NC}"
  echo -e "${MAGENTA}-------------------------------------------------------------------------------${NC}"
  echo
  
  # Core system cleanup
  if [[ "$IS_MACOS" == true ]]; then
    cleanup_macos_system
    cleanup_time_machine
  elif [[ "$IS_LINUX" == true ]]; then
    cleanup_linux_system
    cleanup_old_logs_and_temp
  fi
  cleanup_saved_application_states
  
  echo
  echo -e "${MAGENTA}-------------------------------------------------------------------------------${NC}"
  echo -e "${BOLD}${WHITE}  PHASE 2: APPLICATIONS & BROWSERS${NC}"
  echo -e "${MAGENTA}-------------------------------------------------------------------------------${NC}"
  echo
  
  # iOS and Photos
  cleanup_ios_device_support
  cleanup_ios_backups
  cleanup_photos_library
  
  # Applications
  cleanup_browsers
  cleanup_third_party_apps
  cleanup_mail_attachments
  cleanup_application_support
  cleanup_preferences
  cleanup_containers
  
  echo
  echo -e "${MAGENTA}-------------------------------------------------------------------------------${NC}"
  echo -e "${BOLD}${WHITE}  PHASE 3: DEVELOPMENT ENVIRONMENTS${NC}"
  echo -e "${MAGENTA}-------------------------------------------------------------------------------${NC}"
  echo
  
  # Development
  cleanup_development_caches
  cleanup_package_managers
  cleanup_python_environments
  cleanup_ruby_environment
  cleanup_virtualenvs
  cleanup_node_modules
  cleanup_docker
  cleanup_git_repositories
  
  echo
  echo -e "${MAGENTA}-------------------------------------------------------------------------------${NC}"
  echo -e "${BOLD}${WHITE}  PHASE 4: SYSTEM OPTIMIZATION${NC}"
  echo -e "${MAGENTA}-------------------------------------------------------------------------------${NC}"
  echo
  
  # System optimization
  optimize_system_databases
  optimize_memory_and_swap
  cleanup_network_caches
  cleanup_quicklook_cache
  cleanup_font_caches
  
  # Advanced cleanup
  cleanup_launch_agents
  cleanup_receipts
  cleanup_diagnostics
  cleanup_icloud_cache
  cleanup_audio_caches
  cleanup_spotlight
  
  echo
  echo -e "${MAGENTA}-------------------------------------------------------------------------------${NC}"
  echo -e "${BOLD}${WHITE}  PHASE 5: ANALYSIS & REPORTING${NC}"
  echo -e "${MAGENTA}-------------------------------------------------------------------------------${NC}"
  echo
  
  # File management
  # cleanup_old_downloads
  find_large_files
  
  # Generate final summary
  echo
  generate_summary "$before_space"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--dry-run)
      DRY_RUN=true
      log_message "INFO" "Dry-run mode enabled"
      ;;
    -y|--yes)
      AUTO_YES=true
      log_message "INFO" "Auto-confirm mode enabled"
      ;;
    -v|--verbose)
      VERBOSE=true
      log_message "INFO" "Verbose mode enabled"
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      log_message "ERROR" "Unknown option: $1"
      print_help
      exit 1
      ;;
  esac
  shift
done

# Main execution
if [[ "$AUTO_YES" == true ]] || confirm "Start deep macOS cleanup? This will free up significant disk space."; then
  main
else
  log_message "INFO" "Cleanup cancelled"
  exit 0
fi