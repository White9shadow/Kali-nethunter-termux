# Changelog

## [2025-06-20](https://github.com/White9shadow/Kali-nethunter-termux/commit/09ccbed8fadc88ca671014001cf60cd3be6d03d7)
### Updated: `nethunter.sh`

#### Major changes:
- **Version Bump**: Updated `VERSION` from `2020011601` to `20250620`.
- **Image Details**: Set `IMAGE_NAME` and `SHA_NAME` specifically for arm64 (`kali-nethunter-rootfs-nano-arm64.tar.xz`).
- **New Variables**: Introduced `CHROOT` path and updated variable usage for better clarity.
- **Color Definitions**: Moved color variable definitions up and streamlined their use.

#### Functionality Changes & Improvements:
- **Dependency Handling**:
  - Added `curl` to the dependency check/install list.
  - Improved apt update/upgrade logic for reliability (`--fix-missing` used).
  - Added `fix_apt_cache` function to address Termux apt cache/source issues.
- **User Input & Arguments**:
  - Cleaned up and improved the `ask()` function (removed legacy code, clarified prompts).
  - Added support for an `--insecure` argument for downloads (with validation).
- **Architecture and Setup**:
  - Removed device architecture detection logic and hardcoded for arm64.
  - Deprecated functions for setting strings and unsupported architectures.
- **Rootfs Handling & Verification**:
  - Simplified rootfs download URLs, download logic, and error reporting.
  - Enhanced SHA verification:
    - Now attempts to download and verify with SHA512 first, then SHA256 as fallback.
    - Warnings are given if verification files are unavailable.
    - Improved error handling if hash or extraction fails.
- **Extraction & Install Path**:
  - Ensured extraction path is set to Termux home directory for arm64.
  - Added checks for storage permissions.
- **Launcher & Shortcuts**:
  - Cleaned up nethunter launcher creation.
  - Removed legacy KeX launcher creation and related logic.
- **Permissions & Sudo**:
  - Retained fixes for `sudo`/`su` permissions and sudoers configuration.
- **General Cleanup**:
  - Removed outdated or unused functions (e.g., architecture checks, KeX setup).
  - Refined banner and output messages.
  - Streamlined main script logic: removed unnecessary calls, improved output clarity.

#### User Instructions:
- Updated the post-install instructions to remove KeX references.
- Now only CLI and root-launch instructions are provided.
