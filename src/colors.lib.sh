#!/usr/bin/env bash
# shellcheck disable=SC2034
readonly __COLORS_LIB__="colors.lib.sh";

#------------------------------------------------------------------------------
# ANSI Colors für diverse Scripts
#
# Die Palette (RED, GREEN, NC, …) bleibt fest. Farben und Abstände der
# Theme-Helfer (themeLine, themeHeading und die print*-Helfer in tools.lib.sh)
# kommen aus der Theme-Datei von CLITheme, siehe Abschnitt „CLI-Theme“ unten
# und docs/themes.md.
#
# Einbinden:
#     if [[ "${__COLORS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/colors.lib.sh"; fi
#
# Usage:
#     Sample: echo -e "I ${RED}love${NC} Stack Overflow\n"
#
# Weitere Infos:
#       https://en.wikipedia.org/wiki/ANSI_escape_code#3-bit_and_4-bit
#       https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
#       https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
#
# Mit 'showScriptColors' oder 'showAllColors' können die Farben zum testen
# ausgegeben werden.
#
#------------------------------------------------------------------------------

# ANSI-Color Farbcode wird mit ESC eingeleitet
# Macht die ganze Sache lesbarer
readonly ESC="\x1B"

# Followed by the command, somtimes delimited by opening 
# square bracket ([), known as a 
# Control Sequence Introducer (CSI), optionally followed 
# by arguments and the command itself.
readonly CSI="["

# [38 + [48 - definieren den 256 Color-Space
# [38;5 - Vordergrund
# [48;5 - Hintergrund
readonly FG_COLOR="38;5"
readonly BG_COLOR="48;5"

# https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797#256-colors 
readonly ANSI_COLOR_RED="196"
readonly ANSI_COLOR_GREEN="10"
readonly ANSI_COLOR_YELLOW="11"
readonly ANSI_COLOR_ORANGE="208"
readonly ANSI_COLOR_BROWN="94"
readonly ANSI_COLOR_BLUE="33"
readonly ANSI_COLOR_PURPLE="164"
readonly ANSI_COLOR_CYAN="51"
readonly ANSI_COLOR_DARK_GREY="245"
readonly ANSI_COLOR_GREY="${ANSI_COLOR_DARK_GREY}"

readonly ANSI_COLOR_LIGHT_RED="203"
readonly ANSI_COLOR_LIGHT_GREEN="155"
readonly ANSI_COLOR_LIGHT_BLUE="45"
readonly ANSI_COLOR_LIGHT_PURPLE="170"
readonly ANSI_COLOR_LIGHT_CYAN="123"
readonly ANSI_COLOR_LIGHT_GRAY="251"
readonly ANSI_COLOR_WHITE="15"

# Grep-Colors --------------------------------------------------------------------------------------
# Usage:
#     GREP_COLOR='${GREP_COLOR_GREEN}' \grep --color='auto' '^[^=]*'"

readonly GREP_COLOR_RED="${FG_COLOR};${ANSI_COLOR_RED}"
readonly GREP_COLOR_GREEN="${FG_COLOR};${ANSI_COLOR_GREEN}"
readonly GREP_COLOR_YELLOW="${FG_COLOR};${ANSI_COLOR_YELLOW}"
readonly GREP_COLOR_ORANGE="${FG_COLOR};${ANSI_COLOR_ORANGE}"
readonly GREP_COLOR_BROWN="${FG_COLOR};${ANSI_COLOR_BROWN}"
readonly GREP_COLOR_BLUE="${FG_COLOR};${ANSI_COLOR_BLUE}"
readonly GREP_COLOR_PURPLE="${FG_COLOR};${ANSI_COLOR_PURPLE}"
readonly GREP_COLOR_CYAN="${FG_COLOR};${ANSI_COLOR_CYAN}"
readonly GREP_COLOR_DARK_GREY="${FG_COLOR};${ANSI_COLOR_DARK_GREY}"
readonly GREP_COLOR_GREY="${GREP_COLOR_DARK_GREY}"

