#!/bin/bash

# Default project log dir
log_dir="../var/log"
mkdir -p "$log_dir"  # ✅ Ensure directory exists
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
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d-%H-%M-%S')
    local user="$USER"
    echo "$timestamp : $user : $level : $message" >> "$log_file"
}

# --- [4] Help display ---
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
