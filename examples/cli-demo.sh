#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# cli-demo.sh — Beispiel für ein Kommandozeilen-Skript mit dem CLI-Theme
#
# Zeigt, wie ein Skript mit BashLib Hilfe, Info, Hinweise, Statuszeilen und
# Fehlermeldungen ausgibt. Farben und Abstände kommen von clitheme (CLI_THEME
# wählt das Theme); ohne clitheme oder Theme-Datei, mit NO_COLOR und in einer
# Pipe erscheint dieselbe Ausgabe ohne Farben in denselben Spalten.
#
# Das Skript ändert nichts; es gibt nur aus. Beschreibung in examples/README.md.
#
#   ./examples/cli-demo.sh --help
# -----------------------------------------------------------------------------

if [[ -z ${BASH_LIBS+x} ]]; then echo "Var 'BASH_LIBS' nicht gesetzt!" >&2; exit 1; fi

set -eou pipefail

# tools.lib.sh bindet colors.lib.sh ein; das holt das Theme einmal von clitheme.
# shellcheck source=/dev/null  # liegt unter BASH_LIBS
if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi

APPNAME="$(basename "$0")"
readonly APPNAME
readonly DEMO_VERSION="1.0.0"

# -- Ausgaben -----------------------------------------------------------------

# Hilfe: Befehle, Optionen, Umgebung und Beispiele. themeAccent hebt Platzhalter
# und zulässige Werte in der Beschreibung hervor (Rolle C_ACC).
showHelp() {
    printThemeHeading "Aufruf: ${APPNAME} BEFEHL [ARGUMENT]"
    printThemeRow "info | -i" "Einstellungen und Pfade anzeigen"
    printThemeRow "hints" "Nächste Schritte mit Befehlen anzeigen"
    printThemeRow "status" "Statuszeilen für Erfolg, Warnung und Fehler zeigen"
    printThemeRow "theme" "Farbrollen und Abstände des gewählten Themes zeigen"
    printThemeRow "greet NAME" "Begrüßt $(themeAccent NAME); ohne $(themeAccent NAME) ein Fehler mit $(themeAccent "Exit 2")"
    # usageLine ist die ältere Form; sie bleibt gültig und folgt dem Theme.
    usageLine "" "Zweite Beschreibungszeile, eingerückt mit usageLine … yes" "yes"
    printThemeRow "-h | --help" "Diese Hilfe anzeigen (auch ohne Argument)"

    printThemeHeading "Umgebung"
    printThemeRow "BASH_LIBS" "Ordner der BashLib-Bibliotheken (Pflicht)"
    printThemeRow "CLI_THEME" "Theme der Ausgabe (Standard $(themeAccent classic))"
    printThemeRow "NO_COLOR" "Ausgabe ohne Farben, wenn $(themeAccent gesetzt) (auch leer)"

    printThemeHeading "Beispiele"
    printThemeRow "${APPNAME} info" "Einstellungen anzeigen"
    printThemeRow "CLI_THEME=ocean ${APPNAME} status" "Statuszeilen im Theme ocean"
    printThemeRow "${APPNAME} hints | cat" "In einer Pipe: ohne Farben"
    echo
}

# Info: Werte wie Pfade und Version, eine Zeile je Wert in C_VAL. Theme, Datei und
# Herkunft kommen aus colors.lib.sh (THEME_NAME, THEME_SOURCE, THEME_ORIGIN); die
# Herkunft steht als Markierung in C_MARK, ein Hinweis in C_HINT schließt ab.
showInfo() {
    colorState
    printThemeHeading "Info"
    printThemeValue "Version" "${DEMO_VERSION}"
    printThemeValue "Skript" "${BASH_SOURCE[0]}"
    printThemeValue "BASH_LIBS" "${BASH_LIBS}"
    local _origin="(aus ${THEME_ORIGIN})"
    case "${THEME_ORIGIN}" in
        "") _origin="(ohne clitheme)" ;;
        default) _origin="(Standard)" ;;
    esac
    printThemeValue "Theme" "${THEME_NAME} $(themeMark "${_origin}" "${THEME_COLOR_VALUE}")"
    printThemeValue "Theme-Datei" "${THEME_SOURCE:-keine}"
    printThemeValue "Farben" "${COLOR_STATE}"
    printThemeHint "Farben gibt es nur am Terminal; NO_COLOR schaltet sie ab."
    echo
}

