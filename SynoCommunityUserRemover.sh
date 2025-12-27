#!/bin/sh

# =============================================================================
# SynoCommunityUserRemover: SynoCommunity Package User (sc-*) Removal Tool
# Tianyu (Sky) Lu (tianyu@lu.fm)
# 2025-12-26
# =============================================================================
# Copyright 2025 Tianyu (Sky) Lu
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================

set -eu

# ANSI color codes (disabled if stdout is not a TTY)
if [ -t 1 ]; then
  ansi_red="\033[1;31m"
  ansi_white="\033[1;37m"
  ansi_green="\033[1;32m"
  ansi_yellow="\033[1;33m"
  ansi_blue="\033[1;34m"
  ansi_bell="\007"
  ansi_blink="\033[5m"
  ansi_std="\033[m"
  ansi_rev="\033[7m"
  ansi_ul="\033[4m"
else
  ansi_red=""
  ansi_white=""
  ansi_green=""
  ansi_yellow=""
  ansi_blue=""
  ansi_bell=""
  ansi_blink=""
  ansi_std=""
  ansi_rev=""
  ansi_ul=""
fi

SYNOUSER="/usr/syno/sbin/synouser"
SYNOGROUP="/usr/syno/sbin/synogroup"

# Helper functions for colored output
# Note: Use %b instead of %s to interpret escape sequences in arguments
print_info() {
  printf "${ansi_blue}[INFO]${ansi_std} %b\n" "$1"
}

print_success() {
  printf "${ansi_green}[OK]${ansi_std} %b\n" "$1"
}

print_warn() {
  printf "${ansi_yellow}[WARN]${ansi_std} %b\n" "$1"
}

print_error() {
  printf "${ansi_red}[ERROR]${ansi_std} %b\n" "$1" >&2
}

print_warning_banner() {
  echo ""
  printf "${ansi_red}╔═════════════════════════════════════════════════════════════╗${ansi_std}\n"
  printf "${ansi_red}║${ansi_std}  ${ansi_yellow}⚠  WARNING: DESTRUCTIVE SCRIPT - USE AT YOUR OWN RISK!  ⚠${ansi_std}  ${ansi_red}║${ansi_std}\n"
  printf "${ansi_red}╚═════════════════════════════════════════════════════════════╝${ansi_std}\n"
  echo ""
}

need_root() {
  if [ "$(id -u)" != "0" ]; then
    print_error "Please run as root (DSM7: run 'sudo -i' first)"
    exit 1
  fi
}

confirm() {
  printf "${ansi_yellow}Type \"DELETE\" to confirm deleting user %s: ${ansi_std}" "$1"
  read ans
  [ "$ans" = "DELETE" ] || { print_info "Aborted."; exit 0; }
}

list_sc_users() {
  # No root required since /etc/passwd is world-readable
  print_info "Listing all sc-* users:"
  awk -F: '$1 ~ /^sc-[A-Za-z0-9._-]+$/ {print $1}' /etc/passwd
}

user_exists() {
  grep -q "^$1:" /etc/passwd 2>/dev/null
}

group_exists() {
  grep -q "^$1:" /etc/group 2>/dev/null
}

scan_uid_files() {
  need_root
  print_warning_banner

  u="$1"
  rootpath="$2"
  # Use absolute path so users always know where the file is saved
  outfile="$(pwd)/${u}_owned.txt"

  if ! user_exists "$u"; then
    print_error "User does not exist: $u"
    exit 2
  fi

  if [ ! -d "$rootpath" ]; then
    print_error "Path not found or not a directory: $rootpath"
    exit 2
  fi

  if [ ! -r "$rootpath" ]; then
    print_error "Path is not readable: $rootpath"
    exit 2
  fi

  uid="$(id -u "$u")"
  print_info "User ${ansi_white}$u${ansi_std} has UID=${ansi_yellow}$uid${ansi_std}"
  print_info "Scanning files owned by ${ansi_white}$u${ansi_std} under ${ansi_blue}$rootpath${ansi_std} ..."
  echo ""

  if touch "$outfile" 2>/dev/null; then
      write_ok=1
  else
      write_ok=0
      print_error "Cannot write to ${ansi_white}$outfile${ansi_std}"
      print_warn "Results will be printed to stdout instead."
      echo ""
  fi

  # Suppress find errors (permission denied on some subdirs is common)
  if [ "$write_ok" = "1" ]; then
      file_count=$(find "$rootpath" -uid "$uid" -print 2>/dev/null | tee "$outfile" | wc -l | tr -d ' ') || true
  else
      file_count=$(find "$rootpath" -uid "$uid" -print 2>/dev/null | wc -l | tr -d ' ') || true
  fi
  file_count="${file_count:-0}"  # Fallback to 0 if empty

  echo ""
  print_success "Scan complete. Found ${ansi_yellow}$file_count${ansi_std} files/directories."

  if [ "$file_count" -gt 0 ]; then
    if [ "$write_ok" = "1" ]; then
      print_info "Results saved to: ${ansi_white}$outfile${ansi_std}"
      echo ""

      printf "${ansi_yellow}To change ownership of all listed files:${ansi_std}\n"
      printf "  ${ansi_white}tr '\\\\n' '\\\\0' < '%s' | xargs -0 chown ${ansi_blue}<NEW_USER>:<NEW_GROUP>${ansi_std}\n" "$outfile"
      echo ""

      printf "${ansi_yellow}To delete all listed files (${ansi_red}USE WITH CAUTION${ansi_yellow}):${ansi_std}\n"
      printf "  ${ansi_white}tr '\\\\n' '\\\\0' < '%s' | xargs -0 rm -rf${ansi_std}\n" "$outfile"
      echo ""

      print_warn "Review the file list carefully before running \"rm\" or \"chown\" commands!"
      echo ""
    fi
  else
    # Remove empty output file if no results found
    [ "$write_ok" = "1" ] && rm -f "$outfile" 2>/dev/null || true
    print_info "No files found owned by this user under $rootpath."
  fi
}

