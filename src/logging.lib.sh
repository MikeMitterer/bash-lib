#!/usr/bin/env bash
readonly __LOGGING_LIB__="logging.lib.sh";

# Bash-Logging Tools
#
# Einbinden:
#     if [[ "${__LOGGING_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/logging.lib.sh"; fi
#
# Weitere Infos:
#   https://gist.github.com/goodmami/6556701
#
# Json-Logging in Bash-Scripts
#   https://sevic.dev/notes/bash-script-json-logging/
#
# Infos auf SO:
#   https://serverfault.com/questions/103501/how-can-i-fully-log-all-bash-scripts-actions
#   https://unix.stackexchange.com/a/324005
#

# Default - logging stream (file descriptor 3) defaults to STDERR
#
# Übliche Verwendung in den Scripts: (bat und moreutils muss installiert sein)
#   exec 2> >(tee -a "${LOGFILE}" | bat --style plain -l syslog) 3>&2; trap 'exec 2>&3' EXIT HUP INT QUIT RETURN
#
# Weitere Infos zur Umleitung von File descriptoren:
#   https://stackoverflow.com/a/19279694/504184
#   https://www.thomas-krenn.com/de/wiki/Bash_stdout_und_stderr_umleiten
#
# BAT (colorizer):
#   https://stackoverflow.com/a/30074374/504184
#
# exec 3>&2; trap 'exec 2>&3' EXIT HUP INT QUIT RETURN
# exec 3>&1; trap 'exec 1>&3' EXIT HUP INT QUIT RETURN

# Defaults: fd 3 → stdout, fd 4 → /dev/null
# fd 3 ist der Haupt-Log-Stream (alle Nachrichten).
# fd 4 ist der Info-Stream — per Default /dev/null, da Info bereits über fd 3 läuft.
# Kann vom Aufrufer vor dem Einbinden überschrieben werden (z.B. für bat/tee-Pipelines).
{ true >&3; } 2>/dev/null || exec 3>&1
{ true >&4; } 2>/dev/null || exec 4>/dev/null

readonly LOG_LEVEL_SILENT=0
readonly LOG_LEVEL_CRITICAL=1
readonly LOG_LEVEL_ERROR=2
readonly LOG_LEVEL_WARNING=3
readonly LOG_LEVEL_INFO=4
readonly LOG_LEVEL_DEBUG=5

# Default LOG_LEVEL, shows infos
LOG_VERBOSITY=$((LOG_LEVEL_INFO))

notify() {
    local MESSAGE=$1
    log ${LOG_LEVEL_SILENT} "[NOTE]: ${MESSAGE}"
} # Always prints

critical() {
    local MESSAGE=$1
    log ${LOG_LEVEL_CRITICAL} "[CRITICAL]: ${MESSAGE}"
}

error() {
    local MESSAGE=$1
    log ${LOG_LEVEL_ERROR} "[ERROR]: ${MESSAGE}"
}
warn() {
    local MESSAGE=$1
    log ${LOG_LEVEL_WARNING} "[WARNING]: ${MESSAGE}"
}

inf() {
    local MESSAGE=$1
    log ${LOG_LEVEL_INFO} "[INFO]: ${MESSAGE}"
} # "info" is already a command

debug() {
    local MESSAGE=$1
    log ${LOG_LEVEL_DEBUG} "[DEBUG]: ${MESSAGE}"
}

log() {
    local readonly LEVEL="$1"
    local readonly MESSAGE="$2"

    if [ ${LOG_VERBOSITY} -ge "$LEVEL" ]; then
        # Expand escaped characters, wrap at 80 chars, indent wrapped lines

        # sed-command funktioniert nicht am Mac
        # echo -e "$(date +${ISO_8601_FORMAT}) ${MESSAGE}" | fold -w80 -s | sed '2~1s/^/  /' >&3
        # echo -e "$(date +${ISO_8601_FORMAT}) ${MESSAGE}" | fold -w80 -s >&3

        # ts ist im package 'moreutils' (brew + apt)
        # echo -e "${MESSAGE}" | \ts -m "${ISO_8601_FORMAT}" >&3
        echo -e "${MESSAGE}" >&3
    fi
    if [[ "$LEVEL" -ge ${LOG_LEVEL_CRITICAL} && "$LEVEL" -le ${LOG_LEVEL_WARNING} ]]; then
        echo -e "${MESSAGE}" >&2
    elif [[ "${LEVEL}" == ${LOG_LEVEL_INFO} ]]; then
        echo -e "${MESSAGE}" >&4
    fi
}
