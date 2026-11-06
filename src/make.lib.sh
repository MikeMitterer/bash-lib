#!/usr/bin/env bash
readonly __MAKE_LIB__="make.lib.sh";

#------------------------------------------------------------------------------
# Hilfe und Hinweiszeilen für Makefiles im CLI-Theme
#
# showMakeHelp liest aus Makefiles `##@ Gruppe` und `target: … ## Beschreibung`,
# showMakeHints liest `## Titel` und `Beschriftung<TAB>Wert` von stdin. Beide geben
# über die Theme-Helfer aus tools.lib.sh aus (printThemeHeading, printThemeRow,
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
