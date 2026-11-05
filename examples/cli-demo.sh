#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# cli-demo.sh — Beispiel für ein Kommandozeilen-Skript mit dem CLI-Theme
#
# Zeigt, wie ein Skript mit BashLib Hilfe, Info, Hinweise, Statuszeilen und
# Fehlermeldungen ausgibt. Farben und Abstände kommen aus der Theme-Datei von
# cli-theme (CLI_THEME wählt sie); ohne Datei, mit NO_COLOR und in einer Pipe
# erscheint dieselbe Ausgabe ohne Farben in denselben Spalten.
#
# Das Skript ändert nichts; es gibt nur aus. Beschreibung in examples/README.md.
#
#   ./examples/cli-demo.sh --help
# -----------------------------------------------------------------------------

if [[ -z ${BASH_LIBS+x} ]]; then echo "Var 'BASH_LIBS' nicht gesetzt!" >&2; exit 1; fi

set -eou pipefail

# tools.lib.sh bindet colors.lib.sh ein; das liest die Theme-Datei einmal.
# shellcheck source=/dev/null  # liegt unter BASH_LIBS
if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi

APPNAME="$(basename "$0")"
readonly APPNAME
readonly DEMO_VERSION="1.0.0"

# -- Ausgaben -----------------------------------------------------------------

# Hilfe: Befehle, Optionen, Umgebung und Beispiele.
showHelp() {
    printThemeHeading "Aufruf: ${APPNAME} BEFEHL [ARGUMENT]"
    printThemeRow "info | -i" "Einstellungen und Pfade anzeigen"
    printThemeRow "hints" "Nächste Schritte mit Befehlen anzeigen"
    printThemeRow "status" "Statuszeilen für Erfolg, Warnung und Fehler zeigen"
    printThemeRow "theme" "Farbrollen und Abstände des gewählten Themes zeigen"
    printThemeRow "greet NAME" "Begrüßt NAME; ohne NAME ein Fehler mit Exit 2"
    # usageLine ist die ältere Form; sie bleibt gültig und folgt dem Theme.
    usageLine "" "Zweite Beschreibungszeile, eingerückt mit usageLine … yes" "yes"
    printThemeRow "-h | --help" "Diese Hilfe anzeigen (auch ohne Argument)"

    printThemeHeading "Umgebung"
    printThemeRow "BASH_LIBS" "Ordner der BashLib-Bibliotheken (Pflicht)"
    printThemeRow "CLI_THEME" "Theme der Ausgabe (Standard classic)"
    printThemeRow "NO_COLOR" "Ausgabe ohne Farben"

    printThemeHeading "Beispiele"
    printThemeRow "${APPNAME} info" "Einstellungen anzeigen"
    printThemeRow "CLI_THEME=ocean ${APPNAME} status" "Statuszeilen im Theme ocean"
    printThemeRow "${APPNAME} hints | cat" "In einer Pipe: ohne Farben"
    echo
}

# Info: Werte wie Pfade und Version, eine Zeile je Wert. Theme und Datei kommen
# aus colors.lib.sh (THEME_NAME, THEME_SOURCE), so wie es sie geladen hat.
showInfo() {
    colorState
    printThemeHeading "Info"
    printThemeRow "Version" "${DEMO_VERSION}"
    printThemeRow "Skript" "${BASH_SOURCE[0]}"
    printThemeRow "BASH_LIBS" "${BASH_LIBS}"
    printThemeRow "Theme" "${THEME_NAME}"
    printThemeRow "Theme-Datei" "${THEME_SOURCE}"
    printThemeRow "Farben" "${COLOR_STATE}"
    echo
}

# Hinweise: je Schritt eine Zeile, der Befehl steht für sich und lässt sich kopieren.
showHints() {
    printThemeHeading "Nächste Schritte"
    printThemeRow "Themes anlegen" "cli-theme install"
    printThemeRow "Theme ansehen" "cli-theme show"
    printThemeRow "Theme wechseln" "export CLI_THEME=ocean"
    printThemeRow "Ohne Farben" "NO_COLOR=1 ${APPNAME} info"
    echo
}

# Status: die drei Rollen für Statuszeilen.
showStatus() {
    printThemeHeading "Status"
    printThemeStatus "✓" "Erfolg: alles erledigt" OK
    printThemeStatus "!" "Warnung: Theme-Datei fehlt, Ausgabe ohne Farben" WARN
    printThemeStatus "✗" "Fehler: Datei nicht lesbar" ERR
    echo
}

# Theme: jede Farbrolle in ihrer Farbe, dazu die Abstände aus der Theme-Datei.
showTheme() {
    local _entry _role _variable

    printThemeHeading "Farbrollen (${THEME_NAME})"
    for _entry in C_HEAD=GROUP C_KEY=TARGET C_TEXT=DESC C_VAL=VALUE C_HINT=HINT \
        C_ACC=ACCENT C_OK=SUCCESS C_WARN=WARNING C_ERR=DANGER C_MARK=SERVER; do
        _role="${_entry%%=*}"
        _variable="THEME_COLOR_${_entry#*=}"
        printf '%s' "${THEME_INDENT_TARGET}"
        themeStyle "$(printf '%-*s' "$((THEME_WIDTH_TARGET + THEME_COLUMN_GAP))" "${_role}")" "${!_variable}"
        themeStyle "${!_role:-(leer)}" "${!_variable}"
        printf '\n'
    done

    printThemeHeading "Abstände"
    for _role in I_HEAD I_ROW I_HINT W_KEY GAP WIDTH SPACE; do
        printThemeRow "${_role}" "${!_role}"
    done
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
    elif [[ -z ${C_HEAD} && -z ${C_KEY} ]]; then COLOR_STATE="aus (keine gültige Theme-Datei)"
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
