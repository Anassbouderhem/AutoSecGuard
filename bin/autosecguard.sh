#!/bin/bash

# Load logging functions
source ../src/interface/logging.sh

# Parse options
while getopts "l:h" opt; do
    case $opt in
        l)
            set_log_dir "$OPTARG"
            ;;
        h)
            show_help
            exit 0
            ;;
        a)
            bash "$(dirname "$0")/../src/security/scan_active.sh"
            ;;
        r)
            sudo bash "$(dirname "$0")/../src/security/restore.sh"
            ;;
        *)
            echo "Invalid option"
            show_help
            exit 1
            ;;
    esac
done

log_message "TEST" "hello world"
