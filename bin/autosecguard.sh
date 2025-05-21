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
        *)
            echo "Invalid option"
            show_help
            exit 1
            ;;
    esac
done

log_message "TEST" "hello world"
