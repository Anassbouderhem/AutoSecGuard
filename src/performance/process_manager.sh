#!/bin/bash

# Vérification des privilèges root
check_root() {
    [[ $EUID -ne 0 ]] && { log "ERROR" "Privilèges root requis"; return 1; }
}

# Configuration des chemins
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Un seul dossier var à la racine pour centraliser les données variables
VAR_DIR="$BASE_DIR/var"
mkdir -p "$VAR_DIR" || { echo "Erreur création $VAR_DIR" >&2; exit 1; }



# Dossier des snapshots processus
SNAPSHOT_DIR="$VAR_DIR/backups/process_snapshots"
mkdir -p "$SNAPSHOT_DIR" || exit 1

# Fichier de contrôle pour l'arrêt
STOP_FILE="$VAR_DIR/stop_signal"

# Chargement du système de logging
source "$BASE_DIR/src/interface/logging.sh" || {
    echo "Erreur: Impossible de charger logging.sh" >&2
    exit 1
}

# Fonction de capture d'état processus
snapshot() {
    local pid=$1
    local temps=$(date +'%Y%m%d_%H%M%S')
    if ps -p "$pid" > /dev/null 2>&1; then
        ps -p "$pid" -o pid,ppid,user,%cpu,%mem,vsz,rss,cmd > "$SNAPSHOT_DIR/proc_${pid}_${temps}.snapshot"
        chmod 400 "$SNAPSHOT_DIR/proc_${pid}_${temps}.snapshot" # Sécurisation du fichier
        log "INFO" "Snapshot PID $pid sauvegardé dans $SNAPSHOT_DIR"
    else
        log "WARNING" "Processus PID $pid introuvable, snapshot non effectué"
    fi
}

# Gestion des actions sur processus
manage_process() {
    local pid=$1
    local action=$2
    local cmd_short=$(ps -p "$pid" -o cmd= 2>/dev/null | cut -c1-50)

    case "$action" in
        "kill")
            check_root || return
            if kill -9 "$pid" 2>/dev/null; then
                log "ALERT" "Processus terminé - PID: $pid | CMD: $cmd_short"
            else
                log "ERROR" "Échec kill - PID: $pid | Raison: permission ou PID invalide"
            fi
            ;;
        "renice")
            check_root || return
            if renice +15 "$pid" > /dev/null 2>&1; then
                log "NOTICE" "Priorité réduite - PID: $pid | CMD: $cmd_short"
            else
                log "ERROR" "Échec renice - PID: $pid | Raison: permission refusée"
            fi
            ;;
        *)
            log "DEBUG" "Aucune action demandée pour PID $pid"
            ;;
    esac
}

# Détection des processus consommateurs
detect_process_gourmands() {
    local cpu_seuil=$1
    local ram_seuil=$2
    local action=${3:-""}
    
    log "INFO" "Scan processus (CPU > $cpu_seuil% OU RAM > $ram_seuil%) | Action: ${action:-none}"
    
    ps -eo pid,%cpu,%mem,cmd --sort=-%cpu | awk -v cpu="$cpu_seuil" -v ram="$ram_seuil" '
    NR>1 && ($2 > cpu || $3 > ram) {
        print $1,$2,$3,$4
    }' | while read -r pid cpu ram cmd; do

        # Filtre des processus système et VSCode
        if [[ "$cmd" != *"vscode-server"* && "$pid" -gt 1000 ]]; then
            snapshot "$pid"

            # Niveaux d'alerte différenciés
            if (( $(echo "$cpu > 90" | bc -l) )); then
                log "CRITICAL" "Processus critique - PID: $pid | CPU: ${cpu}% | CMD: ${cmd:0:50}"
                [[ -n "$action" ]] && manage_process "$pid" "$action"
            elif (( $(echo "$cpu > 70" | bc -l) )); then
                log "WARNING" "Processus gourmand - PID: $pid | CPU: ${cpu}%"
                [[ -n "$action" ]] && manage_process "$pid" "$action"
            fi
        fi
    done
}

# Mode surveillance automatique avec arrêt contrôlé
mode_auto() {
    local cpu_seuil=${1:-80}
    local ram_seuil=${2:-50}
    local action=${3:-""}
    local stop_file="$VAR_DIR/stop_signal"
    
    # Fichier pour stocker le PID du processus enfant
    local pid_file="$VAR_DIR/performance_monitor.pid"
    
    rm -f "$stop_file" "$pid_file"
    
    log "INFO" "Démarrage mode auto (CPU: $cpu_seuil% RAM: $ram_seuil% Action: $action)"
    
    # Fonction pour arrêter les processus enfants
    stop_monitoring() {
        if [[ -f "$pid_file" ]]; then
            local child_pid=$(cat "$pid_file")
            kill "$child_pid" 2>/dev/null && log "INFO" "Processus $child_pid arrêté"
            rm -f "$pid_file"
        fi
        rm -f "$stop_file"
        exit 0
    }
    
    trap 'stop_monitoring' SIGINT SIGTERM
    
    # Lancer le monitoring dans un sous-shell et stocker son PID
    (
        while ! [[ -f "$stop_file" ]]; do
            detect_process_gourmands "$cpu_seuil" "$ram_seuil" "$action"
            sleep 30
        done
        exit 0
    ) &
    
    echo $! > "$pid_file"
    log "INFO" "Processus de surveillance démarré. PID: $!"
    log "INFO" "Pour arrêter: 'touch $stop_file' OU 'kill $!' OU option 'k' dans le menu"
    
    wait  # Attendre la fin du processus enfant
    stop_monitoring
}


# Point d'entrée principal
main() {
    case "${1:-}" in
        "--auto")
            mode_auto "${2:-80}" "${3:-50}" "${4:-}"
            ;;
        "--seuil")
            IFS=':' read -r cpu ram <<< "${2:-70:40}"
            detect_process_gourmands "$cpu" "$ram" "${3:-}"
            ;;
        *)
            detect_process_gourmands 70 40
            ;;
    esac
}

main "$@"