readonly GREP_COLOR_LIGHT_RED="${FG_COLOR};${ANSI_COLOR_LIGHT_RED}"
readonly GREP_COLOR_LIGHT_GREEN="${FG_COLOR};${ANSI_COLOR_LIGHT_GREEN}"
readonly GREP_COLOR_LIGHT_BLUE="${FG_COLOR};${ANSI_COLOR_LIGHT_BLUE}"
readonly GREP_COLOR_LIGHT_PURPLE="${FG_COLOR};${ANSI_COLOR_LIGHT_PURPLE}"
readonly GREP_COLOR_LIGHT_CYAN="${FG_COLOR};${ANSI_COLOR_LIGHT_CYAN}"
readonly GREP_COLOR_LIGHT_GRAY="${FG_COLOR};${ANSI_COLOR_LIGHT_GRAY}"
readonly GREP_COLOR_WHITE="${FG_COLOR};${ANSI_COLOR_WHITE}"

# Shell-Colors -------------------------------------------------------------------------------------
# Usage:
#     echo -e "${GREEN}This line has '\${GREEN}'-Foreground${NC}"

readonly RED="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_RED}m"
readonly GREEN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_GREEN}m"
readonly YELLOW="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_YELLOW}m"
readonly ORANGE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_ORANGE}m"
readonly BROWN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_BROWN}m"
readonly BLUE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_BLUE}m"
readonly PURPLE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_PURPLE}m"
readonly CYAN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_CYAN}m"
readonly DARK_GREY="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_DARK_GREY}m"
readonly GREY="${DARK_GREY}"

readonly LIGHT_RED="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIGHT_RED}m"
readonly LIGHT_GREEN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIGHT_GREEN}m"
readonly LIGHT_BLUE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIGHT_BLUE}m"
readonly LIGHT_PURPLE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIGHT_PURPLE}m"
readonly LIGHT_CYAN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIGHT_CYAN}m"
readonly LIGHT_GRAY="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIGHT_GRAY}m"
readonly WHITE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_WHITE}m"

readonly SUCCESS=${GREEN}
readonly INFO=${BLUE}
readonly WARNING=${ORANGE}
readonly FAILED=${RED}
readonly ERROR=${RED}

readonly NC="${ESC}[0m" # No Color

colorGreen() {
    local TEXT=${1}
    echo -e "${GREEN}${TEXT}${NC}"
}

colorError() {
    local TEXT=${1}
    echo -e "${ERROR}${TEXT}${NC}"
}

#------------------------------------------------------------------------------
# DIALOG
#   https://linux.die.net/man/1/dialog
#   https://stackoverflow.com/a/27875395/504184
#

readonly DCBLACK='\Z0'
readonly DCRED='\Z1'
readonly DCGREEN='\Z2'
readonly DCYELLOW='\Z3'
readonly DCBLUE='\Z4'
readonly DCMAGENTA='\Z5'
readonly DCCYAN='\Z6'
readonly DCWHITE='\Z7'
readonly DCOFF='\Zn'

readonly DCSUCCESS=${DCGREEN}
readonly DCINFO=${DCBLUE}
readonly DCWARNING=${DCYELLOW}
readonly DCFAILED=${DCRED}
readonly DCERROR=${DCRED}

#------------------------------------------------------------------------------
# Colors (https://goo.gl/ku0OM6)

# Kann nicht gelöscht werden - wurde bei
# allen Docker-Gen-Scripts verwendet!!!!
#     build -s
#
readonly C1="${GREEN}" # Green
readonly C2="${RED}" # Red
readonly C0="${NC}" # No Color

#
# readonly CM1='\033[1;33m' # Yellow (Menu)
# readonly CM0='\033[0m' # No Color

# Für SED - hier wird ein doppeltes Escape benötigt
readonly SED_GREEN='\\033[38;5;10m'
readonly SED_YELLOW='\\033[38;5;11m'
readonly SED_RED='\\033[38;5;196m'
readonly SED_NC='\\033[0m' # No Color

#readonly CMM1='\\033[1;33m'
#readonly CMM0='\\033[0m'

#readonly SED_GREEN=$CC1
#readonly SED_RED=$CC2

#------------------------------------------------------------------------------
# Sample Colors

