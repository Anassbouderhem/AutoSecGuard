#!/bin/bash

# Répertoire de journalisation par défaut du projet
if [[ -n "$LOG_FILE" ]]; then
    log_file="$LOG_FILE"
else
    log_dir="../var/log"
    mkdir -p "$log_dir"
    log_file="$log_dir/history.log"
fi

# --- [2] Permet de redéfinir le répertoire de logs via -l ---
set_log_dir() {
    local raw_path="$1"
    local expanded_path=$(eval echo "$raw_path")
    log_dir="$expanded_path"
    mkdir -p "$log_dir"
    log_file="$log_dir/history.log"
    export LOG_FILE="$log_file"
}

# --- [3] Fonction d'enregistrement des messages de log ---
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
    echo "$temps : $hostname : -autosecguard- : $username : ERROR : $message" | tee -a "$log_file"    
    case "$code" in
      126) echo "Erreur critique : Permission refusée pour une commande."; ;;
      127) echo "Erreur critique : Commande non trouvée."; ;;
    esac

    exit "$code"
}

