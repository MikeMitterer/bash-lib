#!/usr/bin/env bash
# tools.lib.sh bindet make.lib.sh ein; ein zweites . make.lib.sh ohne
# Guard bricht sonst an readonly ab.
[[ -z "${__MAKE_LIB__:-}" ]] || return 0
readonly __MAKE_LIB__="make.lib.sh";

#------------------------------------------------------------------------------
# Hilfe und Hinweiszeilen für Makefiles im CLI-Theme
#
# showMakeHelp liest aus Makefiles `##@ Gruppe` und `target: … ## Beschreibung`,
# showMakeHints liest `## Titel` und `Beschriftung<TAB>Wert` von stdin. Beide geben
# über die Theme-Helfer aus cli.lib.sh aus (printThemeHeading, printThemeRow,
# printThemeValue, themeMark), also in denselben Spalten wie die Hilfe eines
# Skripts. Am Terminal mit Farben, in einer Pipe und mit NO_COLOR ohne.
#
# Texte aus den Dateien, aus --set und von stdin werden nur ausgegeben, nie
# ausgewertet: $(…), Backticks, Apostrophe und Backslashes erscheinen wörtlich.
#
# Einbinden:
#     if [[ "${__MAKE_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/make.lib.sh"; fi
#
# Usage (im Makefile, Dateinamen über die Umgebung):
#     export HELP_FILES = $(value MAKEFILE_LIST)
#     help:
#         @source "$${BASH_LIBS}/make.lib.sh" && showMakeHelp $${HELP_FILES}
#
#------------------------------------------------------------------------------

# shellcheck source=SCRIPTDIR/tools.lib.sh
if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi

# Endet eine Beschreibung so, steht dafür die Markierung [Maintainer] in der Rolle C_MARK.
readonly MAKE_MAINTAINER_SUFFIX=" — Maintainer"