showScriptColors() {
    echo
    echo -e "${RED}This line has '\${RED}'-Foreground"
    echo -e "${GREEN}This line has '\${GREEN}'-Foreground"
    echo -e "${YELLOW}This line has '\${YELLOW}'-Foreground"
    echo -e "${ORANGE}This line has '\${ORANGE}'-Foreground"
    echo -e "${BROWN}This line has '\${BROWN}'-Foreground"
    echo -e "${BLUE}This line has '\${BLUE}'-Foreground"
    echo -e "${PURPLE}This line has '\${PURPLE}'-Foreground"
    echo -e "${CYAN}This line has '\${CYAN}'-Foreground"
    echo -e "${GREY}This line has '\${GREY}'-Foreground"
    echo
    echo -e "${LIGHT_RED}This line has '\${LIGHT_RED}'-Foreground"
    echo -e "${LIGHT_GREEN}This line has '\${LIGHT_GREEN}'-Foreground"
    echo -e "${LIGHT_BLUE}This line has '\${LIGHT_BLUE}'-Foreground"
    echo -e "${LIGHT_PURPLE}This line has '\${LIGHT_PURPLE}'-Foreground"
    echo -e "${LIGHT_CYAN}This line has '\${LIGHT_CYAN}'-Foreground"
    echo -e "${LIGHT_GRAY}This line has '\${LIGHT_GRAY}'-Foreground"
    echo -e "${WHITE}This line has '\${WHITE}'-Foreground"
    echo
    echo -e "${SUCCESS}This line has '\${SUCCESS}'-Foreground"
    echo -e "${INFO}This line has '\${INFO}'-Foreground"
    echo -e "${WARNING}This line has '\${WARNING}'-Foreground"
    echo -e "${FAILED}This line has '\${FAILED}'-Foreground"
    echo -e "${ERROR}This line has '\${ERROR}'-Foreground${NC}"
    echo
}

# Alle 256 verfügbaren Farben werden in einer Loop ausgegeben
#
# Usage:
#   showAllColors
#
showAllColors() {
    echo
    showColorsInRange "Default colors" 0 7
    echo
    showColorsInRange "High-intensity colors" 8 15
    echo
    showColorsInRange "216 Colors" 16 231
    echo
    showColorsInRange "Grayscale colors" 232 255
    echo
    echo "More infos on Wikipedia: https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit"
    echo
}

# Zeigt die ANSI-Farben in einem bestimmten Range an
#
# SO zum Range:
#   https://stackoverflow.com/questions/169511/how-do-i-iterate-over-a-range-of-numbers-defined-by-variables-in-bash
#
# Usage:
#    showColorsInRange "Default colors" 0 7
#   
showColorsInRange() {
    local DESCRIPTION="$1"
    local FROM="$2"
    local TO="$3"

    echo "${DESCRIPTION}:"
    for COLOR in $(seq "${FROM}" "${TO}"); do
        echo -e "   ${ESC}[38;5;${COLOR}m - Color code is '\$ESC[38;5;${COLOR}m' 0123456789 *+#${NC}";
    done
}





# Ergänzte MakeLib-Palette; vorhandene Konstanten behalten ihre Werte.
readonly ANSI_COLOR_BLACK="0"
readonly BLACK="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_BLACK}m"
readonly ANSI_COLOR_STEEL_BLUE="75"
readonly STEEL_BLUE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_STEEL_BLUE}m"
readonly ANSI_COLOR_GOLD="220"
readonly GOLD="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_GOLD}m"
readonly ANSI_COLOR_CORAL="203"
readonly CORAL="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_CORAL}m"
readonly ANSI_COLOR_TAN="179"
readonly TAN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_TAN}m"
readonly ANSI_COLOR_OLIVE="143"
readonly OLIVE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_OLIVE}m"
readonly ANSI_COLOR_AMBER="208"
readonly AMBER="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_AMBER}m"
readonly ANSI_COLOR_BRICK="160"
readonly BRICK="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_BRICK}m"
readonly ANSI_COLOR_SLATE_BLUE="111"
readonly SLATE_BLUE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_SLATE_BLUE}m"
readonly ANSI_COLOR_TEAL="79"
readonly TEAL="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_TEAL}m"
readonly ANSI_COLOR_SALMON="215"
readonly SALMON="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_SALMON}m"
readonly ANSI_COLOR_HOT_PINK="197"
readonly HOT_PINK="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_HOT_PINK}m"
readonly ANSI_COLOR_PINK="205"
readonly PINK="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_PINK}m"
readonly ANSI_COLOR_CREAM="223"
readonly CREAM="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_CREAM}m"
readonly ANSI_COLOR_BRIGHT_RED="196"
readonly BRIGHT_RED="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_BRIGHT_RED}m"
readonly ANSI_COLOR_DARK_GREEN="34"
readonly DARK_GREEN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_DARK_GREEN}m"
readonly ANSI_COLOR_LIME="77"
readonly LIME="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIME}m"
readonly ANSI_COLOR_PALE_GREEN="151"
readonly PALE_GREEN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_PALE_GREEN}m"
readonly ANSI_COLOR_STRAW="185"
readonly STRAW="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_STRAW}m"
readonly ANSI_COLOR_TERRACOTTA="167"
readonly TERRACOTTA="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_TERRACOTTA}m"
readonly ANSI_COLOR_MAGENTA="201"
readonly MAGENTA="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_MAGENTA}m"
readonly ANSI_COLOR_NEON_GREEN="118"
readonly NEON_GREEN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_NEON_GREEN}m"
readonly ANSI_COLOR_NEON_YELLOW="226"
readonly NEON_YELLOW="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_NEON_YELLOW}m"
readonly BOLD="${ESC}[1m"
readonly RESET="${NC}"

