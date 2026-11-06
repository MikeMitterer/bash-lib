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
# Farben und Abstände kommen von CLITheme: `clitheme export --bash` liest das gewählte
# Theme (CLI_THEME, Datei unter ${XDG_CONFIG_HOME:-~/.config}/clitheme/) und gibt die
# aufgelösten THEME_*-Werte gequotet aus. BashLib liest die Theme-Datei nicht selbst;
# Prüfung, Ersatzwerte und Sicherheitsregeln gelten nur in CLITheme.
#
# Danach stehen THEME_COLOR_* (Escape-Text \x1B[…m wie die Palette), THEME_INDENT_*,
# THEME_WIDTH_TARGET, THEME_COLUMN_GAP, THEME_WIDTH_HELP und THEME_GROUP_SPACING bereit,
# dazu THEME_NAME, THEME_SOURCE und THEME_ORIGIN. Im Skript vor dem Einbinden gesetzte
# THEME_*-Werte gewinnen, geerbte (exportierte) nicht.
#
# Ohne clitheme oder wenn clitheme export scheitert: keine Farben, die Abstände unten,
# ein Hinweis auf stderr bei der ersten Theme-Ausgabe am Terminal, je Fall mit dem
# passenden nächsten Schritt.

# Farben und Abstände, die clitheme export --bash setzt und ein Skript selbst vorgeben darf;
# dazu setzt export THEME_NAME, THEME_SOURCE, THEME_ORIGIN und THEME_NOTICE.
readonly THEME_EXPORTED="THEME_COLOR_GROUP THEME_COLOR_TARGET THEME_COLOR_DESC THEME_COLOR_VALUE THEME_COLOR_HINT
    THEME_COLOR_ACCENT THEME_COLOR_SUCCESS THEME_COLOR_WARNING THEME_COLOR_DANGER THEME_COLOR_SERVER
    THEME_INDENT_GROUP THEME_INDENT_TARGET THEME_INDENT_HINT
    THEME_WIDTH_TARGET THEME_COLUMN_GAP THEME_WIDTH_HELP THEME_GROUP_SPACING"
# Abstände ohne clitheme (wie die classic-Vorlage) und für ungültige Werte
readonly THEME_FALLBACK_WIDTH_TARGET=21 THEME_FALLBACK_COLUMN_GAP=2 THEME_FALLBACK_GROUP_SPACING=1
# Installationsweg von CLITheme für den Hinweis ohne clitheme
readonly THEME_CLITHEME_INSTALL="pipx install git+https://github.com/MikeMitterer/python-clitheme.git"

readonly C_OFF="${NC}"

# Wahr, wenn das Skript $1 selbst gesetzt hat: gesetzt und nicht aus der Umgebung
# geerbt (exportiert).
themeOwn() {
    local -r _EXPORTED='^declare -[A-Za-z]*x'
    [[ -n ${!1+x} && ! $(declare -p "${1}" 2>/dev/null) =~ ${_EXPORTED} ]]
}

# Setzt die THEME_*-Werte aus clitheme export --bash. Eigene Werte des Skripts bleiben;
# ohne clitheme gibt es keine Farben und die Ersatzabstände.
# shellcheck disable=SC2034  # THEME_* liest der Aufrufer
themeLoad() {
    local _name _export _value _own=() _values=()
    local -r _escape=$'\033' _escapeText='\x1B'
    for _name in ${THEME_EXPORTED}; do
        if themeOwn "${_name}"; then
            _own+=("${_name}")
            _values+=("${!_name}")
        fi
    done

    # THEME_NOTICE: Hinweis zum Theme (zwei Zeilen: Befund, nächster Schritt); themeNotice
    # gibt ihn einmal aus.
    THEME_NAME="${CLI_THEME:-classic}" THEME_SOURCE="" THEME_ORIGIN="" THEME_NOTICE=""
    for _name in GROUP TARGET DESC VALUE HINT ACCENT SUCCESS WARNING DANGER SERVER; do
        printf -v "THEME_COLOR_${_name}" '%s' ""
    done
    THEME_INDENT_GROUP="  " THEME_INDENT_TARGET="       " THEME_INDENT_HINT="       "
    THEME_WIDTH_TARGET="${THEME_FALLBACK_WIDTH_TARGET}" THEME_COLUMN_GAP="${THEME_FALLBACK_COLUMN_GAP}"
    THEME_WIDTH_HELP=120 THEME_GROUP_SPACING="${THEME_FALLBACK_GROUP_SPACING}"

    if ! command -v clitheme >/dev/null 2>&1; then
        THEME_NOTICE="clitheme fehlt, Ausgabe ohne Farben"$'\n'"${THEME_CLITHEME_INSTALL}"
    elif _export="$(clitheme export --bash 2>/dev/null)"; then
        # clitheme quotet jeden Wert; die Ausgabe enthält nur Zuweisungen an THEME_*.
        eval "${_export}"
        # Escape-Bytes als Escape-Text wie die Palette: themeStyle setzt sie mit %b um.
        # Ersatz über eine Variable, damit der Escape-Text wörtlich bleibt.
        for _name in GROUP TARGET DESC VALUE HINT ACCENT SUCCESS WARNING DANGER SERVER; do
            _name="THEME_COLOR_${_name}"
            _value="${!_name}"
            printf -v "${_name}" '%s' "${_value//${_escape}/${_escapeText}}"
        done
    else
        # Installiert, aber gescheitert: der Aufruf zeigt den Grund.
        THEME_NOTICE="clitheme export gescheitert, Ausgabe ohne Farben"$'\n'"clitheme export --bash"
    fi

    for _name in "${!_own[@]}"; do
        printf -v "${_own[_name]}" '%s' "${_values[_name]}"
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
# Breite und Abstand aus dem Theme; ungültige Werte fallen auf THEME_FALLBACK_* zurück.
themeLine() {
    local -r _LABEL="${1}" _LINE_TEXT="${2}" _EXTRA="${3:-0}" _TEXT_COLOR="${4-${THEME_COLOR_DESC}}"
    local _WIDTH _GAP _PADDING _PLAIN_LABEL
    themeNotice
    _PLAIN_LABEL=$(themePlain "${_LABEL}")
    _WIDTH=$(themeNumber "${THEME_WIDTH_TARGET}" "${THEME_FALLBACK_WIDTH_TARGET}")
    _GAP=$(themeNumber "${THEME_COLUMN_GAP}" "${THEME_FALLBACK_COLUMN_GAP}")
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
# Leerzeilen davor aus THEME_GROUP_SPACING.
themeHeading() {
    local _SPACING _INDEX
    themeNotice
    _SPACING=$(themeNumber "${THEME_GROUP_SPACING}" "${THEME_FALLBACK_GROUP_SPACING}")
    for ((_INDEX=0; _INDEX<_SPACING; _INDEX++)); do printf '\n'; done
    printf '%s' "${THEME_INDENT_GROUP}"
    themeStyle "${1}" "${THEME_COLOR_GROUP}"
    printf '\n'
}