del_user_group() {
  need_root
  print_warning_banner

  u="$1"
  apply="${2:-0}"

  if ! user_exists "$u"; then
    print_error "User does not exist: ${ansi_white}$u${ansi_std}"
    exit 2
  fi

  print_info "Recommended: Run ${ansi_white}$0 scan $u <path>${ansi_std} first to check all files owned by this user!"
  echo ""

  # Check for related package status
  pkg_name="${u#sc-}"
  if command -v synopkg >/dev/null 2>&1; then
    pkg_status=$(synopkg status "$pkg_name" 2>/dev/null || true)
    if ! printf '%s' "$pkg_status" | grep -q '"status":"non_installed"'; then
      print_warn "Related package ${ansi_white}$pkg_name${ansi_std} detected:"
      printf "  ${ansi_white}%s${ansi_std}\n" "$pkg_status"
      echo ""
      print_warn "Consider uninstalling or stopping the package first:"
      printf "  ${ansi_white}synopkg stop %s${ansi_std}\n" "$pkg_name"
      printf "  ${ansi_white}synopkg uninstall %s${ansi_std}\n" "$pkg_name"
      echo ""
    fi
  fi

  # Check for running processes
  procs=$(ps -eo user,pid,args 2>/dev/null | awk -v u="$u" 'NR == 1 || $1 == u' | head -n 21) || true
  procs="${procs:-}"  # Fallback to empty if command fails
  proc_count=$(printf '%s\n' "$procs" | awk -v u="$u" '$1 == u' | wc -l | tr -d ' ') || true
  proc_count="${proc_count:-0}"  # Fallback to 0 if empty
  if [ "$proc_count" -gt 0 ]; then
    print_warn "There are still processes running as ${ansi_white}$u${ansi_std}. Consider stopping related packages/services first:"
    printf '%s\n' "$procs"
    echo ""
  fi

  if [ "$apply" = "1" ]; then
    # Require explicit confirmation before destructive action
    confirm "$u"
    echo ""

    print_info "Deleting user: ${ansi_white}$u${ansi_std}"
    "$SYNOUSER" --del "$u"
    if group_exists "$u"; then
      print_info "Deleting group with same name: ${ansi_white}$u${ansi_std}"
      "$SYNOGROUP" --del "$u" || true
    fi
    print_success "Done."
  else
    printf "${ansi_yellow}[DRY-RUN]${ansi_std} Commands that would be executed:\n"
    printf "  ${ansi_white}%s --del %s${ansi_std}\n" "$SYNOUSER" "$u"
    if group_exists "$u"; then
      printf "  ${ansi_white}%s --del %s${ansi_std}\n" "$SYNOGROUP" "$u"
    fi
    echo ""
    print_info "To actually execute, add ${ansi_green}--apply${ansi_std}"
  fi
}

usage() {
  printf "${ansi_white}SynoCommunity User Remover${ansi_std}\n"
  echo "--------------------------"
  printf "Remove sc-* users created by SynoCommunity packages.\n"
  printf "by Tianyu (Sky) Lu (tianyu@lu.fm)\n"
  printf "2025-12-26\n"
  printf "Released under Apache-2.0\n"
  echo ""
  printf "${ansi_white}Usage:${ansi_std}\n"
  printf "  ${ansi_green}%s list${ansi_std}                           List all sc-* users\n" "$0"
  printf "  ${ansi_green}%s scan${ansi_std} ${ansi_blue}<sc-username> <path>${ansi_std}      Scan files owned by user under specified path. Results are saved to ./<username>_owned.txt\n" "$0"
  printf "  ${ansi_green}%s del${ansi_std} ${ansi_blue}<sc-username>${ansi_std} [--apply]    Delete user (default: dry-run)\n" "$0"
  printf "  ${ansi_green}%s -h | --help | help${ansi_std}             Show this help message\n" "$0"
  echo ""
  printf "${ansi_white}Examples:${ansi_std}\n"
  printf "  ${ansi_white}%s list${ansi_std}                           # List all sc-* users\n" "$0"
  printf "  ${ansi_white}%s scan sc-syncthing /${ansi_std}            # Scan / for files owned by sc-syncthing\n" "$0"
  printf "  ${ansi_white}%s del sc-syncthing${ansi_std}               # Dry-run: show what would be deleted\n" "$0"
  printf "  ${ansi_white}%s del sc-syncthing --apply${ansi_std}       # Actually delete the user\n" "$0"
}

# ======== Main ========
cmd="${1:-}"

case "$cmd" in
  help|-h|--help)
    usage
    exit 0
    ;;
  list)
    list_sc_users
    ;;
  scan)
    [ "${2:-}" ] || { usage; exit 1; }
    [ "${3:-}" ] || { print_error "Path is required for scan command."; usage; exit 1; }
    scan_uid_files "$2" "$3"
    ;;
  del)
    [ "${2:-}" ] || { usage; exit 1; }
    if [ -z "${3:-}" ]; then
      del_user_group "$2" 0
    elif [ "$3" = "--apply" ]; then
      del_user_group "$2" 1
    else
      print_error "Unknown option: $3"
      usage
      exit 1
    fi
    ;;
  *)
    usage
    exit 1
    ;;
esac