# CLI-Theme ----------------------------------------------------------------------------------------
# Farben und Abstände kommen aus der Theme-Datei von CLITheme (mmit-cli-theme):
#     ${XDG_CONFIG_HOME:-~/.config}/cli-theme/${CLI_THEME:-classic}.theme
# Die Datei wird beim Einbinden einmal gelesen, Zeile für Zeile mit den Regeln von
# CLITheme und nie mit source; eine fremde Datei führt so keinen Code aus.
# MAKE_THEME gilt als veralteter Ersatzname, wenn CLI_THEME fehlt.
#
# Danach stehen die Rollen C_HEAD … C_MARK als Rohwert der Datei (bold+11, dim, …)
# und die Abstände I_HEAD … SPACE als Zahl bereit; C_OFF beendet eine Farbe.
# THEME_NAME, THEME_SOURCE und THEME_ORIGIN nennen das gewählte Theme, seine
# Datei und woher die Wahl kommt (CLI_THEME, MAKE_THEME oder Standard).
# Die THEME_*-Variablen werden aus den Rollen gesetzt; im Skript vor dem Einbinden
# gesetzte THEME_*-Werte gewinnen, geerbte (exportierte) nicht.
#
# Ohne gültige Datei: keine Farben, Abstände der classic-Vorlage, ein Hinweis auf
# stderr bei der ersten Theme-Ausgabe am Terminal.

# Rollen und Abstände der Theme-Datei, Reihenfolge wie in CLITheme.
readonly THEME_ROLES="C_HEAD C_KEY C_TEXT C_VAL C_HINT C_ACC C_OK C_WARN C_ERR C_MARK"
readonly THEME_SPACING="I_HEAD I_ROW I_HINT W_KEY GAP WIDTH SPACE"
# Abstände der classic-Vorlage von CLITheme; test/_testTheme.sh vergleicht sie mit
# der installierten Vorlage.
readonly THEME_CLASSIC_SPACING="I_HEAD=2 I_ROW=7 I_HINT=7 W_KEY=21 GAP=2 WIDTH=120 SPACE=1"

readonly C_OFF="${NC}"

# Hinweis zur Theme-Datei (zwei Zeilen: Befund, nächster Schritt); themeNotice gibt
# ihn einmal aus.
THEME_NOTICE=""

# Escape-Folge zu einer Farbangabe der Theme-Datei; leer bleibt leer.
# $1 Name der Zielvariable, $2 Farbangabe (bold+11, dim, 33, …)
themeSgr() {
    local -r _TARGET="${1}" _SPEC="${2}"
    local _CODES
    case "${_SPEC}" in
        "") _CODES="" ;;
        bold) _CODES="1" ;;
        dim) _CODES="2" ;;
        bold+*) _CODES="1;${FG_COLOR};$((10#${_SPEC#bold+}))" ;;
        dim+*) _CODES="2;${FG_COLOR};$((10#${_SPEC#dim+}))" ;;
        *) _CODES="${FG_COLOR};$((10#${_SPEC}))" ;;
    esac
    if [[ -n ${_CODES} ]]; then
        printf -v "${_TARGET}" '%s' "${ESC}${CSI}${_CODES}m"
    else
        printf -v "${_TARGET}" '%s' ""
    fi
}

