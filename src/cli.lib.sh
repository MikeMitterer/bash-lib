#!/usr/bin/env bash
# BashLib setzt Bash 5 voraus. Die Prüfung steht vor allem anderen und nutzt nur, was
# Bash 3.2 (/bin/bash unter macOS) versteht; exit beendet auch das einbindende Skript.
if [ "${BASH_VERSINFO[0]:-0}" -lt 5 ]; then
    printf '  ✗ Bash 5 nötig, läuft mit Bash %s\n       brew install bash\n' \
        "${BASH_VERSINFO[0]:-?}.${BASH_VERSINFO[1]:-?}.${BASH_VERSINFO[2]:-?}" >&2
    exit 1
fi

# tools.lib.sh bindet cli.lib.sh ein; ein zweites . cli.lib.sh ohne
# Guard bricht sonst an readonly ab.
[[ -z "${__CLI_LIB__:-}" ]] || return 0
readonly __CLI_LIB__="cli.lib.sh";

#------------------------------------------------------------------------------
# Ausgabe im CLI-Theme: Farben und Abstände von clitheme (clitheme export), die
# Bausteine (themeStyle, themeLine, themeAccent, …) und die Helfer für Hilfe,
# Werte, Hinweise und Statuszeilen (printTheme…, usageLine, showMenu).
#
# Einbinden:
#     if [[ "${__CLI_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/cli.lib.sh"; fi
#
# tools.lib.sh bindet cli.lib.sh selbst ein; Skripte, die tools.lib.sh einbinden,
# brauchen keine Änderung. colors.lib.sh bringt nur die feste Palette.
#------------------------------------------------------------------------------

# shellcheck source=SCRIPTDIR/colors.lib.sh
if [[ "${__COLORS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/colors.lib.sh"; fi

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

# shellcheck disable=SC2034  # von einbindenden Skripten verwendet
readonly C_OFF="${NC}"

# Wahr, wenn das Skript $1 selbst gesetzt hat: gesetzt und nicht aus der Umgebung
# geerbt (exportiert).
themeOwn() {
    local -r _EXPORTED='^declare -[A-Za-z]*x'
    [[ -n ${!1+x} && ! $(declare -p "${1}" 2>/dev/null) =~ ${_EXPORTED} ]]
}

# Übernimmt die THEME_*-Werte aus der Ausgabe von clitheme export --bash, ohne eval: Zeilen
# oder durch Leerzeichen getrennte Zuweisungen (so liefert sie $(shell …) in Make), Werte in
# der Form von shlex.quote. Gilt nur, wenn alles passt: jeder Name erwartet und
# vorhanden, Farben leer oder eine SGR-Folge, Einrückungen nur Leerzeichen, Abstände nur
# Ziffern, die übrigen Texte ohne Escape-Zeichen. Sonst bleibt alles unverändert.
#
# $1 Ausgabe von clitheme export --bash, $2 „inherited“: aus der Umgebung, dann auch ohne
# Hinweis in THEME_NOTICE
#
# Exit:
#     0  übernommen
#     1  nicht übernommen
#
themeImport() {
    local _rest="${1#\# clitheme export --bash}" _name _value
    local -A _imported=()
    local -r _escape=$'\033' _quote="'\"'\"'"
    local -r _sgr="^(${_escape}\\[[0-9;]+m)?\$"
    # NAME=WERT, welche NAME gelten, entscheidet case unten; WERT bar (Zeichen, die
    # shlex.quote nicht quotet) oder in '…', ein ' darin als '"'"'
    local -r _assignment="^[[:space:]]*([A-Z_]+)=('[^']*'(\"'\"'[^']*')*|[A-Za-z0-9_@%+=:,./-]+)([[:space:]]+|$)"
    while [[ ${_rest} =~ [^[:space:]] ]]; do
        [[ ${_rest} =~ ${_assignment} ]] || return 1
        _name="${BASH_REMATCH[1]}" _value="${BASH_REMATCH[2]}"
        _rest="${_rest:${#BASH_REMATCH[0]}}"
        if [[ ${_value} == \'* ]]; then
            _value="${_value:1:-1}"
            _value="${_value//${_quote}/\'}"
        fi
        case ${_name} in
            THEME_COLOR_*) [[ ${_value} =~ ${_sgr} ]] ;;
            THEME_INDENT_*) [[ ${_value} =~ ^\ *$ ]] ;;
            THEME_WIDTH_TARGET | THEME_COLUMN_GAP | THEME_WIDTH_HELP | THEME_GROUP_SPACING) [[ ${_value} =~ ^[0-9]+$ ]] ;;
            THEME_NOTICE) [[ ${2:-} != inherited || -z ${_value} ]] && [[ ${_value} != *${_escape}* ]] ;;
            THEME_NAME | THEME_SOURCE | THEME_ORIGIN) [[ ${_value} != *${_escape}* ]] ;;
            *) false ;;
        esac || return 1
        _imported[${_name}]="${_value}"
    done
    for _name in ${THEME_EXPORTED} THEME_NAME THEME_SOURCE THEME_ORIGIN THEME_NOTICE; do
        [[ -n ${_imported[${_name}]+x} ]] || return 1
    done
    for _name in "${!_imported[@]}"; do
        printf -v "${_name}" '%s' "${_imported[${_name}]}"
    done
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

    # Ein geerbter Export (CLITHEME_EXPORT, einmal je make-Lauf) erspart den Aufruf von
    # clitheme; mit Hinweis gilt er nicht, denn Make macht aus dessen Zeilenumbruch ein
    # Leerzeichen.
    if [[ -n ${CLITHEME_EXPORT:-} ]] && themeImport "${CLITHEME_EXPORT}" inherited; then
        :
    elif ! command -v clitheme >/dev/null 2>&1; then
        THEME_NOTICE="clitheme fehlt, Ausgabe ohne Farben"$'\n'"${THEME_CLITHEME_INSTALL}"
    elif ! _export="$(clitheme export --bash 2>/dev/null)" || ! themeImport "${_export}"; then
        # Installiert, aber gescheitert: der Aufruf zeigt den Grund.
        THEME_NOTICE="clitheme export gescheitert, Ausgabe ohne Farben"$'\n'"clitheme export --bash"
    fi
    # Escape-Bytes als Escape-Text wie die Palette: themeStyle setzt sie mit %b um.
    # Ersatz über eine Variable, damit der Escape-Text wörtlich bleibt.
    for _name in GROUP TARGET DESC VALUE HINT ACCENT SUCCESS WARNING DANGER SERVER; do
        _name="THEME_COLOR_${_name}"
        _value="${!_name}"
        printf -v "${_name}" '%s' "${_value//${_escape}/${_escapeText}}"
    done

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

