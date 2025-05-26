#!/bin/bash
# AutoSecGuard - Main Control Script v3.8


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
    PS3="Choisissez un mode d'exécution : "
    select exec_mode in "Fork" "Thread" "Subshell" "Quitter"; do
        case $REPLY in
            1) mode="mode_fork"; break ;;
            2) mode="mode_thread"; break ;;
            3) mode="mode_subshell"; break ;;
            4) exit 0 ;;
            *) echo "Option invalide" ;;
        esac
    done

    PS3="Choisissez une fonctionnalité : "
    select feature in "Sécurité" "Performance" "Restauration" "Quitter"; do
        case $REPLY in
            1) run_security "$mode"; break ;;
            2) 
                read -p "Seuil CPU (%): " cpu
                read -p "Seuil RAM (%): " ram
                read -p "Mode auto? (y/n): " auto
                read -p "Action (kill/renice/none): " action
                read -p "Granularité (low/high/critical): " granularity
                read -p "Intervalle de rafraîchissement (s): " refresh
                
                if [[ "$auto" =~ ^[yY] ]]; then
                    run_performance "$mode" \
                        --cpu-seuil "${cpu:-80}" \
                        --ram-seuil "${ram:-50}" \
                        --auto \
                        --action "${action:-none}" \
                        --granularity "${granularity:-high}" \
                        --refresh "${refresh:-5}"
                else
                    run_performance "$mode" \
                        --cpu-seuil "${cpu:-80}" \
                        --ram-seuil "${ram:-50}" \
                        --action "${action:-none}" \
                        --granularity "${granularity:-high}" \
                        --refresh "${refresh:-5}"
                fi
                break ;;
            3) run_restore; break ;;
            4) exit 0 ;;
            *) echo "Option invalide" ;;
        esac
    done
}

### Entrée principale ###
main() {
    log "SYSTEM" "Démarrage de AutoSecGuard "
    parse_arguments "$@"
}

main "$@"