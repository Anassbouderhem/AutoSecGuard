#!/bin/bash

# Charger les fonctions de journalisation
source ../src/interface/logging.sh

verbose=false  # Mode verbeux désactivé par défaut

# Analyse des options
while getopts "l:harv" opt; do
    case $opt in
        l)
            set_log_dir "$OPTARG"
            ;;
        h)
            show_help
            exit 0
            ;;
        v)
            visualize_logs
            ;;
        a)
            bash "$(dirname "$0")/../src/security/scan_active.sh"
            ;;
        r)
            sudo bash "$(dirname "$0")/../src/security/restore.sh"
            ;;
        *)
            echo "Option invalide"
            show_help
            exit 1
            ;;
    esac
done