# Verdoppelt Backslashes, damit Text von außen (Pfade, Werte, Hinweise) über die
# Theme-Helfer wörtlich erscheint; die geben mit printf %b aus.
#
# Usage:
#     printThemeValue "Pfad" "$(themeEscape "${path}")"
#
# $1 Text
themeEscape() {
    local _rest="${1}" _result=""
    while [[ ${_rest} == *\\* ]]; do
        _result+="${_rest%%\\*}\\\\"
        _rest="${_rest#*\\}"
    done
    printf '%s' "${_result}${_rest}"
}

# Theme-Ausgabe für alle Skripte. Farben und Abstände kommen von clitheme (oben).
# $1 Überschrift; THEME_GROUP_SPACING steuert die Leerzeilen davor.
printThemeHeading() {
    themeHeading "${1}"
}

# $1 Beschriftung, $2 Beschreibung, $3 zusätzliche Einrückung (optional).
printThemeRow() {
    themeLine "$@"
}

# Zeile Bezeichnung · Wert; der Wert in der Rolle C_VAL (Werte, Befehle, Pfade).
# $1 Bezeichnung, $2 Wert
printThemeValue() {
    themeLine "${1}" "${2}" 0 "${THEME_COLOR_VALUE}"
}

# Option der Hilfe: Kurz- und Langform in fester Spalte („-i | --info“); ohne Kurzform
# bleibt deren Platz frei, die Langformen stehen bündig. Optionsnamen in der Rolle
# C_KEY, die Metavariable (etwa DATEI) in C_ACC, die Beschreibung in C_TEXT. Ein zu
# langer Eintrag steht in eigener Zeile, die Beschreibung darunter.
#
# Usage:
#     printThemeOption -i --info "Einstellungen anzeigen"
#     printThemeOption "" --restore DATEI "Sicherung zurückspielen"
#
# $1 Kurzform (leer: keine), $2 Langform (leer: keine), $3 Metavariable (leer oder
# weggelassen: keine), $4 Beschreibung; mit drei Argumenten ist $3 die Beschreibung.
printThemeOption() {
    local -r _short="${1}" _long="${2}"
    local _metavar="${3}" _description="${4-}" _label
    if (( $# == 3 )); then
        _metavar=""
        _description="${3}"
    fi
    if [[ -n ${_short} && -n ${_long} ]]; then
        _label="${_short} | ${_long}"
    elif [[ -n ${_long} ]]; then
        # Platz der Kurzform („-x | “) freilassen
        _label="     ${_long}"
    else
        _label="${_short}"
    fi
    [[ -z ${_metavar} ]] || _label+=" $(themeAccent "${_metavar}" "${THEME_COLOR_TARGET}")"
    themeLine "${_label}" "${_description}"
}

# Beispielaufruf der Hilfe: Aufruf in der Rolle C_KEY, Beschreibung in C_TEXT; ein zu
# langer Aufruf steht in eigener Zeile, die Beschreibung darunter.
#
# Usage:
#     printThemeHeading "Beispiele"
#     printThemeExample "demo --info" "Einstellungen anzeigen"
#
# $1 Aufruf, $2 Beschreibung
printThemeExample() {
    themeLine "${1}" "${2}"
}

# Hinweistext in eigener Zeile: Einrückung I_HINT, Rolle C_HINT.
# $1 Text
printThemeHint() {
    themeNotice
    printf '%s' "${THEME_INDENT_HINT}"
    themeStyle "${1}" "${THEME_COLOR_HINT}"
    printf '\n'
}

# Hervorhebung im Text (Rolle C_ACC: Platzhalter, zulässige Werte, Antworten) zum
# Einbetten in eine Beschreibung; danach gilt wieder die Farbe $2.
#
# Das Ergebnis enthält Escape-Text (\x1B[…m). Es gehört nur an die Theme-Helfer
# (printThemeRow, printThemeValue, printThemeHint, usageLine) oder an
# themeStyle TEXT FARBE; die setzen ihn am Terminal um und entfernen ihn in Pipe
# und mit NO_COLOR. Mit echo oder printf steht er roh in der Ausgabe.
#
# Usage:
#   printThemeRow "greet NAME" "Begrüßt $(themeAccent NAME)"
#   themeStyle "Fertig: $(themeAccent 3) Dateien" "${THEME_COLOR_DESC}"; echo
#
# $1 Text, $2 Farbe danach (Standard THEME_COLOR_DESC, die Farbe der Beschreibung)
themeAccent() {
    themeInline "${THEME_COLOR_ACCENT}" "${1}" "${2-${THEME_COLOR_DESC}}"
}

# Markierung im Text (Rolle C_MARK: Sonderstellung wie Maintainer oder Server,
# Herkunft eines Werts), sonst wie themeAccent: nur an die Theme-Helfer oder
# themeStyle geben, nicht an echo/printf.
#
# Usage:
#   printThemeValue "Theme" "${THEME_NAME} $(themeMark "(aus ${THEME_ORIGIN})" "${THEME_COLOR_VALUE}")"
#
# $1 Text, $2 Farbe danach (Standard THEME_COLOR_DESC)
themeMark() {
    themeInline "${THEME_COLOR_SERVER}" "${1}" "${2-${THEME_COLOR_DESC}}"
}

# Text in Farbe $1, danach Farbe $3; ohne Farbe nur der Text. Vor der Rückkehr
# wird zurückgesetzt: Sonst wirken fett (bold+N) oder die Vordergrundfarbe weiter,
# wenn $3 sie nicht selbst neu setzt (etwa C_HINT=dim).
themeInline() {
    local -r _INLINE_COLOR="${1}" _INLINE_TEXT="${2}" _BACK="${3}"
    if [[ -n ${_INLINE_COLOR} ]]; then
        printf '%s%s%s%s' "${_INLINE_COLOR}" "${_INLINE_TEXT}" "${NC}" "${_BACK}"
    else
        printf '%s' "${_INLINE_TEXT}"
    fi
}

# $1 Symbol, $2 Text, $3 Farbrolle (SUCCESS, WARNING, DANGER, … oder OK, WARN, ERR).
# Inhalt und Umleitung nach stderr legt der Aufrufer fest.
printThemeStatus() {
    local -r _SYMBOL="${1}" _MESSAGE="${2}"
    local _ROLE="${3}"
    case "${_ROLE}" in
        OK) _ROLE=SUCCESS ;;
        WARN) _ROLE=WARNING ;;
        ERR) _ROLE=DANGER ;;
    esac
    local -r _COLOR_NAME="THEME_COLOR_${_ROLE}"
    themeNotice
    printf '%s' "${THEME_INDENT_GROUP}"
    themeStyle "${_SYMBOL} ${_MESSAGE}" "${!_COLOR_NAME:-}"
    printf '\n'
}

