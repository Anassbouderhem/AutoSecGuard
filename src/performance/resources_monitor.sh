#!/bin/bash
# Monitoring des ressources système - Version avec affichage stable

# Configuration des logs
LOG_DIR="/var/log/"
mkdir -p "$LOG_DIR" || { 
    echo "Erreur : Impossible de créer $LOG_DIR (permission refusée)" >&2
    exit 1
}
LOG_FILE="$LOG_DIR/history.log"

# Chargement des fonctions de logging
source "../src/interface/logging.sh" || {
    echo "Erreur: Impossible de charger logging.sh" >&2
    exit 1
}

# Variables globales
MONITOR_ACTIF=true

# Fonction pour générer l'affichage
generer_affichage() {
    local filtre="$1"
    local contenu
    
    # Génération du contenu
    contenu=$(
        echo "=== Ressources Système ==="
        date
        echo "========================="
        printf "%-10s %-8s %-8s %-50s\n" "PID" "%CPU" "%RAM" "COMMAND"
        
        case "$filtre" in
            "high")
                ps -eo pid,%cpu,%mem,cmd --sort=-%cpu | awk 'NR<=6 || ($2+0 > 80 || $3+0 > 50)' | head -n 20
                ;;
            "critical")
                ps -eo pid,%cpu,%mem,cmd --sort=-%cpu | awk 'NR<=6 || ($2+0 > 90 || $3+0 > 70)' | head -n 20
                ;;
            *)
                ps -eo pid,%cpu,%mem,cmd --sort=-%cpu | head -n 20
                ;;
        esac
        
        echo "========================="
        echo "Appuyez sur Ctrl+C pour quitter"
    )
    
    # Affichage en une seule opération
    clear
    echo "$contenu"
}

# Fonction principale de monitoring
monitor() {
    local filtre="$1"
    local delai="$2"
    
    log "INFO" "Démarrage du monitoring (Filtre: ${filtre:-none}, Rafraîchissement: ${delai}s)"
    
    while $MONITOR_ACTIF; do
        generer_affichage "$filtre"
        
        # Sleep avec vérification périodique
        for ((i=0; i<delai && MONITOR_ACTIF; i++)); do
            sleep 1
        done
    done
}

# Fonction de nettoyage
nettoyage() {
    MONITOR_ACTIF=false
    log "INFO" "Monitoring terminé"
    exit 0
}

# Gestion des arguments
filtre=""
delai=5

while getopts "g:r:h" opt; do
    case $opt in
        g) filtre="$OPTARG" ;;
        r) delai="$OPTARG" ;;
        h) 
            echo -e "Syntaxe: $0 [-g <high|critical>] [-r <secondes>]\n"
            echo "Options:"
            echo "  -g <filtre>        Niveau de filtrage : 'high' ou 'critical'"
            echo "  -r <secondes>      Fréquence de rafraîchissement (défaut: 5s)"
            echo "  -h                 Affiche cette aide"
            exit 0
            ;;
        *) error 100 "Option invalide: -$OPTARG" ;;
    esac
done

# Validation des entrées
[[ "$delai" =~ ^[0-9]+$ ]] || error 101 "Le délai de rafraîchissement doit être un nombre positif"
case "$filtre" in
    ""|"high"|"critical") ;;
    *) error 102 "Filtre invalide. Options: high, critical" ;;
esac

# Configuration des traps
trap nettoyage SIGINT SIGTERM

# Lancement du monitoring
monitor "$filtre" "$delai"