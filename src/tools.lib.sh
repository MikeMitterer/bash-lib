#!/usr/bin/env bash
readonly __TOOLS_LIB__="tools.lib.sh";

#------------------------------------------------------------------------------
# Tools für Script - Unabhängig von Docker oder von den build.sh's
#
# Einbinden:
#     if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi
#
#------------------------------------------------------------------------------

if [[ "${__COLORS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/colors.lib.sh"; fi
if [[ "${__APPS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/apps.lib.sh"; fi
if [[ "${__DTIME_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/dtime.lib.sh"; fi

readonly DASH10="----------"
readonly DASH50="--------------------------------------------------"
readonly DASH80="--------------------------------------------------------------------------------"

# Theme-Ausgabe für alle Skripte. Farben und Abstände kommen aus colors.lib.sh.
# $1 Überschrift; THEME_GROUP_SPACING steuert die Leerzeilen davor.
printThemeHeading() {
    themeHeading "${1}"
}

# $1 Beschriftung, $2 Beschreibung, $3 zusätzliche Einrückung (optional).
printThemeRow() {
    themeLine "$@"
}

# $1 Symbol, $2 Text, $3 Farbrolle (SUCCESS, WARNING, DANGER, …).
# Inhalt und Umleitung nach stderr legt der Aufrufer fest.
printThemeStatus() {
    local -r _SYMBOL="${1}" _MESSAGE="${2}" _ROLE="${3}"
    local -r _COLOR_NAME="THEME_COLOR_${_ROLE}"
    printf '%s' "${THEME_INDENT_GROUP}"
    themeStyle "${_SYMBOL} ${_MESSAGE}" "${!_COLOR_NAME:-}"
    printf '\n'
}

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

# Helper zum Anzeigen der "Usage"
#
# Die Breite kommt aus THEME_WIDTH_TARGET in colors.lib.sh.
#
# Usage:
#       usageLine "info | -i                " "Show App-Settings"
#       usageLine "                         " "Sub-Zeile, wird eingerückt" "yes"
#       usageLine "                         " "Sub-Zeile wird um 8 Spaces eingerückt" 8
#
# Params:
#     $1 - Text der ersten Spalte, die Optionen
#     $2 - Text der zweiten Spalte, die Beschreibung
#     $3 - Die Einrückung der ersten Spalte (default: 4)
#          yes | no | intend | <Anzahl der Leerzeichen>
#
usageLine() {
    local _OPTIONS_COL="${1}" _DESCRIPTION_COL="${2}" _INDENT="${3:-no}"
    # Historische Aufrufe mit yes/intend oder einer Zahl bleiben gültig.
    case "${_INDENT}" in
        no) _INDENT=0 ;;
        yes|intend) _INDENT=4 ;;
        *) _INDENT=$(themeNumber "${_INDENT}" 0) ;;
    esac
    _OPTIONS_COL="${_OPTIONS_COL#"${_OPTIONS_COL%%[![:space:]]*}"}"
    _OPTIONS_COL="${_OPTIONS_COL%"${_OPTIONS_COL##*[![:space:]]}"}"
    _DESCRIPTION_COL="${_DESCRIPTION_COL#"${_DESCRIPTION_COL%%[![:space:]]*}"}"
    themeLine "${_OPTIONS_COL}" "${_DESCRIPTION_COL}" "${_INDENT}"
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
    local _HEADLINE=("${_PARAMS[@]:0}")

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

# Prüft ob der angegebene Port offen ist
#
# Usage:
#     local _IS_PORT_APP_SERVER_OPEN=$(isLocalPortOpen "${PORT_APP_SERVER}")
#     local _MARK_APP_SERVER_PORT=$(isLocalPortOpen "${PORT_APP_SERVER}" "${GREEN}" "${RED}")
#
# Weitere Infos:
#     https://adamtheautomator.com/check-if-a-port-is-open-in-linux/
#
isLocalPortOpen() {
    local _PORT=${1?"isPortOpen must be called with one parameter: 'PORT'"}
    local _RET_IF_OPEN=${2-'true'}
    local _RET_IF_CLOSED=${3-'false'}

    if [[ "$(lsof -i -P -n | \grep LISTEN | \grep :"${_PORT}")" != "" ]];then
      echo "${_RET_IF_OPEN}";
    else
      echo "${_RET_IF_CLOSED}";
    fi
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

    local _RANGE=$(seq "${_START}" "${_MAX}")

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
    local _COLOR_HEADLINE="$(printf %q "${DARK_GREY}")"
    local _COLOR_DETAIL="$(printf %q "${LIGHT_GRAY}")"
    local _NC="$(printf %q "${NC}")"

    # Der letzte Part in der |-Verkettung löscht die Leerzeilen!
    local _SCRIPT_DOC="$(\grep "^#['\"|]" "${_SCRIPT}" | sed "s/^#'[ ]*-[-]*//" | \
        sed "s/^#\" /${_COLOR_HEADLINE}/" | sed "s/^#'[ ]*/${_COLOR_DETAIL}/" | \
        sed 's/^[ ]*$//' | sed "N;s/\n/${_NC}/g" | sed 's/^#|[ ]*/\\n/')"

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
    echo "$str"
}

# Zeigt ein Menü an
#
# Parameters:
#   $1 (optional) - The title of the menu. Default is "Bitte wählen Sie eine Option:".
#   $2 (optional) - The options array. Default is default_options.
#
# Returns:
#   None
#
showMenu() {
    local _default_title="Choose option:"
    local _intent="${MM_GLOBAL_STYLE_INTENT:-    }"
    local _title_color="${MM_GLOBAL_STYLE_TITLE_COLOR:-${GREEN}}"
    local _bullet_color="${MM_GLOBAL_STYLE_BULLET_COLOR:-${YELLOW}}"
    local _hint_color="${MM_GLOBAL_STYLE_HINT_COLOR:-${BLUE}}"

    # Wenn nur ein Argument übergeben wird, prüfen, ob es sich um ein Array handelt
    if [[ $# -eq 1 ]] && [[ "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]]; then
        local _title="$_default_title"
        local -n _options=$1
    else
        local _title="${1:-$_default_title}"
        local -n _options="${2:-default_options}"
    fi

    echo -e "${_title_color}$_title${NC}"

    local _options_length=${#_options[@]}
    # for i in "${!_options[@]}"; do
    for (( i = 0; i < _options_length; i++)); do
        local _option="${_options[$i]}"
        # Split _option where the first | is found
        IFS='|' read -r -a _split <<< "${_option}"

        local _raw_option="$(trim "${_split[0]}")"
        local _description="$(trim "${_split[1]}")"

        local _option="${_raw_option}"
        local _has_bullets=false
        local _has_exit=false
        if [[ ${_raw_option} =~ ^- ]]; then
            _option=$(echo "${_raw_option}" | sed 's/^- //')
            _has_bullets=true
        elif [[ ${_raw_option} =~ ^x ]]; then
            _option=$(echo "${_raw_option}" | sed 's/^x //')
            _has_exit=true
        fi

        # Add space after _option where the max amount of characters is _option_length - 20
        local _max_length=30
        local _printable=$(echo -e "${_option}")
        local _not_printable=$(echo -e "${_option}" | tr -cd '[:print:]')

        # Subtract the length of the color codes
        local _length_diff=$(( ${#_printable} - ${#_not_printable} ))

        # Wenn _length_diff > 0 dann sind Farben im Spiel
        if [[ ${_length_diff} -gt 0 ]]; then
            _option_length=${_length_diff}
        else
            _option_length=${#_printable}
        fi

        local _nr_of_spaces=$(( _max_length - _option_length ))
        local _spaces="$(repeat " " $_nr_of_spaces)"

        if [[ ${_has_bullets} == true ]]; then
            echo -e "${_intent}${_bullet_color}$((i+1)).${NC} ${_option}${_spaces}${_hint_color}${_description}${NC}"
        elif [[ ${_has_exit} == true ]]; then
            echo
            echo -e "${_intent}   ${_option}${_spaces}${_hint_color}${_description}${NC}"
        else
            echo -e "${_intent}${_option}${_spaces}${_hint_color}${_description}${NC}"
        fi
    done
}