# Helper zum Anzeigen der "Usage"
#
# Die Breite kommt aus THEME_WIDTH_TARGET (CLI-Theme).
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
    if [[ $# -eq 1 ]] && [[ "$(declare -p "$1" 2>/dev/null)" =~ "declare -a" ]]; then
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

        local _raw_option _description
        _raw_option="${_split[0]#"${_split[0]%%[![:space:]]*}"}"
        _raw_option="${_raw_option%"${_raw_option##*[![:space:]]}"}"
        _description="${_split[1]-}"
        _description="${_description#"${_description%%[![:space:]]*}"}"
        _description="${_description%"${_description##*[![:space:]]}"}"

        local _option="${_raw_option}"
        local _has_bullets=false
        local _has_exit=false
        if [[ ${_raw_option} =~ ^- ]]; then
            _option="${_raw_option#- }"
            _has_bullets=true
        elif [[ ${_raw_option} =~ ^x ]]; then
            _option="${_raw_option#x }"
            _has_exit=true
        fi

        # Add space after _option where the max amount of characters is _option_length - 20
        local _max_length=30
        local _printable _not_printable
        _printable=$(echo -e "${_option}")
        _not_printable=$(echo -e "${_option}" | tr -cd '[:print:]')

        # Subtract the length of the color codes
        local _length_diff=$(( ${#_printable} - ${#_not_printable} ))

        # Wenn _length_diff > 0 dann sind Farben im Spiel
        if [[ ${_length_diff} -gt 0 ]]; then
            _option_length=${_length_diff}
        else
            _option_length=${#_printable}
        fi

        local _nr_of_spaces=$(( _max_length - _option_length ))
        local _spaces
        printf -v _spaces '%*s' "$(( _nr_of_spaces > 0 ? _nr_of_spaces : 0 ))" ''

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