# Hinweise: je Schritt eine Zeile, der Befehl steht in C_VAL für sich und lässt sich
# kopieren; erklärender Text in C_HINT.
showHints() {
    printThemeHeading "Nächste Schritte"
    printThemeValue "Themes anlegen" "clitheme install"
    printThemeValue "Theme ansehen" "clitheme show"
    printThemeValue "Theme wechseln" "export CLI_THEME=ocean"
    printThemeValue "Ohne Farben" "NO_COLOR=1 ${APPNAME} info"
    printThemeHint "Jeder Befehl steht für sich und lässt sich kopieren."
    echo
}

# Status: die drei Rollen für Statuszeilen.
showStatus() {
    printThemeHeading "Status"
    printThemeStatus "✓" "Erfolg: alles erledigt" OK
    printThemeStatus "!" "Warnung: kein Theme, Ausgabe ohne Farben" WARN
    printThemeStatus "✗" "Fehler: Datei nicht lesbar" ERR
    echo
}

# Theme: jede Farbrolle in ihrer Farbe, dazu die Abstände von clitheme.
showTheme() {
    local _entry _role _variable

    printThemeHeading "Farbrollen (${THEME_NAME})"
    for _entry in C_HEAD=GROUP C_KEY=TARGET C_TEXT=DESC C_VAL=VALUE C_HINT=HINT \
        C_ACC=ACCENT C_OK=SUCCESS C_WARN=WARNING C_ERR=DANGER C_MARK=SERVER; do
        _role="${_entry%%=*}"
        _variable="THEME_COLOR_${_entry#*=}"
        printf '%s' "${THEME_INDENT_TARGET}"
        themeStyle "$(printf '%-*s' "$((THEME_WIDTH_TARGET + THEME_COLUMN_GAP))" "${_role}")" "${!_variable}"
        themeStyle "${_variable}" "${!_variable}"
        printf '\n'
    done

    printThemeHeading "Abstände"
    printThemeValue "THEME_INDENT_GROUP" "${#THEME_INDENT_GROUP}"
    printThemeValue "THEME_INDENT_TARGET" "${#THEME_INDENT_TARGET}"
    printThemeValue "THEME_INDENT_HINT" "${#THEME_INDENT_HINT}"
    printThemeValue "THEME_WIDTH_TARGET" "${THEME_WIDTH_TARGET}"
    printThemeValue "THEME_COLUMN_GAP" "${THEME_COLUMN_GAP}"
    printThemeValue "THEME_WIDTH_HELP" "${THEME_WIDTH_HELP}"
    printThemeValue "THEME_GROUP_SPACING" "${THEME_GROUP_SPACING}"
    printThemeHint "THEME_WIDTH_HELP gilt für Python-Werkzeuge; BashLib bricht Zeilen nicht um."
    echo
}

# Begrüßung mit Pflichtangabe; fehlt NAME, Fehlermeldung mit nächstem Schritt.
greet() {
    local -r _name="${1:-}"
    if [[ -z ${_name} ]]; then
        fail "Fehlende Angabe: NAME" "${APPNAME} greet NAME"
    fi
    printThemeStatus "✓" "Hallo ${_name}" OK
    echo
}

# Setzt COLOR_STATE: Farben am Terminal an oder aus, mit Grund. Nicht in $(…)
# aufrufen, dort ist stdout nie ein Terminal.
colorState() {
    if [[ -n ${NO_COLOR+x} ]]; then COLOR_STATE="aus (NO_COLOR gesetzt)"
    elif [[ ! -t 1 ]]; then COLOR_STATE="aus (keine Ausgabe an ein Terminal)"
    elif [[ ${TERM:-} == dumb ]]; then COLOR_STATE="aus (TERM=dumb)"
    elif [[ -z ${THEME_COLOR_GROUP} && -z ${THEME_COLOR_TARGET} ]]; then COLOR_STATE="aus (kein Theme von clitheme)"
    else COLOR_STATE="an"
    fi
}

# Fehler auf stderr: Meldung, dann der nächste Schritt in eigener Zeile; Exit 2.
# $1 Meldung, $2 Befehl für den nächsten Schritt
fail() {
    {
        printThemeStatus "✗" "${1}" ERR
        printf '%s%s\n\n' "${THEME_INDENT_TARGET}" "${2}"
    } >&2
    exit 2
}

# -- Befehle ------------------------------------------------------------------

readonly COMMAND="${1:-}"

case "${COMMAND}" in
    "" | -h | --help) showHelp ;;
    info | -i) showInfo ;;
    hints) showHints ;;
    status) showStatus ;;
    theme) showTheme ;;
    greet) greet "${2:-}" ;;
    -*) fail "Unbekannte Option: ${COMMAND}" "${APPNAME} --help" ;;
    *) fail "Unbekannter Befehl: ${COMMAND}" "${APPNAME} --help" ;;
esac
