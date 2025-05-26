#!/bin/bash

# Default project log dir
log_dir="../var/log"
mkdir -p "$log_dir"  #  Ensure directory exists
log_file="$log_dir/autosecguard.log"

# --- [2] Allow overriding the log directory via -l ---
set_log_dir() {
    local raw_path="$1"
    local expanded_path=$(eval echo "$raw_path")  # expand ~
    log_dir="$expanded_path"
    mkdir -p "$log_dir"
    log_file="$log_dir/autosecguard.log"
}

# --- [3] Log message function ---
log() {
 local level=$1; shift
  local temps
  temps="$(date '+%Y-%m-%d-%H-%M-%S')"
  local username
  username="$(whoami)"
  local hostname
  hostname="$(hostname -s)"
  local message="$*"
  echo "$temps : $hostname : -autosecguard- : $level : $username : $message" | tee -a "$log_file"
}

# ---  Help display ---
show_help() {
    echo "Usage: ./autosecguard [options]"
    echo ""
    echo "[ General Options ]"
    echo "  -h                   Show this help message"
    echo "  -l <directory>       Set custom log directory (default: var/log)"
    echo ""
    echo "[ Logging Format ]"
    echo "  yyyy-mm-dd-hh-mm-ss : username : INFOS/ERROR : message"
}
