#!/bin/bash
# AutoSecGuard - Main Control Script v3.8

clear


# ... le reste de ton script ...


### Configuration ###
PROJECT_ROOT="$(dirname "$(realpath "$0")")/.."
LOG_DIR="/var/log/autosecguard"
mkdir -p "$LOG_DIR" || { echo "Erreur : Impossible de créer $LOG_DIR" >&2; exit 1; }
LOG_FILE="$LOG_DIR/autosecguard_$(date +%Y%m%d).log"

### Vérification root pour certaines fonctionnalités ###
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Cette fonctionnalité nécessite les privilèges root"
        return 1
    fi
}

### Chargement des dépendances ###
source "$PROJECT_ROOT/src/interface/logging.sh" || exit 1
source "$PROJECT_ROOT/src/modes/modes_exe.sh" || exit 1

### Aide ###
show_help() {
    cat << EOF
AutoSecGuard - Système intégré de sécurité et performance

Usage: $0 [MODE] [FONCTIONNALITÉ] [OPTIONS]

Modes d'exécution:
  -f, --fork       Exécution parallèle (fork)
  -t, --thread     Exécution threadée (défaut)
  -s, --subshell   Exécution en subshells

Fonctionnalités principales:
  -sec, --security       Scan actif + surveillance (nécessite root)
  -p, --performance    Monitoring CPU/RAM/Processus
  -R, --restore        Restauration système (nécessite root)

Options performance:
  --cpu-seuil XX   Définir le seuil CPU (défaut: 80)
  --ram-seuil XX   Définir le seuil RAM (défaut: 50)
  --auto           Mode surveillance continue
  --granularity    Niveau de détail (low|high|critical)
  --refresh        Intervalle de rafraîchissement (secondes)
  --action         Actions sur processus (kill|renice)

Exemples:
  sudo $0 -f --security
  $0 --performance --cpu-seuil 90 --auto --action kill
  $0 --performance --granularity high --refresh 10
  sudo $0 --restore
EOF
}

### Fonctions de modules ###
run_security() {
    check_root || return 1
    log "SECURITY" "Lancement du module de sécurité"
    
    # Configurer le fichier de log de sécurité
    SECURITY_LOG="$LOG_DIR/security_access.log"
    touch "$SECURITY_LOG" || {
        log "ERROR" "Impossible de créer $SECURITY_LOG"
        exit 1
    }
    chmod 600 "$SECURITY_LOG"

    local tasks=(
        "$PROJECT_ROOT/src/security/scan_active.sh --full --log $SECURITY_LOG"
        "$PROJECT_ROOT/src/security/surveillance.sh --daemon --log $SECURITY_LOG"
    )
    for t in "${tasks[@]}"; do
        $1 "$t"
    done
}

run_performance() {
    local mode=$1
    shift
    local cpu_seuil=80
    local ram_seuil=50
    local auto_mode=false
    local granularity="high"
    local refresh=5
    local action=""
    local args=()

    # Analyse des options spécifiques
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cpu-seuil) cpu_seuil=$2; shift 2 ;;
            --ram-seuil) ram_seuil=$2; shift 2 ;;
            --auto) auto_mode=true; shift ;;
            --granularity) granularity=$2; shift 2 ;;
            --refresh) refresh=$2; shift 2 ;;
            --action) action=$2; shift 2 ;;
            *) args+=("$1"); shift ;;
        esac
    done

    log "PERFORMANCE" "Configuration - CPU:${cpu_seuil}% RAM:${ram_seuil}% Action:${action:-none}"
    PERF_LOG="$LOG_DIR/performance_$(date +%Y%m%d).log"
    
    if $auto_mode; then
        # Mode automatique (démon)
        check_root || return 1
        log "PERFORMANCE" "Lancement en mode surveillance continue"
        "$PROJECT_ROOT/src/performance/process_manager.sh" --auto "$cpu_seuil" "$ram_seuil" "$action" --log "$PERF_LOG" &
        "$PROJECT_ROOT/src/performance/resources_monitor.sh" -g "$granularity" -r "$refresh" --log "$PERF_LOG" &
    else
        # Mode ponctuel
        log "PERFORMANCE" "Lancement en mode ponctuel"
        "$PROJECT_ROOT/src/performance/process_manager.sh" --seuil "${cpu_seuil}:${ram_seuil}" "$action"
        "$PROJECT_ROOT/src/performance/resources_monitor.sh" -g "$granularity" -r "$refresh"
    fi
}

run_restore() {
    check_root || return 1
    log "RESTORE" "Lancement de la restauration système"
    "$PROJECT_ROOT/src/security/restore.sh" || {
        log "ERROR" "Échec de la restauration"
        return 1
    }
}

### Analyse des arguments ###
parse_arguments() {
    local mode="mode_thread"
    local feature_set=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--fork) mode="mode_fork"; shift ;;
            -t|--thread) mode="mode_thread"; shift ;;
            -s|--subshell) mode="mode_subshell"; shift ;;
            -sec|--security) 
                run_security "$mode"
                feature_set=true
                shift ;;
            -p|--performance) 
                shift
                run_performance "$mode" "$@"
                feature_set=true
                return 0
                ;;
            -R|--restore) 
                run_restore
                feature_set=true
                shift ;;
            -h|--help) 
                show_help
                exit 0 ;;
            *) 
                log "ERROR" "Argument invalide : $1"
                show_help
                exit 1 ;;
        esac
    done

    if ! $feature_set; then
        interactive_mode
    fi
}


### Mode interactif ###
interactive_mode() {
    while true; do
        echo -e "\n===== Menu AutoSecGuard ====="
        echo "h) Afficher l'aide"
        echo "r) Restauration système (root)"
        echo "a) Scan actif (root)"
        echo "c) Vérification d'intégrité (hash)"
        echo "s) Surveillance continue (root)"
        echo "p) Performance (CPU/RAM/Processus)"
        echo "m) Mode interactif avancé"
        echo "q) Quitter"
        echo "============================="
        read -p "Votre choix : " choice

        case "$choice" in
            h|H) 
                echo "Affichage de l'aide..."
                show_help 
                ;;
            r|R) 
                echo "Lancement de la restauration système..."
                run_restore 
                ;;
            a|A) 
                echo "Lancement du scan actif..."
                run_security "mode_thread" 
                ;;
            c|C) 
                echo "Lancement de la vérification d'intégrité..."
                "$PROJECT_ROOT/src/security/hash_check.sh" 
                ;;
            s|S) 
                echo "Lancement de la surveillance continue en arrière-plan..."
                "$PROJECT_ROOT/src/security/surveillance.sh" &
                ;;
                p|P) 
            read -p "Seuil CPU (%): " cpu
            read -p "Seuil RAM (%): " ram
            echo "Lancement du monitoring performance en arrière-plan..."
            run_performance "mode_thread" \
                --cpu-seuil "${cpu:-80}" \
                --ram-seuil "${ram:-50}" &
            echo "Le monitoring tourne en arrière-plan avec PID $!"
            ;;

            m|M) 
                echo "Lancement du mode interactif avancé..."
                "$PROJECT_ROOT/src/modes/modes_exe.sh" 
                ;;
            q|Q) 
                echo "Fermeture de AutoSecGuard"
                exit 0
                ;;
            *) 
                echo "Option invalide"
                ;;
        esac
    done
}


### Entrée principale ###
main() {
    log "SYSTEM" "Démarrage de AutoSecGuard "
    parse_arguments "$@"
}

main "$@"