# Liest die Theme-Datei in _THEME_<NAME>; Fehler stehen danach in THEME_NOTICE.
# Gibt 1 zurück, wenn die Datei fehlt oder ungültig ist.
themeRead() {
    local -r _FILE="${1}"
    local _LINE _ENTRY _KEY _VALUE _NUMBER=0 _NAME _MISSING=""
    local -r _ENTRY_PATTERN='^([A-Z][A-Z_]*)=(.*)$'
    local -r _COLOR_PATTERN='^((bold|dim)\+)?([0-9]{1,3})$|^(bold|dim)?$'

    while IFS= read -r _LINE || [[ -n ${_LINE} ]]; do
        _NUMBER=$((_NUMBER + 1))
        _ENTRY="${_LINE%%#*}"
        _ENTRY="${_ENTRY#"${_ENTRY%%[![:space:]]*}"}"
        _ENTRY="${_ENTRY%"${_ENTRY##*[![:space:]]}"}"
        [[ -n ${_ENTRY} ]] || continue

        _KEY="" _VALUE=""
        if [[ ${_ENTRY} =~ ${_ENTRY_PATTERN} ]]; then
            _KEY="${BASH_REMATCH[1]}"
            _VALUE="${BASH_REMATCH[2]}"
            _VALUE="${_VALUE#"${_VALUE%%[![:space:]]*}"}"
        fi
        if [[ " ${THEME_ROLES} " == *" ${_KEY} "* && ${_VALUE} =~ ${_COLOR_PATTERN} ]] \
            && (( 10#${BASH_REMATCH[3]:-0} < 256 )); then
            printf -v "_THEME_${_KEY}" '%s' "${_VALUE}"
        elif [[ " ${THEME_SPACING} " == *" ${_KEY} "* && ${_VALUE} =~ ^[0-9]+$ ]]; then
            printf -v "_THEME_${_KEY}" '%d' "$((10#${_VALUE}))"
        else
            _LINE="${_LINE%"${_LINE##*[![:space:]]}"}"
            THEME_NOTICE="${_FILE}:${_NUMBER}: ungültiger Eintrag '${_LINE#"${_LINE%%[![:space:]]*}"}'"
            return 1
        fi
    done < "${_FILE}"

    for _NAME in ${THEME_ROLES} ${THEME_SPACING}; do
        _KEY="_THEME_${_NAME}"
        [[ -n ${!_KEY+x} ]] || _MISSING="${_MISSING:+${_MISSING}, }${_NAME}"
    done
    if [[ -n ${_MISSING} ]]; then
        THEME_NOTICE="${_FILE}: fehlende Einträge ${_MISSING}"
        return 1
    fi
}

# Wahr, wenn das Skript $1 selbst gesetzt hat: gesetzt und nicht aus der Umgebung
# geerbt (exportiert).
themeOwn() {
    local -r _EXPORTED='^declare -[A-Za-z]*x'
    [[ -n ${!1+x} && ! $(declare -p "${1}" 2>/dev/null) =~ ${_EXPORTED} ]]
}

# Sucht und liest die Theme-Datei wie CLITheme und setzt Rollen, Abstände und THEME_*.
# Ungültige Angaben fallen als Ganzes zurück: keine Farben, Abstände von classic.
themeLoad() {
    local _SELECTED="${CLI_THEME:-${MAKE_THEME:-classic}}"
    local _BASE="${XDG_CONFIG_HOME:-}" _FOLDER _FILE _ENTRY _ROLE _SOURCE _SGR _LOADED=no
    # Ein relativer XDG_CONFIG_HOME gilt nach der XDG-Spezifikation nicht.
    [[ ${_BASE} == /* ]] || _BASE="${HOME}/.config"
    _FOLDER="${_BASE}/cli-theme"
    _FILE="${_FOLDER}/${_SELECTED}.theme"
    # Name, Ort und Herkunft des gewählten Themes, etwa für eine Info-Ausgabe
    THEME_NAME="${_SELECTED}"
    THEME_SOURCE="${_FILE}"
    if [[ -n ${CLI_THEME:-} ]]; then THEME_ORIGIN="CLI_THEME"
    elif [[ -n ${MAKE_THEME:-} ]]; then THEME_ORIGIN="MAKE_THEME"
    else THEME_ORIGIN="Standard"
    fi

    for _ROLE in ${THEME_ROLES} ${THEME_SPACING}; do unset "_THEME_${_ROLE}"; done
    if [[ ! ${_SELECTED} =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
        THEME_NOTICE="Ungültiger CLI_THEME '${_SELECTED}'"
    elif [[ -L ${_FOLDER} || -L ${_FILE} ]]; then
        THEME_NOTICE="$([[ -L ${_FOLDER} ]] && printf '%s' "${_FOLDER}" || printf '%s' "${_FILE}") ist ein Link; aus Sicherheitsgründen abgelehnt"
    elif [[ ! -e ${_FILE} ]]; then
        THEME_NOTICE="CLI-Theme fehlt (${_FILE})"$'\n'"cli-theme install"
    elif [[ ! -f ${_FILE} ]]; then
        THEME_NOTICE="${_FILE} ist keine reguläre Datei"
    elif [[ ! -r ${_FILE} ]]; then
        THEME_NOTICE="${_FILE}: nicht lesbar"
    elif themeRead "${_FILE}"; then
        _LOADED=yes
    fi
    # Ein Befund ohne eigenen nächsten Schritt verweist auf cli-theme show.
    [[ -z ${THEME_NOTICE} || ${THEME_NOTICE} == *$'\n'* ]] || THEME_NOTICE+=$'\n'"cli-theme show"

    for _ROLE in ${THEME_ROLES}; do
        _ENTRY="_THEME_${_ROLE}"
        [[ ${_LOADED} == yes ]] && printf -v "${_ROLE}" '%s' "${!_ENTRY}" || printf -v "${_ROLE}" '%s' ""
    done
    for _ENTRY in ${THEME_CLASSIC_SPACING}; do
        _ROLE="_THEME_${_ENTRY%%=*}"
        [[ ${_LOADED} == yes ]] && printf -v "${_ENTRY%%=*}" '%d' "${!_ROLE}" || printf -v "${_ENTRY%%=*}" '%d' "${_ENTRY#*=}"
    done
    for _ROLE in ${THEME_ROLES} ${THEME_SPACING}; do unset "_THEME_${_ROLE}"; done

    # Kompatibilität: THEME_* aus den Rollen. Im Skript vor dem Einbinden gesetzte
    # Werte gewinnen; geerbte, exportierte (etwa von MakeLib aus make) nicht.
    for _ENTRY in GROUP=C_HEAD TARGET=C_KEY DESC=C_TEXT VALUE=C_VAL HINT=C_HINT ACCENT=C_ACC \
        SUCCESS=C_OK WARNING=C_WARN DANGER=C_ERR SERVER=C_MARK; do
        _ROLE="THEME_COLOR_${_ENTRY%%=*}" _SOURCE="${_ENTRY#*=}"
        if ! themeOwn "${_ROLE}"; then
            themeSgr _SGR "${!_SOURCE}"
            printf -v "${_ROLE}" '%s' "${_SGR}"
        fi
    done
    for _ENTRY in GROUP=I_HEAD TARGET=I_ROW HINT=I_HINT; do
        _ROLE="THEME_INDENT_${_ENTRY%%=*}" _SOURCE="${_ENTRY#*=}"
        themeOwn "${_ROLE}" || printf -v "${_ROLE}" '%*s' "${!_SOURCE}" ''
    done
    for _ENTRY in WIDTH_TARGET=W_KEY COLUMN_GAP=GAP WIDTH_HELP=WIDTH GROUP_SPACING=SPACE; do
        _ROLE="THEME_${_ENTRY%%=*}" _SOURCE="${_ENTRY#*=}"
        themeOwn "${_ROLE}" || printf -v "${_ROLE}" '%s' "${!_SOURCE}"
    done
}

themeLoad

# Gibt den Hinweis zur Theme-Datei einmal auf stderr aus, nur am Terminal.
themeNotice() {
    [[ -n ${THEME_NOTICE} && -t 2 ]] || return 0
    printf '%s⚠ %s\n%s%s\n' "${THEME_INDENT_GROUP}" "${THEME_NOTICE%%$'\n'*}" \
        "${THEME_INDENT_HINT}" "${THEME_NOTICE#*$'\n'}" >&2
    THEME_NOTICE=""
}

# Nur neue Theme-Helfer berücksichtigen TTY/NO_COLOR. Alte ANSI-Konstanten
# bleiben unverändert, auch für bestehende printf-%b-/echo-e-Aufrufer.
themeStyle() {
    local -r _STYLE_TEXT="${1}" _COLOR="${2}"
    if [[ -t 1 && -z ${NO_COLOR+x} && ${TERM:-} != dumb && -n ${_COLOR} ]]; then
        printf '%b%b%b' "${_COLOR}" "${_STYLE_TEXT}" "${NC}"
    else
        themePlain "${_STYLE_TEXT}"
    fi
}

# Vorhandene Farbfragmente in usageLine-Texten bleiben am Terminal nutzbar.
# Für Pipe/NO_COLOR ANSI-Codes erst decodieren und dann entfernen.
themePlain() {
    local _PLAIN_TEXT
    _PLAIN_TEXT=$(printf '%b' "${1}")
    local -r _ANSI_PATTERN=$'\033''\[[0-9;]*m'
    while [[ ${_PLAIN_TEXT} =~ ${_ANSI_PATTERN} ]]; do
        _PLAIN_TEXT=${_PLAIN_TEXT//"${BASH_REMATCH[0]}"/}
    done
    printf '%s' "${_PLAIN_TEXT}"
}

# Liefert für ungültige Breiten den Standard, ohne Shell-Auswertung des Werts.
themeNumber() {
    local -r _VALUE="${1}" _DEFAULT="${2}"
    if [[ ${_VALUE} =~ ^[0-9]{1,3}$ ]]; then
        printf '%d' "$((10#${_VALUE}))"
    else
        printf '%d' "${_DEFAULT}"
    fi
}

# Zwei Spalten; lange Beschriftung erhält eine eigene Zeile.
# $3 erhält die zusätzliche Beschreibungseinrückung von usageLine,
# $4 die Farbe der rechten Spalte (Standard THEME_COLOR_DESC).
# shellcheck disable=SC2153  # W_KEY und GAP setzt themeLoad mit printf -v
themeLine() {
    local -r _LABEL="${1}" _LINE_TEXT="${2}" _EXTRA="${3:-0}" _TEXT_COLOR="${4-${THEME_COLOR_DESC}}"
    local _WIDTH _GAP _PADDING _PLAIN_LABEL
    themeNotice
    _PLAIN_LABEL=$(themePlain "${_LABEL}")
    _WIDTH=$(themeNumber "${THEME_WIDTH_TARGET}" "${W_KEY}")
    _GAP=$(themeNumber "${THEME_COLUMN_GAP}" "${GAP}")
    (( _GAP >= 1 )) || _GAP=1
    _WIDTH=$((_WIDTH + _EXTRA))
    printf '%s' "${THEME_INDENT_TARGET}"
    themeStyle "${_LABEL}" "${THEME_COLOR_TARGET}"
    if (( ${#_PLAIN_LABEL} > _WIDTH )); then
        printf '\n%s' "${THEME_INDENT_TARGET}"
        _PADDING=$((_WIDTH + _GAP))
    else
        _PADDING=$((_WIDTH - ${#_PLAIN_LABEL} + _GAP))
    fi
    printf '%*s' "${_PADDING}" ''
    themeStyle "${_LINE_TEXT}" "${_TEXT_COLOR}"
    printf '\n'
}

# Gruppenüberschrift mit konfigurierbarem Abstand davor.
# shellcheck disable=SC2153  # SPACE setzt themeLoad mit printf -v
themeHeading() {
    local _SPACING _INDEX
    themeNotice
    _SPACING=$(themeNumber "${THEME_GROUP_SPACING}" "${SPACE}")
    for ((_INDEX=0; _INDEX<_SPACING; _INDEX++)); do printf '\n'; done
    printf '%s' "${THEME_INDENT_GROUP}"
    themeStyle "${1}" "${THEME_COLOR_GROUP}"
    printf '\n'
}
