#!/bin/bash
# Vérification des privilèges root
if [[ $EUID -ne 0 ]]; then
  echo "Erreur : Ce script doit être exécuté avec les privilèges root." >&2
  exit 1
fi

# Répertoire et fichier de logs
LOG_DIR="/var/log/autosecguard"
mkdir -p "$LOG_DIR" || error 126 "Impossible de créer $LOG_DIR (permission refusée)"
LOG_FILE="$LOG_DIR/history.log"
SNAPSHOT_DIR="/var/backups/process_snapshots"
mkdir -p "$SNAPSHOT_DIR" || { echo "Erreur : Impossible de créer $SNAPSHOT_DIR (permission refusée)"; exit 1; }; 

source /src/interface/logging.sh


error() {
    local code="$1"
    shift
    local temps
    temps="$(date '+%Y-%m-%d-%H-%M-%S')"
    local username
    username="$(whoami)"
    local message="$*"
    local hostname
    hostname="$(hostname -s)"
    echo "$temps : $hostname : -autosecguard- : $username : ERROR : $message" | tee -a "$LOG_FILE"
    
    case "$code" in
      126) echo "Erreur critique : Permission refusée pour une commande."; ;;
      127) echo "Erreur critique : Commande non trouvée."; ;;
    esac

    exit "$code"
}



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

detect_process_gourmands(){
    local cpu_seuil=$1
    local ram_seuil=$2
    log "INFO" "Scan en cours (Seuils: CPU>$cpu_seuil% RAM>$ram_seuil%)"
    ps -eo pid,%cpu,%mem,cmd --sort=-%cpu | awk -v cpu="$cpu_seuil" -v ram="$ram_seuil" '
    NR>1 && ($2 > cpu || $3 > ram) {
      print $1,$2,$3,$4
    }'| while read -r pid cpu ram cmd; do

    # Exclusion des processus système et VS Code
    if [[ "$cmd" != *"vscode-server"* && "$pid" -gt 1000 ]]; then
    snapshot "$pid"

    # manager les processus
    if (( $(echo "$cpu > 90" | bc -l) )); then
        log "WARNING" "Processus critique: PID $pid (CPU: $cpu% CMD: ${cmd:0:50}...)"
        manage_process "$pid" "kill"
    elif (( $(echo "$cpu > 70" | bc -l) )); then
        log "NOTICE" "Processus gourmand: PID $pid (CPU: $cpu%)"
        manage_process "$pid" "renice"
    fi
    fi
done
}

#manager les processus
manage_process(){
    local pid=$1
    local action=$2

    case "$action" in 
    "kill")
     if kill -9 "$pid" 2>/dev/null; then
        log "ALERT" "Processus $pid terminé"
      else
        log "ERROR" "Échec kill $pid (permission ou PID invalide)"
      fi
      ;;
    "renice")
      if renice +15 "$pid" > /dev/null 2>&1; then
        log "NOTICE" "Priorité $pid réduite"
      else
        log "ERROR" "Échec renice $pid (permission refusée)"
      fi
      ;;
  esac
}

mode_auto() {
    local cpu_seuil=${1:-80}
    local ram_seuil=${2:-50}
    echo "i am "
    log "INFO" "Démarrage mode auto (CPU: $cpu_seuil% RAM: $ram_seuil%)"
    while true; do
        detect_process_gourmands "$cpu_seuil" "$ram_seuil"
        sleep 30  # Scan toutes les 30 secondes
  done
}

#Démarrage
case "$1" in
  "--auto")
    mode_auto "${2:-80}" "${3:-50}"
    ;;
  "--help")
    echo "Usage: $(basename "$0") [--auto [CPU% RAM%]] [--seuil CPU%:RAM%]"
    echo "Exemples:"
    echo "  $0 --auto 80 50  # Surveillance continue (seuils personnalisés)"
    echo "  $0 --seuil 90:70  # Scan ponctuel avec seuils stricts"
    ;;
  "--seuil")
    IFS=':' read -r cpu ram <<< "$2"
    detect_process_gourmands "$cpu" "$ram"
    ;;
  *)
    detect_process_gourmands 70 40  
    ;;
esac
