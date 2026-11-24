#!/usr/bin/env bash
# Ein zweites . make.lib.sh ohne Guard bricht sonst an readonly ab.
[[ -z "${__MAKE_LIB__:-}" ]] || return 0
readonly __MAKE_LIB__="make.lib.sh";

#------------------------------------------------------------------------------
# Hilfe, Infos und Hinweise für Makefiles im CLI-Theme
#
# Eine Rezeptzeile ergibt eine Ausgabezeile: printMakeHeading und printMakeValue
# geben je eine Zeile aus wie printThemeHeading und printThemeValue aus cli.lib.sh,
# showMakeHeader die Kopfzeilen der Hilfe, showMakeTargets die Gruppen und Targets
# aus den Makefiles. Am Terminal mit Farben, in einer Pipe und mit NO_COLOR ohne.
#
# Texte aus Argumenten und Dateien werden nur ausgegeben, nie ausgewertet: $(…),
# Backticks, Apostrophe und Backslashes erscheinen wörtlich.
#
# Für Agenten (bashlib --skill):
#     Zweck:   Hilfe, Hinweise, Version und Einrichtung für Makefiles im CLI-Theme
#     Wann:    `make help`, `make info` oder `make hints` ausgeben, Prüf-Targets an `make setup` binden, ein Paket editierbar mit pipx installieren
#     Wichtig: showMakeHeader, showMakeTargets, printMakeHeading, printMakeValue, requireMakeSetup, installEditablePackage, showProjectVersion
#
# Einbinden:
#     if [[ "${__MAKE_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/make.lib.sh"; fi
#
# Usage (im Makefile): BASH_ENV lädt make.lib.sh in jede Rezeptzeile der
# Anzeige-Targets. Bash wertet BASH_ENV aus, darum der Verweis auf BASH_LIBS
# statt des Pfads; Dateinamen und Werte von außen über die Umgebung.
#     export BASH_LIBS
#     export HELP_FILES = $(value MAKEFILE_LIST)
#     help info: export BASH_ENV := $${BASH_LIBS}/make.lib.sh
#
# Ohne die zwei Zeilen darunter startet jede Rezeptzeile clitheme (rund 0,1 s). Mit ihnen
# läuft clitheme export einmal je make-Lauf, und themeLoad übernimmt das Ergebnis geprüft
# aus CLITHEME_EXPORT (cli.lib.sh, themeImport). Make ab 4.4 gibt BASH_ENV auch an
# $(shell); dort lädt make.lib.sh das Theme noch einmal, also zwei Aufrufe je Lauf:
#     clitheme_export = $(eval clitheme_export := $$(shell clitheme export --bash 2>/dev/null))$(clitheme_export)
#     help info: export CLITHEME_EXPORT = $(clitheme_export)
#
#     help:
#         @showMakeHeader "$${PROJECT_NAME}"
#         @showMakeTargets $${HELP_FILES}
#
#     info:
#         @printMakeHeading "Umgebung"
#         @printMakeValue   WORKSPACE "$${WORKSPACE}"
#
#------------------------------------------------------------------------------

