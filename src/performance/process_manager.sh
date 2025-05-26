#!/bin/bash

check_root() {
    [[ $EUID -ne 0 ]] && { log "ERROR" "Privilèges root requis"; return 1; }
}

# Configuration des chemins
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Un seul dossier var à la racine
VAR_DIR="$BASE_DIR/var"
mkdir -p "$VAR_DIR" || { echo "Erreur création $VAR_DIR" >&2; exit 1; }

# Logs
LOG_DIR="$VAR_DIR/log"
mkdir -p "$LOG_DIR" || exit 1
LOG_FILE="$LOG_DIR/process_manager.log"

# Snapshots
SNAPSHOT_DIR="$VAR_DIR/backups/process_snapshots"
mkdir -p "$SNAPSHOT_DIR" || exit 1

# Chargement de logging.sh 
source "$BASE_DIR/src/interface/logging.sh" || {
    echo "Erreur: Impossible de charger logging.sh" >&2
    exit 1
}


# Fonctions
snapshot() {
    local pid=$1
    local temps=$(date +'%Y%m%d_%H%M%S')
    if ps -p "$pid" > /dev/null 2>&1; then
        ps -p "$pid" -o pid,ppid,user,%cpu,%mem,vsz,rss,cmd > "$SNAPSHOT_DIR/proc_${pid}_${temps}.snapshot"
        log "INFO" "Snapshot PID $pid sauvegardé dans $SNAPSHOT_DIR"
    else
        log "WARNING" "Processus PID $pid introuvable, snapshot non effectué"
    fi
}

manage_process() {
    local pid=$1
    local action=$2

    case "$action" in
        "kill")
            check_root || return
            if kill -9 "$pid" 2>/dev/null; then
                log "ALERT" "Processus $pid terminé"
            else
                log "ERROR" "Échec kill $pid (permission ou PID invalide)"
            fi
            ;;
        "renice")
            check_root || return
            if renice +15 "$pid" > /dev/null 2>&1; then
                log "NOTICE" "Priorité $pid réduite"
            else
                log "ERROR" "Échec renice $pid (permission refusée)"
            fi
            ;;
        *)
            log "DEBUG" "Aucune action demandée pour PID $pid"
            ;;
    esac
}

detect_process_gourmands() {
    local cpu_seuil=$1
    local ram_seuil=$2
    local action=${3:-""}
    
    log "INFO" "Scan en cours (Seuils: CPU>$cpu_seuil% RAM>$ram_seuil% Action:$action)"
    
    ps -eo pid,%cpu,%mem,cmd --sort=-%cpu | awk -v cpu="$cpu_seuil" -v ram="$ram_seuil" '
    NR>1 && ($2 > cpu || $3 > ram) {
        print $1,$2,$3,$4
    }' | while read -r pid cpu ram cmd; do

        # Exclusion des processus système
        if [[ "$cmd" != *"vscode-server"* && "$pid" -gt 1000 ]]; then
            snapshot "$pid"

            if (( $(echo "$cpu > 90" | bc -l) )); then
                log "WARNING" "Processus critique: PID $pid (CPU: $cpu% CMD: ${cmd:0:50}...)"
                [[ -n "$action" ]] && manage_process "$pid" "$action"
            elif (( $(echo "$cpu > 70" | bc -l) )); then
                log "NOTICE" "Processus gourmand: PID $pid (CPU: $cpu%)"
                [[ -n "$action" ]] && manage_process "$pid" "$action"
            fi
        fi
    done
}

mode_auto() {
    local cpu_seuil=${1:-80}
    local ram_seuil=${2:-50}
    local action=${3:-""}
    
    log "INFO" "Démarrage mode auto (CPU: $cpu_seuil% RAM: $ram_seuil% Action: $action)"
    trap 'log "INFO" "Arrêt du mode auto"; exit 0' SIGINT SIGTERM
    
    while true; do
        detect_process_gourmands "$cpu_seuil" "$ram_seuil" "$action"
        sleep 30
    done
}

# Point d'entrée
case "$1" in
    "--auto")
        mode_auto "${2:-80}" "${3:-50}" "${4:-}"
        ;;
    "--seuil")
        IFS=':' read -r cpu ram <<< "$2"
        detect_process_gourmands "$cpu" "$ram" "${3:-}"
        ;;
    "--help")
        echo "Usage: $(basename "$0") [--auto [CPU% RAM% [action]] [--seuil CPU%:RAM% [action]]"
        echo "Exemples:"
        echo "  $0 --auto 80 50 kill       # Surveillance avec kill automatique"
        echo "  $0 --seuil 90:70 renice    # Scan ponctuel avec renice"
        ;;
    *)
        detect_process_gourmands 70 40
        ;;
esac