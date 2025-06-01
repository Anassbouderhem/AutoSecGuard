#!/bin/bash

### Configuration ###
PROJECT_ROOT="$(dirname "$(realpath "$0")")/.."
LOG_DIR="/var/log/autosecguard"
PID_FILE="/var/run/autosecguard.pid"
mkdir -p "$LOG_DIR" || { echo "Erreur : Impossible de créer $LOG_DIR" >&2; exit 1; }
LOG_FILE="$LOG_DIR/autosecguard_$(date +%Y%m%d).log"
STOP_FILE="$PROJECT_ROOT/var/stop_signal"

### Initialisation ###
init() {
    mkdir -p "$PROJECT_ROOT/var" || {
        log "ERROR" "Impossible de créer $PROJECT_ROOT/var"
        exit 1
    }
    rm -f "$STOP_FILE"
}

### Gestion des signaux ###
setup_signal_handlers() {
    trap 'handle_exit_signal SIGINT' SIGINT
    trap 'handle_exit_signal SIGTERM' SIGTERM
    trap 'handle_exit_signal SIGHUP' SIGHUP
}

handle_exit_signal() {
    local signal=$1
    log "INFO" "Signal $signal reçu, arrêt en cours..."
    cleanup
    exit 0
}

### Nettoyage ###
cleanup() {
    rm -f "$STOP_FILE" "$PID_FILE"
    pkill -P $$ 2>/dev/null
    log "INFO" "Nettoyage terminé, arrêt du système"
}

### Vérification root ###
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Cette fonctionnalité nécessite les privilèges root"
        return 1
    fi
}

### Chargement des dépendances ###
load_dependencies() {
    source "$PROJECT_ROOT/src/interface/logging.sh" || {
        echo "Échec du chargement de logging.sh" >&2
        exit 1
    }
    source "$PROJECT_ROOT/src/modes/modes_exe.sh" || {
        log "ERROR" "Échec du chargement de modes_exe.sh"
        exit 1
    }
    source "$PROJECT_ROOT/src/interface/interactive.sh" || {
        log "ERROR" "Échec du chargement de interactive.sh"
        exit 1
    }
}

### Aide ###
show_help() {
    cat << EOF
AutoSecGuard - Système intégré de sécurité et performance v4.0

Usage: $0 [MODE] [FONCTIONNALITÉ] [OPTIONS]

Modes d'exécution:
  -f, --fork       Exécution parallèle (fork)
  -t, --thread     Exécution threadée (défaut)
  -s, --subshell   Exécution en subshells

Fonctionnalités principales:
  -sec, --security       Scan actif + surveillance (nécessite root)
  -p, --performance      Monitoring CPU/RAM/Processus
  -R, --restore          Restauration système (nécessite root)
  --stop                 Arrêt propre du système

Options performance:
  --cpu-seuil XX         Définir le seuil CPU (défaut: 80)
  --ram-seuil XX         Définir le seuil RAM (défaut: 50)
  --auto                 Mode surveillance continue
  --granularity          Niveau de détail (low|high|critical)
  --refresh              Intervalle de rafraîchissement (secondes)
  --action               Actions sur processus (kill|renice)

  -l, --logdir <répertoire>  Changer le répertoire de journalisation (ex: -l ~/meslogs)


Méthodes d'arrêt:
  1. $0 --stop
  2. touch $STOP_FILE
  3. kill -TERM [PID]

Exemples:
  sudo $0 -f --security
  $0 --performance --cpu-seuil 90 --auto --action kill
  sudo $0 --stop
EOF
}

### Vérifier le signal d'arrêt ###
check_stop_signal() {
    [[ -f "$STOP_FILE" ]]
}

### Gestion du PID ###
manage_pid() {
    case "$1" in
        create)
            echo $$ > "$PID_FILE"
            ;;
        remove)
            rm -f "$PID_FILE"
            ;;
        check)
            if [[ -f "$PID_FILE" ]]; then
                local old_pid
                old_pid=$(cat "$PID_FILE")
                if ps -p "$old_pid" > /dev/null; then
                    log "WARNING" "Un processus est déjà en cours (PID: $old_pid)"
                    return 1
                else
                    rm -f "$PID_FILE"
                fi
            fi
            ;;
    esac
}