# Hilfe aus Makefiles: Gruppen (`##@ Gruppe`) als Überschrift, Targets mit
# `## Beschreibung` als Zeile. Zuweisungen (NAME := …) und Targets ohne `##`
# zählen nicht. Eine Beschreibung, die auf „ — Maintainer“ endet, bekommt die
# Markierung [Maintainer]; {NAME} ersetzt der Wert aus --set NAME=WERT,
# unbekannte Platzhalter bleiben stehen. Die Ausgabe endet mit einer Leerzeile.
#
# Usage:
#     showMakeHelp Makefile
#     showMakeHelp --set "minor=0.4.0 → 0.5.0" Makefile extra.mk
#
# Params:
#     --set NAME=WERT   Wert für den Platzhalter {NAME}; NAME aus A-Z, a-z, 0-9, _
#     $@                Makefiles in der Reihenfolge der Ausgabe (etwa MAKEFILE_LIST)
#
# Exit:
#     0  Hilfe ausgegeben
#     1  eine Datei ist nicht lesbar (dann ohne Ausgabe)
#     2  Aufruf falsch: --set ohne NAME=WERT oder keine Datei
#
showMakeHelp() {
    # Indizierte Arrays statt -A: make.lib.sh läuft auch unter /bin/bash 3.2 (macOS)
    local -a _settings=() _files=()
    local _file _line _setting _target _description _maintainer
    local -r _GROUP='^##@[[:space:]]*(.*)$'
    local -r _TARGET='^([A-Za-z0-9_-]+):(.*)$'

    while (( $# > 0 )); do
        case "${1}" in
            --set)
                _setting="${2-}"
                if [[ ! ${_setting} =~ ^[A-Za-z0-9_]+= ]]; then
                    printf 'showMakeHelp: NAME=WERT erwartet, war %s\n' "${_setting}" >&2
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
        printf 'showMakeHelp: keine Datei angegeben\n' >&2
        return 2
    fi
    for _file in "${_files[@]}"; do
        if [[ ! -f ${_file} || ! -r ${_file} ]]; then
            printf 'showMakeHelp: %s ist nicht lesbar\n' "${_file}" >&2
            return 1
        fi
    done

    for _file in "${_files[@]}"; do
        while IFS= read -r _line || [[ -n ${_line} ]]; do
            _line="${_line%$'\r'}"
            if [[ ${_line} =~ ${_GROUP} ]]; then
                printThemeHeading "$(makeEscape "$(trim "${BASH_REMATCH[1]}")")"
            elif [[ ${_line} =~ ${_TARGET} && ${BASH_REMATCH[2]} != =* \
                    && ${BASH_REMATCH[2]} == *"## "* ]]; then
                _target="${BASH_REMATCH[1]}"
                _description="$(trim "${BASH_REMATCH[2]#*"## "}")"
                _maintainer=""
                if [[ ${_description} == *"${MAKE_MAINTAINER_SUFFIX}" ]]; then
                    _description="${_description%"${MAKE_MAINTAINER_SUFFIX}"}"
                    _maintainer=" $(themeMark "[Maintainer]")"
                fi
                printThemeRow "${_target}" \
                    "$(makeEscape "$(makeFill "${_description}" ${_settings[@]+"${_settings[@]}"})")${_maintainer}"
            fi
        done < "${_file}"
    done
    echo
}

# Name/Wert-Zeilen für make info: Paare NAME WERT als Argumente, in den Spalten des
# Themes wie showMakeHints; ein leerer Wert erscheint als „nicht gesetzt“. Die
# Ausgabe endet mit einer Leerzeile.
#
# Usage (im Makefile, Werte über die Umgebung):
#     showMakeInfo PROJECT_NAME "$${PROJECT_NAME}" WORKSPACE "$${WORKSPACE}"
#
# Exit:
#     0  ausgegeben
#     2  ungerade Anzahl Argumente (dann ohne Ausgabe)
#
showMakeInfo() {
    if (( $# % 2 != 0 )); then
        printf 'showMakeInfo: Paare NAME WERT erwartet, war %d Argumente\n' "$#" >&2
        return 2
    fi
    while (( $# > 0 )); do
        printThemeValue "$(makeEscape "${1}")" "$(makeEscape "${2:-nicht gesetzt}")"
        shift 2
    done
    echo
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

# Hinweiszeilen von stdin: `## Titel` wird Überschrift, `Beschriftung<TAB>Wert`
# eine Zeile mit dem Wert in der Rolle C_VAL, der nie umbricht. Eine Zeile ohne
# TAB ist eine Beschriftung ohne Wert; leere Zeilen zählen nicht. Die Ausgabe
# endet mit einer Leerzeile.
#
# Usage:
#     printf '%s\t%s\n' "Vor dem Commit" "make check" | showMakeHints
#     { printf '## %s\n' Links; printf '%s\t%s\n' Repository "${url}"; } | showMakeHints
#
showMakeHints() {
    local _line _label _value
    while IFS= read -r _line || [[ -n ${_line} ]]; do
        _line="${_line%$'\r'}"
        if [[ ${_line} == "## "* ]]; then
            printThemeHeading "$(makeEscape "$(trim "${_line#"## "}")")"
        elif [[ -n ${_line//[[:space:]]/} ]]; then
            _label="${_line%%$'\t'*}"
            _value=""
            [[ ${_line} == *$'\t'* ]] && _value="${_line#*$'\t'}"
            printThemeValue "$(makeEscape "$(trim "${_label}")")" "$(makeEscape "$(trim "${_value}")")"
        fi
    done
    echo
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

# Verdoppelt Backslashes: Die Theme-Helfer geben Text mit printf %b aus, ein
# Backslash im Text erscheint so wörtlich.
#
# Params:
#     $1 - Text
makeEscape() {
    local _rest="${1}" _result=""
    while [[ ${_rest} == *\\* ]]; do
        _result+="${_rest%%\\*}\\\\"
        _rest="${_rest#*\\}"
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
