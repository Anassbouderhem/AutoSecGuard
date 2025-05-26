#!/bin/bash

# Répertoire de journalisation par défaut du projet
log_dir="../var/log"
mkdir -p "$log_dir"  # S'assurer que le répertoire existe
log_file="$log_dir/history.log"

# --- [2] Permet de redéfinir le répertoire de logs via -l ---
set_log_dir() {
    local raw_path="$1"
    local expanded_path=$(eval echo "$raw_path")  # expansion de ~
    log_dir="$expanded_path"
    mkdir -p "$log_dir"
    log_file="$log_dir/history.log"
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
    echo "$temps : $hostname : -autosecguard- : $username : ERROR : $message" | tee -a "$LOG_FILE"
    
    case "$code" in
      126) echo "Erreur critique : Permission refusée pour une commande."; ;;
      127) echo "Erreur critique : Commande non trouvée."; ;;
    esac

    exit "$code"
}

# ---  Help display ---
show_help() {
    echo "Utilisation : ./autosecguard [options]"
    echo ""
    echo "[ Options générales ]"
    echo "  -h                   Affiche ce message d'aide"
    echo "  -l <répertoire>      Définir un répertoire de logs personnalisé (défaut : var/log)"
    echo ""
    echo "[ Format des journaux ]"
    echo "  aaaa-mm-jj-hh-mm-ss : nom_utilisateur : INFOS/ERROR : message"
}