### Fonction d'arrêt ###
stop_system() {
    if [[ -f "$PID_FILE" ]]; then
        local main_pid
        main_pid=$(cat "$PID_FILE")
        if kill -0 "$main_pid" 2>/dev/null; then
            kill -TERM "$main_pid"
            local waited=0
            while kill -0 "$main_pid" 2>/dev/null ; do
                sleep 1
                ((waited++))
            done
            if kill -0 "$main_pid" 2>/dev/null; then
                kill -KILL "$main_pid"
                log "WARNING" "Arrêt forcé du processus $main_pid"
            fi
            rm -f "$PID_FILE"
                log "INFO" "Système arrêté"
            echo "Système arrêté"
        else
            rm -f "$PID_FILE"
            echo "Aucun processus actif trouvé"
        fi
    else
        touch "$STOP_FILE"
        echo "Signal d'arrêt envoyé, veuillez patienter..."
    fi
}

### Modules ###
run_security() {
    check_root || return 1
    log "SECURITY" "Lancement du module de sécurité"
    SECURITY_LOG="$LOG_DIR/security_access.log"
    touch "$SECURITY_LOG" && chmod 600 "$SECURITY_LOG"
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
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cpu-seuil) cpu_seuil=$2; shift 2 ;;
            --ram-seuil) ram_seuil=$2; shift 2 ;;
            --auto) auto_mode=true; shift ;;
            --granularity) granularity=$2; shift 2 ;;
            --refresh) refresh=$2; shift 2 ;;
            --action) action=$2; shift 2 ;;
            *) shift ;;
        esac
    done
    log "PERFORMANCE" "Configuration - CPU:${cpu_seuil}% RAM:${ram_seuil}% Action:${action:-none}"
    PERF_LOG="$LOG_DIR/performance_$(date +%Y%m%d).log"
    if $auto_mode; then
        check_root || return 1
        log "PERFORMANCE" "Lancement en mode surveillance continue"
        rm -f "$STOP_FILE"
        manage_pid create
        (
            while ! check_stop_signal; do
                "$PROJECT_ROOT/src/performance/process_manager.sh" --seuil "${cpu_seuil}:${ram_seuil}" "$action"
                sleep "$refresh"
            done
        ) >> "$PERF_LOG" 2>&1 &
        (
            while ! check_stop_signal; do
                "$PROJECT_ROOT/src/performance/resources_monitor.sh" -g "$granularity"
                sleep "$refresh"
            done
        ) >> "$PERF_LOG" 2>&1 &
        log "INFO" "Surveillance en cours. PID: $$"
        log "INFO" "Pour arrêter: '$0 --stop' ou 'touch $STOP_FILE'"
    else
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
    manage_pid check || exit 1

    # Prétraitement des options globales
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--fork) mode="mode_fork"; shift ;;
            -t|--thread) mode="mode_thread"; shift ;;
            -s|--subshell) mode="mode_subshell"; shift ;;
            -l|--logdir)
                if [[ -n "$2" ]]; then
                    set_log_dir "$2"
                    shift 2
                else
                    log "ERROR" "Le répertoire de log doit être spécifié après -l/--logdir"
                    show_help
                    exit 101
                fi
                ;;
            --stop)
                stop_system
                exit $?
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -sec|--security|-p|--performance|-R|--restore)
                break # On passe à la gestion des fonctionnalités
                ;;
            *)
                break
                ;;
        esac
    done

    # Gestion des fonctionnalités
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -sec|--security)
                run_security "$mode"
                feature_set=true
                ;;
            -p|--performance)
                shift
                run_performance "$mode" "$@"
                feature_set=true
                return 0
                ;;
            -R|--restore)
                run_restore
                feature_set=true
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log "ERROR" "Option invalide: $1"
                show_help
                exit 100
                ;;
        esac
        shift
    done

    if ! $feature_set; then
        # lancer le mode interactif
        if [[ $# -eq 0 ]]; then
            interactive_mode
            exit 0
        fi
        log "ERROR" "Aucune fonctionnalité sélectionnée"
        show_help
        exit 1
    fi
}

### Lancement principal ###
init
load_dependencies
setup_signal_handlers
parse_arguments "$@"
