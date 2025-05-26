#!/bin/bash
# Répertoire et fichier de logs
LOG_DIR="/var/log/autosecguard"
mkdir -p "$LOG_DIR" || { echo "Erreur : Impossible de créer $LOG_DIR (permission refusée)"; exit 1; }
LOG_FILE="$LOG_DIR/history.log"

source /src/interface/logging.sh

# Fonction de monitoring
monitor(){
    local filtre="$1"
    local delai="$2"
    log "INFO" "Démarrage du monitoring (Filtre: ${filtre:-none}, Rafraîchissement: ${delai}s)"
    while true; do
        clear
        echo "=== Ressources Système ==="
        date
        echo "========================="
        printf "%-10s %-8s %-8s %-50s\n" "PID" "%CPU" "%RAM" "COMMAND"

        case "$filtre" in
        "high")
            # Affiche les processus avec CPU > 80% ou MEM > 50%, ou les 6 premiers par défaut
            ps -eo pid,%cpu,%mem,cmd --sort=-%cpu | awk 'NR<=6 || ($2+0 > 80 || $3+0 > 50)' | head -n 20
            ;;
        "critical")
            # Affiche les processus avec CPU > 90% ou MEM > 70%, ou les 6 premiers par défaut
            ps -eo pid,%cpu,%mem,cmd --sort=-%cpu | awk 'NR<=6 || ($2+0 > 90 || $3+0 > 70)' | head -n 20
            ;;
        *)
            # Affiche les 20 processus les plus consommateurs en CPU 
            ps -eo pid,%cpu,%mem,cmd --sort=-%cpu | head -n 20
            ;;
        esac
        echo "========================="
        echo "Appuyer sut Ctrl+C pour quitter"
        sleep "$delai"
        done
}
filtre=""
delai=5

while getopts "g:r:h" opt; do
  case $opt in
    g) filtre="$OPTARG" ;;
    r) delai="$OPTARG" ;;
    h) 
      echo -e "Syntaxe: $0 [-g <high|critical>] [-r <secondes>]\n"
      echo "  -g <filtre>        Filtrage : 'high' ou 'critical'"
      echo "  -r <secondes>      Fréquence de mise à jour (défaut: 2s)"
      echo "  -h                 Affiche cette aide"
      exit 0
      ;;
    *) error 100 "Option invalide: -$OPTARG" ;;
  esac
done

[[ "$delai" =~ ^[0-9]+$ ]] || error 101 "Le delai de rafraîchissement doit être un nombre"
case "$filtre" in
  ""|"high"|"critical") ;;
  *) error 102 "Filtre invalide. Options: high, critical" ;;
esac

trap 'log "INFO" "Monitoring terminé"; exit 0' SIGINT
monitor "$filtre" "$delai"