# Nur Ausgabe und Version: BASH_ENV lädt make.lib.sh in jede Rezeptzeile, tools.lib.sh
# (apps, dtime, os) startet beim Einbinden Programme. Wer dessen Helfer braucht, bindet
# tools.lib.sh selbst ein.
# shellcheck source=SCRIPTDIR/cli.lib.sh
if [[ "${__CLI_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/cli.lib.sh"; fi
# shellcheck source=SCRIPTDIR/version.lib.sh
if [[ "${__VERSION_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/version.lib.sh"; fi

# Kopfzeilen der Makefile-Hilfe: Leerzeile, „Please use `make <target>' where <target>
# is one of“, Leerzeile, „Project: NAME“; target und NAME in der Gruppenfarbe des
# Themes. Bei deutscher Sprache (_isGermanLocale) deutsch: „Verwende `make <target>',
# wobei <target> eines der folgenden ist“ und „Projekt: NAME“. Ohne Theme-Farben, mit
# NO_COLOR oder ohne Terminal ohne Escape-Folgen. Der Name wird nur ausgegeben, nie
# ausgewertet.
#
# Usage:
#     showMakeHeader "$${PROJECT_NAME}"
#
# Exit:
#     0  ausgegeben
#     2  Aufruf falsch: kein NAME
#
showMakeHeader() {
    if (( $# != 1 )) || [[ -z ${1} ]]; then
        printf 'showMakeHeader: NAME erwartet\n' >&2
        return 2
    fi
    # Mit NC als Farbe behält themeStyle die eingebetteten Farben; ohne Theme-Farben bleibt
    # sie leer, und themeStyle gibt nur den Text aus.
    local -r _plain="${THEME_COLOR_GROUP:+${NC}}"
    local -r _target="$(themeInline "${THEME_COLOR_GROUP}" target "")"
    local -r _name="$(themeInline "${THEME_COLOR_GROUP}" "$(themeEscape "${1}")" "")"
    echo
    if _isGermanLocale; then
        themeStyle "Verwende \`make <${_target}>', wobei <target> eines der folgenden ist" "${_plain}"
        printf '\n\n'
        themeStyle "Projekt: ${_name}" "${_plain}"
    else
        themeStyle "Please use \`make <${_target}>' where <target> is one of" "${_plain}"
        printf '\n\n'
        themeStyle "Project: ${_name}" "${_plain}"
    fi
    printf '\n'
}

# Ist die Sprache der Meldungen deutsch? Vorrang wie bei gettext: LC_ALL, LC_MESSAGES,
# LANG; LANGUAGE (Liste wie „de:en“, zählt der erste Eintrag) geht vor, außer die
# Locale ist leer, C oder POSIX. Ist keine der vier Variablen gesetzt (etwa make aus
# einer IDE unter macOS), gilt die erste Systemsprache aus defaults read -g
# AppleLanguages; ohne defaults oder wenn es scheitert, englisch.
#
# Exit:
#     0  deutsch (de, de_AT.UTF-8, de_DE@euro, …)
#     1  jede andere oder keine Sprache
#
_isGermanLocale() {
    local _lang="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" _system
    if [[ -n ${LANGUAGE:-} && -n ${_lang} && ${_lang} != C && ${_lang} != C.* && ${_lang} != POSIX ]]; then
        _lang="${LANGUAGE%%:*}"
    elif [[ -z ${_lang} && -z ${LANGUAGE:-} ]]; then
        # Ausgabe wie ( "de-AT", de, en ): der erste Eintrag, ohne Anführungszeichen
        _system="$(defaults read -g AppleLanguages 2>/dev/null)"
        [[ ${_system} =~ ^\([[:space:]]*\"?([A-Za-z_-]+) ]] && _lang="${BASH_REMATCH[1]}"
    fi
    [[ ${_lang} =~ ^de([-_.@]|$) ]]
}

# Gruppen (`##@ Gruppe`) als Überschrift, Targets mit `## Beschreibung` als Zeile,
# aus den Makefiles in der angegebenen Reihenfolge. Server-Targets mit `##R` (schreibend)
# und `##D` (destruktiv) stehen ebenso da, der Name in der Server- bzw. Danger-Farbe des
# Themes. Zuweisungen (NAME := …) und Targets ohne `##` zählen nicht. Die Beschreibung
# erscheint als Text, wie sie dasteht. {version}, {major}, {minor} und {patch} zeigen
# die Version aus dem Arbeitsverzeichnis (readProjectVersion) und für die drei
# Release-Arten davor und danach, etwa „0.6.0 → 0.7.0“; ohne Versionsdatei einen
# Ersatz wie „x.y.z → x.Y+1.0“. Weitere {NAME} ersetzt --set NAME=WERT, es gewinnt
# auch vor der Version; unbekannte Platzhalter bleiben stehen. Die Ausgabe endet mit
# einer Leerzeile.
#
# Usage:
#     showMakeTargets Makefile
#     showMakeTargets --set "host=example.org" Makefile extra.mk
#
# Params:
#     --set NAME=WERT   Wert für den Platzhalter {NAME}; NAME aus A-Z, a-z, 0-9, _
#     $@                Makefiles in der Reihenfolge der Ausgabe (etwa MAKEFILE_LIST)
#
# Exit:
#     0  ausgegeben
#     1  eine Datei ist nicht lesbar (dann ohne Ausgabe)
#     2  Aufruf falsch: --set ohne NAME=WERT oder keine Datei
#
showMakeTargets() {
    local -a _settings=() _files=()
    local _file _line _setting _target _description _version _bump _next _color
    # Leerzeichen am Rand des Namens bzw. der Beschreibung fangen die Muster nicht ein
    local -r _GROUP='^##@[[:space:]]*(.*[^[:space:]])?[[:space:]]*$'
    local -r _TARGET='^([A-Za-z0-9_-]+):(.*)$'
    # Erster Marker nach dem Doppelpunkt: ## lokal, ##R Server schreibend, ##D destruktiv
    local -r _MARKER='##([RD]?) [[:space:]]*(.*[^[:space:]])?[[:space:]]*$'

    while (( $# > 0 )); do
        case "${1}" in
            --set)
                _setting="${2-}"
                if [[ ! ${_setting} =~ ^[A-Za-z0-9_]+= ]]; then
                    printf 'showMakeTargets: NAME=WERT erwartet, war %s\n' "${_setting}" >&2
                    return 2
                fi
                _settings+=("${_setting}")
                shift 2
                ;;
            --)
                shift
                _files+=("$@")
                break
                ;;
            *)
                _files+=("${1}")
                shift
                ;;
        esac
    done
    if (( ${#_files[@]} == 0 )); then
        printf 'showMakeTargets: keine Datei angegeben\n' >&2
        return 2
    fi
    for _file in "${_files[@]}"; do
        if [[ ! -f ${_file} || ! -r ${_file} ]]; then
            printf 'showMakeTargets: %s ist nicht lesbar\n' "${_file}" >&2
            return 1
        fi
    done

    # Version vor den Werten aus --set: bei gleichem NAME gilt in makeFill der letzte.
    _version="$(readProjectVersion 2>/dev/null)" || _version="x.y.z"
    _settings=("version=${_version}" ${_settings[@]+"${_settings[@]}"})
    for _bump in "major:X+1.0.0" "minor:x.Y+1.0" "patch:x.y.Z+1"; do
        _next="$(semVerNext "${_bump%%:*}" 2>/dev/null)" || _next="${_bump#*:}"
        _settings=("${_bump%%:*}=${_version} → ${_next}" "${_settings[@]}")
    done

    for _file in "${_files[@]}"; do
        while IFS= read -r _line || [[ -n ${_line} ]]; do
            _line="${_line%$'\r'}"
            if [[ ${_line} =~ ${_GROUP} ]]; then
                printThemeHeading "$(themeEscape "${BASH_REMATCH[1]}")"
            elif [[ ${_line} =~ ${_TARGET} && ${BASH_REMATCH[2]} != =* ]] \
                    && _target="${BASH_REMATCH[1]}" && [[ ${BASH_REMATCH[2]} =~ ${_MARKER} ]]; then
                case "${BASH_REMATCH[1]}" in
                    R) _color="${THEME_COLOR_SERVER}" ;;
                    D) _color="${THEME_COLOR_DANGER}" ;;
                    *) _color="" ;;
                esac
                [[ -z ${_color} ]] || _target="$(themeInline "${_color}" "${_target}" "")"
                _description="${BASH_REMATCH[2]}"
                printThemeRow "${_target}" "$(themeEscape "$(makeFill "${_description}" "${_settings[@]}")")"
            fi
        done < "${_file}"
    done
    echo
}

# Überschrift einer Gruppe in make info und make hints, wie printThemeHeading; der
# Text erscheint wörtlich.
#
# Usage:
#     @printMakeHeading "Links"
#
# Exit:
#     0  ausgegeben
#     2  Aufruf falsch: kein TEXT
#
printMakeHeading() {
    if (( $# != 1 )) || [[ -z ${1} ]]; then
        printf 'printMakeHeading: TEXT erwartet\n' >&2
        return 2
    fi
    printThemeHeading "$(themeEscape "${1}")"
}

# Zeile Bezeichnung · Wert in make info und make hints, wie printThemeValue: der Wert
# in der Rolle C_VAL, er bricht nie um. Beides erscheint wörtlich; ohne WERT steht
# nur die Bezeichnung da.
#
# Usage:
#     @printMakeValue WORKSPACE "$${WORKSPACE}"
#     @printMakeValue "1. Setup" "make setup"
#
# Exit:
#     0  ausgegeben
#     2  Aufruf falsch: keine BEZEICHNUNG oder mehr als zwei Argumente
#
printMakeValue() {
    if (( $# < 1 || $# > 2 )) || [[ -z ${1} ]]; then
        printf 'printMakeValue: BEZEICHNUNG [WERT] erwartet\n' >&2
        return 2
    fi
    printThemeValue "$(themeEscape "${1}")" "$(themeEscape "${2-}")"
}

# Prüft für Prüf-Targets (test, check), ob das Projekt mit make setup eingerichtet ist:
# --hooks DIR verlangt git config core.hooksPath = DIR, --make MAKE STEMPEL… verlangt,
# dass `MAKE -q STEMPEL…` die Stempeldateien als aktuell meldet. Fehlt etwas, steht
# „✗ Nicht eingerichtet“ und darunter `make setup` auf stderr; das Skript endet nicht.
#
# Usage (im Makefile):
#     @source "$${BASH_LIBS}/make.lib.sh" && requireMakeSetup --hooks .githooks
#     @source "$${BASH_LIBS}/make.lib.sh" && requireMakeSetup --make "$(MAKE)" .venv/.installed
#
# Exit:
#     0  eingerichtet
#     1  nicht eingerichtet (Meldung auf stderr)
#     2  Aufruf falsch: keine Prüfung, Stempel ohne --make oder unbekannte Option
#
requireMakeSetup() {
    local _hooks="" _make=""
    local -a _stamps=()
    while (( $# > 0 )); do
        case "${1}" in
            --hooks|--make)
                # Ohne Wert (etwa aus einer leeren Make-Variable) würde shift 2 scheitern
                # und die Schleife dieselbe Option endlos wieder sehen.
                if (( $# < 2 )) || [[ -z ${2} ]]; then
                    printf 'requireMakeSetup: %s %s erwartet\n' "${1}" "$([[ ${1} == --hooks ]] && echo DIR || echo MAKE)" >&2
                    return 2
                fi
                if [[ ${1} == --hooks ]]; then _hooks="${2}"; else _make="${2}"; fi
                shift 2
                ;;
            --) shift; _stamps+=("$@"); break ;;
            -*) printf 'requireMakeSetup: unbekannte Option %s\n' "${1}" >&2; return 2 ;;
            *) _stamps+=("${1}"); shift ;;
        esac
    done
    if [[ -z ${_hooks} && ${#_stamps[@]} -eq 0 ]]; then
        printf 'requireMakeSetup: --hooks DIR oder --make MAKE STEMPEL… erwartet\n' >&2
        return 2
    fi
    if (( ${#_stamps[@]} > 0 )) && [[ -z ${_make} ]]; then
        printf 'requireMakeSetup: Stempel brauchen --make MAKE\n' >&2
        return 2
    fi

    local _ready=yes
    if [[ -n ${_hooks} && "$(git config core.hooksPath 2>/dev/null)" != "${_hooks}" ]]; then
        _ready=no
    fi
    if (( ${#_stamps[@]} > 0 )) && ! "${_make}" -q "${_stamps[@]}" >/dev/null 2>&1; then
        _ready=no
    fi
    [[ ${_ready} == no ]] || return 0
    {
        printThemeStatus "✗" "Nicht eingerichtet" ERR
        printThemeHint "make setup"
    } >&2
    return 1
}

# Installiert die Arbeitskopie DIR editierbar mit pipx (`pipx install -e --force DIR`):
# die Befehle aus [project.scripts] zeigen danach auf DIR. Bei Erfolg steht
# „✓ BEFEHLE aus DIR“ da, die Befehle aus DIR/pyproject.toml (readPackageCommands),
# ohne Einträge „Paket“; die rohe Ausgabe von pipx bleibt verborgen. Fehlt pipx,
# stehen „✗ pipx fehlt“ und https://pipx.pypa.io auf stderr; scheitert pipx, dessen
# Ausgabe und „✗ pipx install fehlgeschlagen“. Neue Befehle legt pipx nur beim
# Installieren an; nach einem Update deshalb erneut aufrufen.
#
# Usage (im Makefile):
#     install: ## Befehle des Pakets aus dieser Arbeitskopie (pipx, editierbar)
#         @source "$${BASH_LIBS}/make.lib.sh" && installEditablePackage "$${WORKSPACE}"
#
# Exit:
#     0  installiert
#     1  pipx fehlt oder pipx install gescheitert (Meldung auf stderr)
#     2  Aufruf falsch: kein DIR
#
installEditablePackage() {
    if (( $# != 1 )) || [[ -z ${1} ]]; then
        printf 'installEditablePackage: DIR erwartet\n' >&2
        return 2
    fi
    local _output _commands
    # requireCommand aus apps.lib.sh erst hier: das Einbinden sucht Werkzeuge im System
    # shellcheck source=SCRIPTDIR/apps.lib.sh
    if [[ "${__APPS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/apps.lib.sh"; fi
    requireCommand pipx "https://pipx.pypa.io" || return 1
    if ! _output="$(pipx install -e --force "${1}" 2>&1)"; then
        printf '%s\n' "${_output}" >&2
        printThemeStatus "✗" "pipx install fehlgeschlagen" ERR >&2
        return 1
    fi
    _commands="$(readPackageCommands "${1}")" || _commands="Paket"
    printThemeStatus "✓" "${_commands//$'\n'/, } aus $(themeEscape "${1}")" OK
}

# Legt mit clitheme install fehlende Theme-Dateien an (vorhandene bleiben) und meldet den
# Ordner. Fehlt clitheme, tut es nichts: Die Ausgabe bleibt dann farblos, den
# Installationsbefehl nennt devtools. Scheitert install, stehen dessen Ausgabe und der
# nächste Schritt auf stderr.
#
# Usage (im Makefile, Teil von setup):
#     @source "$${BASH_LIBS}/make.lib.sh" && installCliThemes || true
#
# Exit:
#     0  Themes angelegt oder clitheme fehlt
#     1  clitheme install gescheitert
#
installCliThemes() {
    local _output
    command -v clitheme >/dev/null || return 0
    if ! _output="$(clitheme install 2>&1)"; then
        printf '%s\n' "${_output}" >&2
        printThemeStatus "✗" "clitheme install fehlgeschlagen, Ausgabe ohne Farben" ERR >&2
        printThemeHint "clitheme show" >&2
        return 1
    fi
    printThemeStatus "✓" "CLI-Themes in $(themeEscape "$(dirname -- "$(clitheme path)")")" OK
}

# Ersetzt {NAME} durch den Wert aus NAME=WERT; unbekannte Platzhalter bleiben,
# wie sie sind. Werte werden nicht erneut durchsucht. Gilt ein NAME mehrfach,
# zählt der letzte.
#
# Params:
#     $1 - Text mit Platzhaltern
#     $2… - Werte als NAME=WERT
makeFill() {
    local _rest="${1}" _result="" _after _name _value _setting _found
    local -r _NAME='^([A-Za-z0-9_]+)\}(.*)$'
    shift
    while [[ ${_rest} == *"{"* ]]; do
        _result+="${_rest%%"{"*}"
        _after="${_rest#*"{"}"
        if [[ ${_after} =~ ${_NAME} ]]; then
            _name="${BASH_REMATCH[1]}"
            _rest="${BASH_REMATCH[2]}"
            _found=no
            for _setting in "$@"; do
                if [[ ${_setting%%=*} == "${_name}" ]]; then
                    _value="${_setting#*=}"
                    _found=yes
                fi
            done
            if [[ ${_found} == yes ]]; then
                _result+="${_value}"
            else
                _result+="{${_name}}"
            fi
        else
            _result+="{"
            _rest="${_after}"
        fi
    done
    printf '%s' "${_result}${_rest}"
}

# Version aus der Versionsdatei und Release-Tag (gitReleaseTag) als zwei Zeilen
# im CLI-Theme, für make version. Fehlt eines, steht der Grund als Wert da.
#
# Usage:
#   showProjectVersion
#   showProjectVersion pyproject.toml ../app
#
# $1 Quelle wie readProjectVersion (Standard auto), $2 Verzeichnis (Standard .)
showProjectVersion() {
    local -r _SOURCE="${1:-auto}" _REPO="${2:-.}"
    local _version _tag
    _version="$(readProjectVersion "${_SOURCE}" "${_REPO}")" || _version="keine Versionsdatei"
    _tag="$(gitReleaseTag HEAD "${_REPO}")" || _tag="kein Release-Tag"
    printThemeValue "Version" "${_version}"
    printThemeValue "Release-Tag" "${_tag}"
}

# Die letzten Release-Tags (gitListReleaseTags) im CLI-Theme, neueste zuerst:
# Tag als Bezeichnung, Nachricht als Beschreibung; die erste Spalte wird so
# breit wie der längste Tag. Ohne Release-Tag ein Hinweis.
#
# Usage:
#   showReleaseTags
#   showReleaseTags 5 ../app
#
# $1 Anzahl (Standard 10), $2 Verzeichnis (Standard .); Exit wie gitListReleaseTags
showReleaseTags() {
    local _list _tag _message _longest=0 _extra
    _list="$(gitListReleaseTags "${1:-10}" "${2:-.}")" || return $?
    if [[ -z ${_list} ]]; then
        printThemeHint "keine Release-Tags"
        return 0
    fi
    while IFS=$'\t' read -r _tag _message; do
        (( ${#_tag} > _longest )) && _longest=${#_tag}
    done <<< "${_list}"
    _extra=$(( _longest - $(themeNumber "${THEME_WIDTH_TARGET}" "${THEME_FALLBACK_WIDTH_TARGET}") ))
    (( _extra > 0 )) || _extra=0
    while IFS=$'\t' read -r _tag _message; do
        printThemeRow "${_tag}" "${_message}" "${_extra}"
    done <<< "${_list}"
}
