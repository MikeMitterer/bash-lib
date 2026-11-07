#!/usr/bin/env bash
readonly __TOOLS_LIB__="tools.lib.sh";

#------------------------------------------------------------------------------
# Allzweck-Helfer für Skripte: trim, repeat, Logfile-Zeilen, Links, scriptToDoc.
# Die Ausgabe im CLI-Theme steht in cli.lib.sh, die tools.lib.sh einbindet.
#
# Einbinden:
#     if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi
#
#------------------------------------------------------------------------------

# Ausgabe im CLI-Theme (bringt colors.lib.sh mit)
# shellcheck source=SCRIPTDIR/cli.lib.sh
if [[ "${__CLI_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/cli.lib.sh"; fi
# shellcheck source=SCRIPTDIR/apps.lib.sh
if [[ "${__APPS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/apps.lib.sh"; fi
# shellcheck source=SCRIPTDIR/dtime.lib.sh
if [[ "${__DTIME_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/dtime.lib.sh"; fi
# shellcheck source=SCRIPTDIR/version.lib.sh
if [[ "${__VERSION_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/version.lib.sh"; fi

# Öffentliche Konstanten für Skripte, die tools.lib.sh einbinden
# shellcheck disable=SC2034  # von einbindenden Skripten verwendet
readonly DASH10="----------"
# shellcheck disable=SC2034  # von einbindenden Skripten verwendet
readonly DASH50="--------------------------------------------------"
# shellcheck disable=SC2034  # von einbindenden Skripten verwendet
readonly DASH80="--------------------------------------------------------------------------------"

# Zeigt den Status des jeweiligen Files oder Folders an
#
# Die Breite der ersten Spalte ist fix auf 30 Zeichen
#
# Usage:
#   logFileStatus "Settings-ETC:     "  "${SETTINGS_ETC}"
#
# Params:
#   $1 - Beschreibung die angezeigt wird
#   $2 - File oder Dir
#   $3 - yes | no - Bei "no" wird keine Überprüfung gemacht

logFileStatus() {
    local _DESCRIPTION=${1}
    local _FILE_OR_FOLDER=${2}
    local _CHECK=${3-yes}

    # shellcheck disable=SC2155
    local _COL0=$(repeat " " 4)
    local _WIDTH_COL1=30
    # shellcheck disable=SC2155
    local _DESCRIPTION_COL_TRIMMED="$(echo -e "${_DESCRIPTION}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    local _LENGTH_DESCRIPTION_COL=${#_DESCRIPTION_COL_TRIMMED}
    # shellcheck disable=SC2155
    local _DESCRIPTION_COL="${_DESCRIPTION_COL_TRIMMED}$(repeat " " $((_WIDTH_COL1 - _LENGTH_DESCRIPTION_COL)))"

    local _MARKER_COLOR="${LIGHT_BLUE}"

    if [[ ${_CHECK} != "no" ]];then
        if [[ -e "${_FILE_OR_FOLDER}" ]];then
            _MARKER_COLOR="${GREEN}"
        else
            _MARKER_COLOR="${RED}"
        fi
    fi
    echo -e "${_COL0}${_DESCRIPTION_COL}${_MARKER_COLOR}${_FILE_OR_FOLDER}${NC}"
}

# Zeigt die Links des run-Scripts aus dem "docker/_ci"-Bereich an
#
# Kommt in den links ein http-String vor wir dieser durch die
# Farbe "Blau" ersetzt
#
# param1: Die Headline
# param2: Alle links die angezeigt werden sollen
#
# Usage:
#     readonly local _LINKS=(
#         "http://www.MikeMitterer.at/"
#         "http://www.Google.com/"
#         "Hallo     http://noch.ein.Test:8080"
#     )
#     showModuleLinks "Headline" "${_LINKS[@]}"
#
showModuleLinks() {
    local _PARAMS=("$@")
    local -r _HEADLINE="${1}"

    echo
    echo -e "${YELLOW}${_HEADLINE}:${NC}"
    echo

    for _LINK in "${_PARAMS[@]:1}"; do
      # Der link wird in Blau eingefärbt
      local _TMP=${_LINK/http/${BLUE}http}

      if [[ "${_LINK}" != "" ]]; then
        echo -e "    🔗 ${_TMP}${NC}"
      else
        echo
      fi
    done

    echo
}

# Wiederholt eine Sequenz von Zeichen
#
# Usage:
#     local _IP_IS="$(getIPFor "${_DOMAIN}")"
#     local _LEN="${#_DOMAIN}"
#     local _SPACE="$(repeat ' ' $((_LEN - 25)) )"
#
#     echo -e "    IP for ${_DOMAIN} is: ${_SPACE}${GREEN}${_IP_IS}${NC}"
#
#     -------------------------------------------------------------------------
#
#     echo -e "$(repeat '*' 80)\n"
#
# Params:
#     $1 - String der wiederholt werden soll
#     $2 - Anzahl der Wiederholungen
#
repeat() {
    local _START=1
    local _STRING_TO_REPEAT="${1:--}"
    local _MAX=${2:-80}

    local _RANGE
    # Ungültige Anzahl: seq meldet den Fehler, das aufrufende Skript läuft weiter (set -e)
    _RANGE=$(seq "${_START}" "${_MAX}") || true

    for i in $_RANGE ; do echo -n "${_STRING_TO_REPEAT}"; done
}

# Generiert aus dem Doc-Header des Scripts eine Dokumentation
#
# Zeilen die mit
#  #' - beginnen werden gelöscht
#  #" beginnen werden als Titel verwendet
#  #' beginnen werden als detaillierte Beschreibung verwendet
#  #| beginnen, wird bei der Ausgabe eine Leerzeile generiert
#
# Usage I:
#  #' ------------------------------------------------------------------------------
#  #" Die definierten src-Directories werden auf Veränderung überprüft.
#  #'
#  #' Sollte ein "package.json"-File vorhanden sein und "yarn" installiert sein,
#  #' wird zusätzlich der "yarn version"-Befehl ausgeführt und in die MD5-Prüfung
#  #' mit einbezogen.
#  #'
#  #' Als "Marker" für die Veränderung wird '.scrmd5' bzw. '.prev.scrmd5' verwendet.
#  #|
#  #' Sollte sich was geändert haben, kann das Modul "deployed" werden
#  #' und die Version nach oben gezogen.
#  #' ------------------------------------------------------------------------------
#
# Usage II:
#     readonly SCRIPT_DOC=$(scriptToDoc "${SCRIPT}")
#     [[ ${SCRIPT_DOC:-""} != "" ]] && echo -e "\n$(echo "${SCRIPT_DOC}" | sed 's/^//g')"
#     [[ ${SCRIPT_DOC:-""} != "" ]] && echo -e "\n${SCRIPT_DOC}"
#
scriptToDoc() {
    local _SCRIPT="$1"

    # printf "escapt" den Backslash (ESC) in den jeweiligen Farben
    #
    # Weitere Infos:
    #     https://askubuntu.com/a/1332058/723654
    #
    local _COLOR_HEADLINE _COLOR_DETAIL _NC _SCRIPT_DOC
    _COLOR_HEADLINE="$(printf %q "${DARK_GREY}")"
    _COLOR_DETAIL="$(printf %q "${LIGHT_GRAY}")"
    _NC="$(printf %q "${NC}")"

    # Der letzte Part in der |-Verkettung löscht die Leerzeilen!
    # Ohne Doku-Zeilen scheitert grep; das aufrufende Skript läuft weiter (set -e)
    _SCRIPT_DOC="$(\grep "^#['\"|]" "${_SCRIPT}" | sed "s/^#'[ ]*-[-]*//" | \
        sed "s/^#\" /${_COLOR_HEADLINE}/" | sed "s/^#'[ ]*/${_COLOR_DETAIL}/" | \
        sed 's/^[ ]*$//' | sed "N;s/\n/${_NC}/g" | sed 's/^#|[ ]*/\\n/')" || true

    echo "${_SCRIPT_DOC}${NC}"
}

# Entfernt führende und nachfolgende Leerzeichen aus einem String.
#
# Parameters:
#   $1 - Der zu trimmende String.
#
# Usage:
#     local _VAR="  Hallo Welt  "
#     local _TRIMMED_VAR=$(trim "${_VAR}")
#
# Returns:
#   Der getrimmte String.
#
trim() {
    local str="$1"
    # Entfernt führende und nachfolgende Leerzeichen
    str="${str#"${str%%[![:space:]]*}"}"  # Entfernt führende Leerzeichen
    str="${str%"${str##*[![:space:]]}"}"  # Entfernt nachfolgende Leerzeichen
    # printf statt echo: ein Text wie „-n“ bleibt erhalten
    printf '%s' "$str"
}
