#!/bin/bash

# Répertoire de journalisation par défaut du projet
log_dir="../var/log"
mkdir -p "$log_dir"  # S'assurer que le répertoire existe
log_file="$log_dir/autosecguard.log"

# --- [2] Permet de redéfinir le répertoire de logs via -l ---
set_log_dir() {
    local raw_path="$1"
    local expanded_path=$(eval echo "$raw_path")  # expansion de ~
    log_dir="$expanded_path"
    mkdir -p "$log_dir"
    log_file="$log_dir/autosecguard.log"
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

# --- [4] Fonction de visualisation des journaux ---
visualize_logs() {
    echo "Visualisation structurée des journaux"

    read -p "Entrez la date à filtrer (aaaa-mm-jj ou laissez vide pour tout afficher) : " filtre_date
    read -p "Entrez le niveau de log à filtrer (ex : ERROR, INFOS ou laissez vide) : " filtre_niveau

    echo -e "\n--- Journaux filtrés ---"
    awk -F" : " -v date="$filtre_date" -v niveau="$filtre_niveau" '
    {
        split($1, ts, "-")
        log_date = ts[1] "-" ts[2] "-" ts[3]
        if ((date == "" || index($1, date) == 1) &&
            (niveau == "" || $3 == niveau)) {
            print $0
        }
    }' "$log_file"
}

# --- Affichage de l'aide ---
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